import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../models/location_point.dart';

/// Result of one real rain check - see WeatherService.checkRain.
class WeatherCheck {
  const WeatherCheck({required this.known, required this.isRaining});

  /// Used whenever the real check itself failed (no network, the API is
  /// down, or an unexpected response shape) - a real point that WAS
  /// checked and came back dry uses `WeatherCheck(known: true,
  /// isRaining: false)` instead, so callers can tell "confirmed dry"
  /// apart from "couldn't ask".
  const WeatherCheck.unknown() : known = false, isRaining = false;

  /// False whenever the real check itself failed - callers should treat
  /// "unknown" as "don't warn", never as "assume it's raining": a false
  /// rain warning (telling someone to swap out a bike leg that's
  /// actually fine) is worse than staying quiet the one time the check
  /// couldn't be made.
  final bool known;
  final bool isRaining;
}

/// Real-time "is it raining here right now" check via Open-Meteo
/// (https://open-meteo.com/en/docs) - like OsmBikeShareService's
/// Overpass calls, this is a genuinely free, keyless public API (no
/// account, no API key, no quota to burn), so it fits this app's
/// existing preference for a real, no-key data source over adding yet
/// another API key just to ask one yes/no weather question. Used by
/// TransportController for both the "don't recommend a bike option
/// while it's raining" search-time tag and SavedListPage's "it's
/// raining near your saved bike leg, want to swap it?" prompt.
class WeatherService {
  const WeatherService();

  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// WMO weather-interpretation codes
  /// (https://open-meteo.com/en/docs, "WMO Weather interpretation
  /// codes") that mean actual rain, drizzle, rain showers, or a
  /// thunderstorm is happening right now. Deliberately excludes fog
  /// (45/48), cloud cover alone, and every snow code - this app's
  /// service area (Penang/Klang Valley) essentially never sees snow,
  /// and fog by itself isn't a reason to avoid a bike the way rain is.
  static bool _isRainCode(int code) =>
      (code >= 51 && code <= 67) ||
      (code >= 80 && code <= 82) ||
      (code >= 95 && code <= 99);

  /// Checks whether it's raining right now at [point]. Best-effort only
  /// - see WeatherCheck.unknown's doc comment - never throws.
  Future<WeatherCheck> checkRain(LocationPoint point) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?latitude=${point.lat}&longitude=${point.lng}'
        '&current=precipitation,weather_code&timezone=auto',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint(
          '[WeatherService] ${response.statusCode} checking ${point.name}',
        );
        return const WeatherCheck.unknown();
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>?;
      if (current == null) return const WeatherCheck.unknown();

      final precipitationMm =
          (current['precipitation'] as num?)?.toDouble() ?? 0.0;
      final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
      final isRaining = precipitationMm > 0.1 || _isRainCode(weatherCode);
      debugPrint(
        '[WeatherService] ${point.name}: precipitation=${precipitationMm}mm '
        'code=$weatherCode -> ${isRaining ? "raining" : "dry"}',
      );
      return WeatherCheck(known: true, isRaining: isRaining);
    } catch (error) {
      debugPrint('[WeatherService] check failed for ${point.name}: $error');
      return const WeatherCheck.unknown();
    }
  }
}
