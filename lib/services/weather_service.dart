import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../models/location_point.dart';

class WeatherCheck {
  const WeatherCheck({
    required this.known,
    required this.isRaining,
    this.isHazy = false,
    this.isExtremeHeat = false,
  });

  const WeatherCheck.unknown()
    : known = false,
      isRaining = false,
      isHazy = false,
      isExtremeHeat = false;

  final bool known;

  final bool isRaining;

  final bool isHazy;

  final bool isExtremeHeat;
}

class WeatherService {
  const WeatherService();

  static const _forecastUrl = 'https://api.open-meteo.com/v1/forecast';
  static const _airQualityUrl =
      'https://air-quality-api.open-meteo.com/v1/air-quality';

  static bool _isRainCode(int code) =>
      (code >= 51 && code <= 67) ||
      (code >= 80 && code <= 82) ||
      (code >= 95 && code <= 99);

  static const _hazyPm10Threshold = 150.0;

  static const _extremeHeatThreshold = 36.0;

  // Forecast range Open-Meteo actually serves per request - a planned
  // time further out than this has no hourly data to match against.
  static const _forecastDays = 16;

  // If the closest hourly forecast slot is further than this from `at`,
  // treat it as "no forecast for that time" rather than silently using a
  // far-off hour's weather.
  static const _maxForecastGap = Duration(hours: 2);

  /// Index into an hourly `time` array closest to [at]. [at] and the
  /// parsed timestamps are compared as plain wall-clock values (see the
  /// class doc comment above checkConditions) - no timezone conversion.
  /// Returns null if [times] is empty or nothing is within
  /// [_maxForecastGap] of [at].
  int? _nearestHourlyIndex(List<dynamic>? times, DateTime at) {
    if (times == null || times.isEmpty) return null;
    int? bestIndex;
    Duration? bestGap;
    for (var i = 0; i < times.length; i++) {
      final raw = times[i] as String?;
      if (raw == null) continue;
      final parsed = DateTime.parse(raw);
      final wallClock = DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
      );
      final gap = wallClock.difference(at).abs();
      if (bestGap == null || gap < bestGap) {
        bestGap = gap;
        bestIndex = i;
      }
    }
    if (bestIndex == null || bestGap! > _maxForecastGap) return null;
    return bestIndex;
  }

  /// Checks weather at [point]. By default checks real-time "right now"
  /// conditions (`current`). Pass [at] - a planned/departure time in this
  /// app's usual Malaysia-wall-clock frame (e.g. TripLeg.start,
  /// RideOption.departTime) - to instead check the forecast for that
  /// specific time (`hourly`, nearest matching hour). Returns
  /// WeatherCheck.unknown() if [at] falls outside Open-Meteo's forecast
  /// range.
  Future<WeatherCheck> checkConditions(LocationPoint point, {DateTime? at}) async {
    bool? isRaining;
    bool? isExtremeHeat;
    try {
      final uri = at == null
          ? Uri.parse(
              '$_forecastUrl?latitude=${point.lat}&longitude=${point.lng}'
              '&current=precipitation,weather_code,apparent_temperature'
              '&timezone=auto',
            )
          : Uri.parse(
              '$_forecastUrl?latitude=${point.lat}&longitude=${point.lng}'
              '&hourly=precipitation,weather_code,apparent_temperature'
              '&timezone=auto&forecast_days=$_forecastDays',
            );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint(
          '[WeatherService] forecast ${response.statusCode} checking '
          '${point.name}',
        );
      } else {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        double? precipitationMm;
        int? weatherCode;
        double? apparentC;
        if (at == null) {
          final current = json['current'] as Map<String, dynamic>?;
          if (current != null) {
            precipitationMm = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
            weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
            apparentC = (current['apparent_temperature'] as num?)?.toDouble();
          }
        } else {
          final hourly = json['hourly'] as Map<String, dynamic>?;
          final index = _nearestHourlyIndex(hourly?['time'] as List?, at);
          if (index == null) {
            debugPrint(
              '[WeatherService] ${point.name}: no forecast hour near $at',
            );
          } else {
            final precipList = hourly?['precipitation'] as List?;
            final codeList = hourly?['weather_code'] as List?;
            final heatList = hourly?['apparent_temperature'] as List?;
            precipitationMm = (precipList?[index] as num?)?.toDouble() ?? 0.0;
            weatherCode = (codeList?[index] as num?)?.toInt() ?? 0;
            apparentC = (heatList?[index] as num?)?.toDouble();
          }
        }
        if (precipitationMm != null && weatherCode != null) {
          isRaining = precipitationMm > 0.1 || _isRainCode(weatherCode);
          if (apparentC != null) {
            isExtremeHeat = apparentC >= _extremeHeatThreshold;
          }
          debugPrint(
            '[WeatherService] ${point.name}: precipitation=${precipitationMm}mm '
            'code=$weatherCode feelsLike=${apparentC ?? '?'}°C -> '
            'rain=${isRaining ?? '?'} heat=${isExtremeHeat ?? '?'}',
          );
        }
      }
    } catch (error) {
      debugPrint('[WeatherService] forecast check failed for ${point.name}: $error');
    }

    bool? isHazy;
    try {
      final uri = at == null
          ? Uri.parse(
              '$_airQualityUrl?latitude=${point.lat}&longitude=${point.lng}'
              '&current=pm10&timezone=auto',
            )
          : Uri.parse(
              '$_airQualityUrl?latitude=${point.lat}&longitude=${point.lng}'
              '&hourly=pm10&timezone=auto&forecast_days=$_forecastDays',
            );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint(
          '[WeatherService] air-quality ${response.statusCode} checking '
          '${point.name}',
        );
      } else {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        double? pm10;
        if (at == null) {
          final current = json['current'] as Map<String, dynamic>?;
          pm10 = (current?['pm10'] as num?)?.toDouble();
        } else {
          final hourly = json['hourly'] as Map<String, dynamic>?;
          final index = _nearestHourlyIndex(hourly?['time'] as List?, at);
          if (index != null) {
            final pm10List = hourly?['pm10'] as List?;
            pm10 = (pm10List?[index] as num?)?.toDouble();
          }
        }
        if (pm10 != null) {
          isHazy = pm10 >= _hazyPm10Threshold;
          debugPrint(
            '[WeatherService] ${point.name}: pm10=$pm10µg/m³ -> '
            'haze=$isHazy',
          );
        }
      }
    } catch (error) {
      debugPrint(
        '[WeatherService] air-quality check failed for ${point.name}: $error',
      );
    }

    if (isRaining == null && isHazy == null && isExtremeHeat == null) {
      return const WeatherCheck.unknown();
    }
    return WeatherCheck(
      known: true,
      isRaining: isRaining ?? false,
      isHazy: isHazy ?? false,
      isExtremeHeat: isExtremeHeat ?? false,
    );
  }
}
