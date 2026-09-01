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

/// Wraps `geolocator` to ask for location permission and read the user's
/// current position, then reverse-geocodes those coordinates into a real
/// place name (via OpenStreetMap's free Nominatim service - no API key
/// needed) so the "From" field shows an actual address instead of a
/// generic "My Location" label.
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

      // Transportation uses the coordinate as the actual route origin, so
      // request navigation-grade accuracy rather than accepting a coarse
      // Wi-Fi/IP fix. The bounded timeout still prevents an emulator with
      // no configured location from hanging the screen indefinitely.
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

  /// Turns coordinates into a short "Area, City" style label matching the
  /// rest of the app's place names (e.g. "Rawang, Kuala Lumpur"). Falls
  /// back to "My Location" if the lookup fails for any reason (offline,
  /// timeout, unexpected response) - reverse geocoding is a nice-to-have,
  /// never something that should block using the app.
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
  /// Purely live either way - no built-in preset list. When a HERE key is
  /// configured, [_searchHereAutosuggest] is tried first: HERE's
  /// Autosuggest API (https://autosuggest.search.hereapi.com) is a real
  /// search-as-you-type product - the same kind of thing Google Maps'
  /// search box uses - and finds a specific street/POI by partial name
  /// (e.g. "Bishop Street") far more reliably than Nominatim's free-text
  /// search, which is built for resolving one specific address rather
  /// than ranking partial-keyword matches. [_searchNominatim] (the
  /// original implementation) is the fallback - no HERE key configured,
  /// or the HERE call fails/times out/returns nothing - so search never
  /// goes fully dead just because one live source had a problem.
  /// Duplicate-looking results (same short label) are collapsed to one.
  ///
  /// Returns an empty list if the keyword is too short, nothing matches,
  /// or every live lookup fails/times out (offline, rate-limited, etc.).
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
        // Live search failed/timed out - liveMatches just stays empty
        // rather than throwing, so the UI shows "no results" instead of
        // crashing.
      }
    }

    // Either source can return several results that shorten to the same
    // "Area, City" label (e.g. two POIs on the same road) - keep the list
    // free of visually-duplicate suggestions.
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

  /// HERE's Autosuggest API - real search-as-you-type, ranked by
  /// relevance against partial input, the way Google Maps' search box
  /// behaves. `in=countryCode:MYS` scopes results to Malaysia (this app
  /// only covers Malaysian routes) without needing a bias coordinate.
  /// Only keeps items that are an actual place with real coordinates
  /// (`resultType` like "place"/"street"/"locality"/"houseNumber" - all
  /// carry a real `position`); HERE also returns "categoryQuery"/
  /// "chainQuery" items ("restaurants near me"-style query refinements
  /// with no coordinates of their own), which aren't a real destination
  /// and are skipped.
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
        // For a mall/restaurant the access point is a better routing
        // destination than the POI's visual centre (which may sit inside a
        // large building). Fall back to the display position when HERE has
        // no access point for the result.
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

  /// The original implementation, now the fallback when no HERE key is
  /// configured or [_searchHereAutosuggest] didn't produce anything -
  /// OpenStreetMap's free Nominatim search endpoint, no API key needed.
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

  /// Builds the display name for a HERE Autosuggest item. `title` is the
  /// entity HERE actually matched against the typed query - for a real
  /// POI like "Gurney Paragon" that's already the exact name a user typed
  /// and expects to see back, so it comes FIRST, not last: an earlier
  /// version of this preferred a generic "district, city" label built
  /// from `address` (e.g. "Central George Town, George Town") over the
  /// real matched name, which meant search results never actually showed
  /// what was typed/searched for - defeating the entire point of using a
  /// real search-as-you-type API. `title` is only enriched with a short
  /// city/district suffix when that adds real disambiguating context not
  /// already present in the title itself (e.g. "Gurney Paragon, George
  /// Town" rather than just "Gurney Paragon" with no area shown at all).
  /// Falls back to the old pure-address shortening only for the rare item
  /// that has no title at all.
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
