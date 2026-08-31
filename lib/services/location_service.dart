import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/location_point.dart';

enum LocationLookupStatus { success, serviceDisabled, permissionDenied, error }

class LocationLookupResult {
  const LocationLookupResult({required this.status, this.point});

  final LocationLookupStatus status;
  final LocationPoint? point;
}

/// Wraps `geolocator` to ask for location permission and read the user's
/// current position, then reverse-geocodes those coordinates into a real
/// place name (via OpenStreetMap's free Nominatim service - no API key
/// needed) so the "From" field shows an actual address instead of a
/// generic "My Location" label.
class LocationService {
  const LocationService();

  Future<LocationLookupResult> detectCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationLookupResult(
          status: LocationLookupStatus.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationLookupResult(
          status: LocationLookupStatus.permissionDenied,
        );
      }

      // Without a time limit, this can hang for a very long time (or
      // effectively forever) on a device/emulator that can't get a quick
      // GPS/network fix - a common case on Android emulators with no
      // location signal configured. Bounding it means a slow/unavailable
      // fix fails fast into the existing catch-all below (which already
      // falls back to "couldn't detect location" and leaves From blank),
      // instead of leaving the user staring at a loading state with no
      // idea whether it's still working.
      //
      // accuracy is deliberately `low`, not `medium`/`high`: on Flutter
      // web specifically (geolocator's web implementation maps anything
      // above `low` to the browser's `enableHighAccuracy: true`), asking
      // for better-than-low accuracy on a desktop browser with no real GPS
      // chip makes Chrome try much harder for a precise fix - which is
      // often exactly what was making this feel "stuck": it would
      // regularly burn the *entire* timeout before giving up, every single
      // search. `low` accepts a fast, coarse Wi-Fi/IP-based fix instead -
      // still plenty precise for "which city/area am I roughly in", which
      // is all this app actually needs from it. Also true on a real phone,
      // just less dramatically slow there.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );

      final placeName = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      return LocationLookupResult(
        status: LocationLookupStatus.success,
        point: LocationPoint(
          name: placeName,
          lat: position.latitude,
          lng: position.longitude,
        ),
      );
    } catch (_) {
      return const LocationLookupResult(status: LocationLookupStatus.error);
    }
  }

  /// Turns coordinates into a short "Area, City" style label matching the
  /// rest of the app's place names (e.g. "Rawang, Kuala Lumpur"). Falls
  /// back to "My Location" if the lookup fails for any reason (offline,
  /// timeout, unexpected response) - reverse geocoding is a nice-to-have,
  /// never something that should block using the app.
  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(
        queryParameters: {
          'format': 'jsonv2',
          'lat': '$lat',
          'lon': '$lng',
          'zoom': '16',
          'addressdetails': '1',
        },
      );

      final response = await http
          .get(
            uri,
            // Nominatim's usage policy requires a way to identify the
            // calling app - no key needed, just an honest User-Agent.
            headers: const {'User-Agent': 'collab_assignment_flutter_app/1.0'},
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return 'My Location';

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return _shortLabelFrom(body) ?? 'My Location';
    } catch (_) {
      return 'My Location';
    }
  }

  /// Resolves a free-text place name typed by the user (e.g. "cyberjaya" or
  /// "1 utama") into a [LocationPoint], via OpenStreetMap's free Nominatim
  /// search endpoint - no API key, no fixed list of choices, so the user
  /// can type anywhere rather than only picking from a short preset list.
  ///
  /// Returns `null` if the keyword is blank, nothing matches, or the
  /// lookup fails (offline, timeout, unexpected response).
  Future<LocationPoint?> searchPlace(String keyword) async {
    final results = await searchPlaces(keyword, limit: 1);
    return results.isEmpty ? null : results.first;
  }

  /// Same as [searchPlace] but returns up to [limit] matches, so the "From"
  /// / "To" fields can show live suggestions as the user types instead of
  /// only resolving a single best guess.
  ///
  /// Purely live - every result comes from OpenStreetMap's free Nominatim
  /// search endpoint, no built-in preset list. Duplicate-looking results
  /// (same short label) are collapsed to one.
  ///
  /// Returns an empty list if the keyword is too short, nothing matches,
  /// or the live lookup fails/times out (offline, rate-limited, etc.).
  Future<List<LocationPoint>> searchPlaces(String keyword, {int limit = 5}) async {
    final query = keyword.trim();
    if (query.isEmpty) return const [];

    List<LocationPoint> liveMatches = const [];
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
        queryParameters: {
          'q': query,
          'format': 'jsonv2',
          'addressdetails': '1',
          'limit': '$limit',
          // This app only covers Malaysian routes - keep suggestions
          // relevant instead of matching short keywords anywhere on Earth.
          'countrycodes': 'my',
        },
      );

      final response = await http
          .get(
            uri,
            headers: const {'User-Agent': 'collab_assignment_flutter_app/1.0'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List;
        final points = <LocationPoint>[];

        for (final entry in results) {
          final body = entry as Map<String, dynamic>;
          final lat = double.tryParse(body['lat']?.toString() ?? '');
          final lng = double.tryParse(body['lon']?.toString() ?? '');
          if (lat == null || lng == null) continue;

          points.add(LocationPoint(name: _shortLabelFrom(body) ?? query, lat: lat, lng: lng));
        }
        liveMatches = points;
      }
    } catch (_) {
      // Live search failed/timed out - liveMatches just stays empty rather
      // than throwing, so the UI shows "no results" instead of crashing.
    }

    // Nominatim can return several results that shorten to the same
    // "Area, City" label (e.g. two POIs on the same road) - keep the list
    // free of visually-duplicate suggestions.
    final seenNames = <String>{};
    final deduped = <LocationPoint>[];
    for (final point in liveMatches) {
      if (seenNames.add(point.name)) deduped.add(point);
    }
    return deduped.take(limit).toList();
  }

  /// Shared "Area, City" style shortener for a Nominatim result - used for
  /// both reverse geocoding (current location) and forward search (typed
  /// keyword), since both return the same `address` / `display_name`
  /// shape. Returns null if nothing usable was found in [body].
  String? _shortLabelFrom(Map<String, dynamic> body) {
    final address = body['address'] as Map<String, dynamic>?;

    if (address != null) {
      final locality =
          address['suburb'] ??
          address['neighbourhood'] ??
          address['road'] ??
          address['village'] ??
          address['town'];
      final city =
          address['city'] ??
          address['town'] ??
          address['municipality'] ??
          address['county'] ??
          address['state'];

      final parts = <String>{
        if (locality is String && locality.isNotEmpty) locality,
        if (city is String && city.isNotEmpty) city,
      }.toList();

      if (parts.isNotEmpty) return parts.join(', ');
    }

    final displayName = body['display_name'] as String?;
    if (displayName != null && displayName.isNotEmpty) {
      final segments = displayName.split(',').map((s) => s.trim()).toList();
      return segments.take(2).join(', ');
    }

    return null;
  }
}
