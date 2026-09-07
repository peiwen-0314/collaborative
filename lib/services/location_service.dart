import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/location_point.dart';

enum LocationLookupStatus { success, serviceDisabled, permissionDenied, error }

class LocationLookupResult {
  const LocationLookupResult({required this.status, this.point});

  final LocationLookupStatus status;
  final LocationPoint? point;
}

class LocationService {
  const LocationService();

  Future<LocationLookupResult> detectCurrentLocation() async {
    try {
      await ApiConfig.ensureLoaded();
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 18),
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

  Future<String> _reverseGeocode(double lat, double lng) async {
    if (ApiConfig.hasHereApiKey) {
      try {
        final uri =
            Uri.parse(
              'https://revgeocode.search.hereapi.com/v1/revgeocode',
            ).replace(
              queryParameters: {
                'at': '$lat,$lng',
                'limit': '1',
                'lang': 'en',
                'apiKey': ApiConfig.hereApiKey,
              },
            );
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final items = body['items'] as List?;
          if (items != null && items.isNotEmpty) {
            final item = items.first as Map<String, dynamic>;
            final name = _nameFromHereItem(item);
            if (name != null && name.isNotEmpty) return name;
          }
        }
      } catch (_) {
        // Keep the keyless Nominatim fallback below.
      }
    }

    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse')
          .replace(
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

  Future<LocationPoint?> searchPlace(String keyword) async {
    final results = await searchPlaces(keyword, limit: 1);
    return results.isEmpty ? null : results.first;
  }

  Future<List<LocationPoint>> searchPlaces(
    String keyword, {
    int limit = 8,
    LocationPoint? bias,
  }) async {
    await ApiConfig.ensureLoaded();
    final query = keyword.trim();
    if (query.isEmpty) return const [];

    var liveMatches = const <LocationPoint>[];
    if (ApiConfig.hasHereApiKey) {
      try {
        liveMatches = await _searchHereAutosuggest(
          query,
          limit: limit,
          bias: bias,
        );
      } catch (_) {
        // Fall through to Nominatim below.
      }
    }
    if (liveMatches.isEmpty) {
      try {
        liveMatches = await _searchNominatim(query, limit: limit);
      } catch (_) {
      }
    }

    final seenPlaces = <String>{};
    final deduped = <LocationPoint>[];
    for (final point in liveMatches) {
      final key =
          '${point.name.toLowerCase()}|'
          '${point.lat.toStringAsFixed(5)},${point.lng.toStringAsFixed(5)}';
      if (seenPlaces.add(key)) deduped.add(point);
    }
    return deduped.take(limit).toList();
  }

  Future<List<LocationPoint>> _searchHereAutosuggest(
    String query, {
    required int limit,
    LocationPoint? bias,
  }) async {
    final areaParameter = bias == null
        ? <String, String>{'in': 'countryCode:MYS'}
        : <String, String>{'at': '${bias.lat},${bias.lng}'};
    final uri =
        Uri.parse(
          'https://autosuggest.search.hereapi.com/v1/autosuggest',
        ).replace(
          queryParameters: {
            'q': query,
            'limit': '$limit',
            'lang': 'en',
            'apiKey': ApiConfig.hereApiKey,
            ...areaParameter,
          },
        );

    final response = await http.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return const [];

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List?;
    if (items == null) return const [];

    final points = <LocationPoint>[];
    for (final raw in items) {
      try {
        final item = raw as Map<String, dynamic>;
        final access = item['access'] as List?;
        final position = access != null && access.isNotEmpty
            ? access.first as Map<String, dynamic>?
            : item['position'] as Map<String, dynamic>?;
        if (position == null) {
          continue; // categoryQuery/chainQuery - not a real place.
        }
        final lat = (position['lat'] as num?)?.toDouble();
        final lng = (position['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        points.add(
          LocationPoint(
            name: _nameFromHereItem(item) ?? query,
            lat: lat,
            lng: lng,
          ),
        );
      } catch (_) {
        // Skip a single malformed item.
      }
    }
    return points;
  }

  Future<List<LocationPoint>> _searchNominatim(
    String query, {
    required int limit,
  }) async {
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

    if (response.statusCode != 200) return const [];

    final results = jsonDecode(response.body) as List;
    final points = <LocationPoint>[];

    for (final entry in results) {
      final body = entry as Map<String, dynamic>;
      final lat = double.tryParse(body['lat']?.toString() ?? '');
      final lng = double.tryParse(body['lon']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      points.add(
        LocationPoint(name: _shortLabelFrom(body) ?? query, lat: lat, lng: lng),
      );
    }
    return points;
  }

  String? _nameFromHereItem(Map<String, dynamic> item) {
    final title = item['title'] as String?;
    final address = item['address'] as Map<String, dynamic>?;

    if (title != null && title.isNotEmpty) {
      final area = (address?['city'] ?? address?['district']) as String?;
      if (area != null && area.isNotEmpty && !title.contains(area)) {
        return '$title, $area';
      }
      return title;
    }

    if (address == null) return null;
    final locality =
        address['street'] ?? address['district'] ?? address['city'];
    final city = address['city'] ?? address['county'] ?? address['state'];
    final parts = <String>{
      if (locality is String && locality.isNotEmpty) locality,
      if (city is String && city.isNotEmpty) city,
    }.toList();
    if (parts.isNotEmpty) return parts.join(', ');

    final label = address['label'] as String?;
    if (label != null && label.isNotEmpty) {
      final segments = label.split(',').map((s) => s.trim()).toList();
      return segments.take(2).join(', ');
    }
    return null;
  }

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
