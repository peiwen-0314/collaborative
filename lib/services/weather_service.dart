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

  Future<WeatherCheck> checkConditions(LocationPoint point) async {
    bool? isRaining;
    bool? isExtremeHeat;
    try {
      final uri = Uri.parse(
        '$_forecastUrl?latitude=${point.lat}&longitude=${point.lng}'
        '&current=precipitation,weather_code,apparent_temperature'
        '&timezone=auto',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint(
          '[WeatherService] forecast ${response.statusCode} checking '
          '${point.name}',
        );
      } else {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final current = json['current'] as Map<String, dynamic>?;
        if (current != null) {
          final precipitationMm =
              (current['precipitation'] as num?)?.toDouble() ?? 0.0;
          final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
          isRaining = precipitationMm > 0.1 || _isRainCode(weatherCode);
          final apparentC = (current['apparent_temperature'] as num?)
              ?.toDouble();
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
      final uri = Uri.parse(
        '$_airQualityUrl?latitude=${point.lat}&longitude=${point.lng}'
        '&current=pm10&timezone=auto',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint(
          '[WeatherService] air-quality ${response.statusCode} checking '
          '${point.name}',
        );
      } else {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final current = json['current'] as Map<String, dynamic>?;
        final pm10 = (current?['pm10'] as num?)?.toDouble();
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
