import 'dart:convert';

import 'package:http/http.dart' as http;

class GeoapifyAttractionCandidate {
  final String placeId;
  final String name;
  final String state;
  final String area;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> categories;
  String categoryName;

  GeoapifyAttractionCandidate({
    required this.placeId,
    required this.name,
    required this.state,
    required this.area,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.categories,
    required this.categoryName,
  });
}

class GeoapifyAttractionDetails {
  final String description;
  final String openingTime;
  final String closingTime;
  final String phoneNumber;
  final List<String> facilities;
  final List<String> highlights;
  final String imageUrl;

  const GeoapifyAttractionDetails({
    this.description = '',
    this.openingTime = '',
    this.closingTime = '',
    this.phoneNumber = '',
    this.facilities = const [],
    this.highlights = const [],
    this.imageUrl = '',
  });
}

class GeoapifyAttractionService {
  final String apiKey;

  const GeoapifyAttractionService({
    required this.apiKey,
  });

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  Future<({double lat, double lon})> geocodeArea({
    required String area,
    String? state,
  }) async {
    _checkApiKey();

    final parts = <String>[
      area.trim(),
      if (state != null && state.trim().isNotEmpty) state.trim(),
      'Malaysia',
    ];

    final uri = Uri.https(
      'api.geoapify.com',
      '/v1/geocode/search',
      {
        'text': parts.join(', '),
        'filter': 'countrycode:my',
        'limit': '1',
        'format': 'json',
        'apiKey': apiKey,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Geoapify geocoding failed (${response.statusCode}).',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? const [];

    if (results.isEmpty) {
      throw Exception('Could not find "$area" in Malaysia.');
    }

    final first = Map<String, dynamic>.from(results.first as Map);
    final lat = _toDouble(first['lat']);
    final lon = _toDouble(first['lon']);

    if (lat == null || lon == null) {
      throw Exception('Geoapify returned invalid coordinates.');
    }

    return (lat: lat, lon: lon);
  }

  Future<List<GeoapifyAttractionCandidate>> searchAttractions({
    required String area,
    String? state,
    int radiusMeters = 20000,
    int limit = 60,
  }) async {
    _checkApiKey();

    final center = await geocodeArea(
      area: area,
      state: state,
    );

    final uri = Uri.https(
      'api.geoapify.com',
      '/v2/places',
      {
        'categories': 'tourism.attraction,tourism.sights,heritage',
        'filter': 'circle:${center.lon},${center.lat},$radiusMeters',
        'bias': 'proximity:${center.lon},${center.lat}',
        'limit': '$limit',
        'lang': 'en',
        'apiKey': apiKey,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Geoapify Places search failed (${response.statusCode}).',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (data['features'] as List?) ?? const [];

    final result = <GeoapifyAttractionCandidate>[];
    final seen = <String>{};

    for (final rawFeature in features) {
      final feature = Map<String, dynamic>.from(rawFeature as Map);
      final properties = Map<String, dynamic>.from(
        (feature['properties'] as Map?) ?? const {},
      );

      final name = (properties['name'] ?? '').toString().trim();
      final placeId = (properties['place_id'] ?? '').toString().trim();

      if (name.isEmpty || placeId.isEmpty || !seen.add(placeId)) {
        continue;
      }

      final countryCode =
          (properties['country_code'] ?? '').toString().toLowerCase();

      if (countryCode.isNotEmpty && countryCode != 'my') {
        continue;
      }

      final categories = ((properties['categories'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();

      final returnedState =
          (properties['state'] ?? state ?? '').toString().trim();

      final returnedArea = _firstNonEmpty([
        properties['city'],
        properties['district'],
        properties['suburb'],
        properties['county'],
        area,
      ]);

      result.add(
        GeoapifyAttractionCandidate(
          placeId: placeId,
          name: name,
          state: returnedState,
          area: returnedArea,
          address: (properties['formatted'] ?? '').toString().trim(),
          latitude: _toDouble(properties['lat']) ?? center.lat,
          longitude: _toDouble(properties['lon']) ?? center.lon,
          categories: categories,
          categoryName: mapCategoryName(categories),
        ),
      );
    }

    result.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return result;
  }

  Future<GeoapifyAttractionDetails> getPlaceDetails(
    GeoapifyAttractionCandidate candidate,
  ) async {
    _checkApiKey();

    final uri = Uri.https(
      'api.geoapify.com',
      '/v2/place-details',
      {
        'id': candidate.placeId,
        'features': 'details',
        'lang': 'en',
        'apiKey': apiKey,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      return GeoapifyAttractionDetails(
        highlights: _highlightsFromCategories(candidate.categories),
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (data['features'] as List?) ?? const [];

    Map<String, dynamic>? details;

    for (final raw in features) {
      final feature = Map<String, dynamic>.from(raw as Map);
      final props = Map<String, dynamic>.from(
        (feature['properties'] as Map?) ?? const {},
      );

      if ((props['feature_type'] ?? '').toString() == 'details') {
        details = props;
        break;
      }
    }

    if (details == null) {
      return GeoapifyAttractionDetails(
        highlights: _highlightsFromCategories(candidate.categories),
      );
    }

    final contact = Map<String, dynamic>.from(
      (details['contact'] as Map?) ?? const {},
    );

    final media = Map<String, dynamic>.from(
      (details['wiki_and_media'] as Map?) ?? const {},
    );

    final facilities = <String>[];

    if (details['wheelchair'] == true) {
      facilities.add('Wheelchair Accessible');
    }
    if (details['toilets'] == true) {
      facilities.add('Toilets');
    }
    if (details['internet_access'] == true) {
      facilities.add('Internet Access');
    }
    if (details['dogs'] == true) {
      facilities.add('Dogs Allowed');
    }
    if (details['air_conditioning'] == true) {
      facilities.add('Air Conditioning');
    }
    if (details['changing_table'] == true) {
      facilities.add('Baby Changing Facility');
    }
    if (details['outdoor_seating'] == true) {
      facilities.add('Outdoor Seating');
    }

    final hours = _parseOpeningHours(
      (details['opening_hours'] ?? '').toString(),
    );

    String description =
        (details['description'] ?? '').toString().trim();

    if (description.isEmpty && details['heritage'] is Map) {
      final heritage = Map<String, dynamic>.from(details['heritage'] as Map);
      description = (heritage['description'] ?? '').toString().trim();
    }

    return GeoapifyAttractionDetails(
      description: description,
      openingTime: hours.$1,
      closingTime: hours.$2,
      phoneNumber: (contact['phone'] ?? '').toString().trim(),
      facilities: facilities,
      highlights: _highlightsFromCategories(candidate.categories),
      imageUrl: (media['image'] ?? '').toString().trim(),
    );
  }

  String mapCategoryName(List<String> categories) {
    final joined = categories.join('|').toLowerCase();

    if (joined.contains('heritage') ||
        joined.contains('historic') ||
        joined.contains('archaeological')) {
      return 'Cultural & Heritage';
    }

    if (joined.contains('viewpoint') ||
        joined.contains('natural') ||
        joined.contains('park') ||
        joined.contains('garden')) {
      return 'Nature & Scenic';
    }

    if (joined.contains('museum') ||
        joined.contains('gallery') ||
        joined.contains('artwork')) {
      return 'Arts & Culture';
    }

    if (joined.contains('religion') ||
        joined.contains('place_of_worship')) {
      return 'Religious & Cultural';
    }

    return 'Tourist Attraction';
  }

  List<String> _highlightsFromCategories(List<String> categories) {
    final result = <String>[];
    final joined = categories.join('|').toLowerCase();

    if (joined.contains('heritage')) result.add('Heritage Site');
    if (joined.contains('unesco')) result.add('UNESCO Heritage');
    if (joined.contains('viewpoint')) result.add('Scenic Viewpoint');
    if (joined.contains('archaeological')) result.add('Archaeological Site');
    if (joined.contains('artwork')) result.add('Art & Culture');
    if (result.isEmpty) result.add('Tourist Attraction');

    return result;
  }

  (String, String) _parseOpeningHours(String raw) {
    final match = RegExp(
      r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})',
    ).firstMatch(raw);

    if (match == null) return ('', '');

    return (
      match.group(1) ?? '',
      match.group(2) ?? '',
    );
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void _checkApiKey() {
    if (!hasApiKey) {
      throw Exception(
        'Geoapify API key is missing. Run with '
        '--dart-define=GEOAPIFY_API_KEY=YOUR_KEY',
      );
    }
  }
}
