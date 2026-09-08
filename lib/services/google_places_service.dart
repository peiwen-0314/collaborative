import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/google_place.dart';

class GooglePlacesService {
  static const String _apiKey = String.fromEnvironment(
    'PLACES_API_KEY',
  );

  static const String _baseUrl =
      'https://places.googleapis.com/v1';

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  void _ensureConfigured() {
    if (!isConfigured) {
      throw StateError(
        'Google Places API key is missing. '
            'Run with --dart-define=PLACES_API_KEY=YOUR_KEY',
      );
    }
  }

  Future<List<GooglePlace>> searchPlaces(String query) async {
    _ensureConfigured();

    final value = query.trim();
    if (value.isEmpty) return [];

    final response = await http.post(
      Uri.parse('$_baseUrl/places:searchText'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
        'places.id,'
            'places.displayName,'
            'places.formattedAddress,'
            'places.location',
      },
      body: jsonEncode({
        'textQuery': value,
        'languageCode': 'en',
        'regionCode': 'MY',
        'pageSize': 10,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Google Places search failed '
            '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded =
    jsonDecode(response.body) as Map<String, dynamic>;

    final rawPlaces =
        decoded['places'] as List<dynamic>? ?? const [];

    return rawPlaces
        .whereType<Map<String, dynamic>>()
        .map(GooglePlace.fromSearchJson)
        .where(
          (place) =>
      place.placeId.isNotEmpty &&
          place.name.isNotEmpty,
    )
        .toList();
  }

  Future<GooglePlace> getPlaceDetails(String placeId) async {
    _ensureConfigured();

    final id = placeId.trim();
    if (id.isEmpty) {
      throw ArgumentError('Place ID cannot be empty.');
    }

    final uri = Uri.parse('$_baseUrl/places/$id').replace(
      queryParameters: const {
        'languageCode': 'en',
        'regionCode': 'MY',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
        'id,'
            'displayName,'
            'formattedAddress,'
            'location,'
            'addressComponents,'
            'regularOpeningHours,'
            'nationalPhoneNumber,'
            'internationalPhoneNumber,'
            'websiteUri,'
            'photos',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Google Place Details failed '
            '(${response.statusCode}): ${response.body}',
      );
    }

    final json =
    jsonDecode(response.body) as Map<String, dynamic>;

    final displayName =
        json['displayName'] as Map<String, dynamic>? ?? const {};

    final location =
        json['location'] as Map<String, dynamic>? ?? const {};

    final addressInfo = _parseAddressComponents(
      json['addressComponents'],
    );

    final phone = _firstNonEmpty([
      (json['internationalPhoneNumber'] ?? '').toString(),
      (json['nationalPhoneNumber'] ?? '').toString(),
    ]);

    final photos = <GooglePlacePhoto>[];
    final rawPhotos = json['photos'];
    if (rawPhotos is List) {
      for (final item in rawPhotos) {
        if (item is Map<String, dynamic>) {
          final photo = GooglePlacePhoto.fromJson(item);
          if (photo.name.isNotEmpty) photos.add(photo);
        }
      }
    }

    return GooglePlace(
      placeId: (json['id'] ?? id).toString().trim(),
      name: (displayName['text'] ?? '').toString().trim(),
      address: (json['formattedAddress'] ?? '').toString().trim(),
      latitude: (location['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (location['longitude'] as num?)?.toDouble() ?? 0,
      phoneNumber: phone.trim(),
      websiteUrl: (json['websiteUri'] ?? '').toString().trim(),
      state: addressInfo['state'] ?? '',
      area: addressInfo['area'] ?? '',
      openingHours: _parseOpeningHours(
        json['regularOpeningHours'],
      ),
      photos: photos,
    );
  }

  /// Returns a temporary Google-hosted image URI for display only.
  /// Do NOT store this URI or the photo resource name in Firestore.
  Future<String> getPhotoUri(
      GooglePlacePhoto photo, {
        int maxWidthPx = 900,
      }) async {
    _ensureConfigured();

    final resource = photo.name.trim();
    if (resource.isEmpty) return '';

    final uri = Uri.parse(
      '$_baseUrl/$resource/media',
    ).replace(
      queryParameters: {
        'maxWidthPx': maxWidthPx.toString(),
        'skipHttpRedirect': 'true',
        'key': _apiKey,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Google Place Photo failed '
            '(${response.statusCode}): ${response.body}',
      );
    }

    final data =
    jsonDecode(response.body) as Map<String, dynamic>;

    return (data['photoUri'] ?? '').toString().trim();
  }

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static Map<String, String> _parseAddressComponents(
      dynamic raw,
      ) {
    String state = '';
    String locality = '';
    String sublocality = '';
    String neighborhood = '';

    if (raw is List) {
      for (final item in raw) {
        if (item is! Map<String, dynamic>) continue;

        final longText =
        (item['longText'] ?? '').toString().trim();

        final types = <String>[];
        final rawTypes = item['types'];

        if (rawTypes is List) {
          types.addAll(
            rawTypes.map((e) => e.toString()),
          );
        }

        if (types.contains('administrative_area_level_1')) {
          state = longText;
        }

        if (types.contains('locality')) {
          locality = longText;
        }

        if (types.contains('sublocality') ||
            types.contains('sublocality_level_1')) {
          sublocality = longText;
        }

        if (types.contains('neighborhood')) {
          neighborhood = longText;
        }
      }
    }

    state = _normaliseMalaysiaState(state);

    final area = _firstNonEmpty([
      neighborhood,
      sublocality,
      locality,
    ]);

    return {
      'state': state,
      'area': area,
    };
  }

  static String _normaliseMalaysiaState(String value) {
    final text = value.trim().toLowerCase();

    const aliases = {
      'wilayah persekutuan kuala lumpur': 'Kuala Lumpur',
      'federal territory of kuala lumpur': 'Kuala Lumpur',
      'wilayah persekutuan putrajaya': 'Putrajaya',
      'federal territory of putrajaya': 'Putrajaya',
      'wilayah persekutuan labuan': 'Labuan',
      'federal territory of labuan': 'Labuan',
      'pulau pinang': 'Penang',
      'malacca': 'Melaka',
    };

    return aliases[text] ?? value.trim();
  }

  static Map<String, List<String>> _parseOpeningHours(
      dynamic raw,
      ) {
    const days = <int, String>{
      0: 'Sunday',
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
    };

    final result = <String, List<String>>{
      for (final day in days.values) day: <String>[],
    };

    if (raw is! Map<String, dynamic>) {
      return result;
    }

    final periods = raw['periods'];
    if (periods is! List) {
      return result;
    }

    for (final item in periods) {
      if (item is! Map<String, dynamic>) continue;

      final open =
      item['open'] as Map<String, dynamic>?;

      final close =
      item['close'] as Map<String, dynamic>?;

      if (open == null) continue;

      final dayNumber =
      (open['day'] as num?)?.toInt();

      if (dayNumber == null ||
          !days.containsKey(dayNumber)) {
        continue;
      }

      final dayName = days[dayNumber]!;
      final start = _formatLocalTime(open);

      // A period without "close" can represent a 24-hour period.
      final end =
      close == null ? '24:00' : _formatLocalTime(close);

      if (start.isNotEmpty && end.isNotEmpty) {
        result[dayName]!.add('$start-$end');
      }
    }

    return result;
  }

  static String _formatLocalTime(
      Map<String, dynamic> point,
      ) {
    final hour =
        (point['hour'] as num?)?.toInt() ?? 0;

    final minute =
        (point['minute'] as num?)?.toInt() ?? 0;

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // FIRST ONLINE GOOGLE PHOTO FOR AN EXISTING FIRESTORE PLACE
  // ============================================================

  /// Fetches the first Google photo for a stored Google Place ID.
  ///
  /// Nothing is written to Firestore or Firebase Storage.
  /// This is intended for UI display (management list, user cards, detail page).
  Future<GooglePlacePhoto?> getFirstPhotoForPlace(
      String placeId,
      ) async {
    _ensureConfigured();

    final id = placeId.trim();

    if (id.isEmpty) {
      return null;
    }

    final uri = Uri.parse(
      '$_baseUrl/places/$id',
    ).replace(
      queryParameters: const {
        'languageCode': 'en',
        'regionCode': 'MY',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': 'photos',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Google photo lookup failed '
            '(${response.statusCode}): ${response.body}',
      );
    }

    final data =
    jsonDecode(response.body) as Map<String, dynamic>;

    final rawPhotos = data['photos'];

    if (rawPhotos is! List || rawPhotos.isEmpty) {
      return null;
    }

    final first = rawPhotos.first;

    if (first is! Map<String, dynamic>) {
      return null;
    }

    final photo = GooglePlacePhoto.fromJson(first);

    return photo.name.trim().isEmpty ? null : photo;
  }

  /// Convenience method: Place ID -> fresh photo resource -> online photo URI.
  ///
  /// The returned URI is for display only. Do not persist it in Firestore.
  Future<String> getFirstPhotoUriForPlace(
      String placeId, {
        int maxWidthPx = 700,
      }) async {
    final photo = await getFirstPhotoForPlace(placeId);

    if (photo == null) {
      return '';
    }

    return getPhotoUri(
      photo,
      maxWidthPx: maxWidthPx,
    );
  }

}
