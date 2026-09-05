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

  final String categoryName;
  final int qualityScore;

  const GeoapifyAttractionCandidate({
    required this.placeId,
    required this.name,
    required this.state,
    required this.area,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.categories,
    required this.categoryName,
    required this.qualityScore,
  });
}

class GeoapifyAttractionDetails {
  final String description;
  final String openingTime;
  final String closingTime;
  final String phoneNumber;
  final String website;
  final List<String> facilities;
  final List<String> highlights;
  final String imageUrl;

  const GeoapifyAttractionDetails({
    this.description = '',
    this.openingTime = '',
    this.closingTime = '',
    this.phoneNumber = '',
    this.website = '',
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

  static const Map<String, List<String>> stateSearchAreas = {
    'Johor': [
      'Johor Bahru',
      'Desaru',
      'Mersing',
      'Kota Tinggi',
      'Kluang',
      'Batu Pahat',
      'Muar',
    ],
    'Kedah': [
      'Alor Setar',
      'Langkawi',
      'Kuah',
      'Sungai Petani',
      'Kulim',
      'Baling',
    ],
    'Kelantan': [
      'Kota Bharu',
      'Tumpat',
      'Bachok',
      'Pasir Mas',
      'Gua Musang',
    ],
    'Melaka': [
      'Melaka City',
      'Ayer Keroh',
      'Alor Gajah',
      'Jasin',
    ],
    'Negeri Sembilan': [
      'Seremban',
      'Port Dickson',
      'Kuala Pilah',
      'Rembau',
      'Jelebu',
    ],
    'Pahang': [
      'Kuantan',
      'Cameron Highlands',
      'Tanah Rata',
      'Brinchang',
      'Genting Highlands',
      'Bentong',
      'Jerantut',
      'Kuala Tahan',
      'Fraser Hill',
    ],
    'Penang': [
      'George Town',
      'Batu Ferringhi',
      'Air Itam',
      'Balik Pulau',
      'Tanjung Bungah',
      'Butterworth',
      'Bukit Mertajam',
    ],
    'Perak': [
      'Ipoh',
      'Taiping',
      'Kuala Kangsar',
      'Pangkor',
      'Kampar',
      'Gopeng',
      'Lenggong',
    ],
    'Perlis': [
      'Kangar',
      'Arau',
      'Padang Besar',
      'Kuala Perlis',
    ],
    'Sabah': [
      'Kota Kinabalu',
      'Kundasang',
      'Ranau',
      'Sandakan',
      'Semporna',
      'Lahad Datu',
      'Tawau',
      'Kudat',
    ],
    'Sarawak': [
      'Kuching',
      'Miri',
      'Sibu',
      'Bintulu',
      'Bako',
      'Santubong',
      'Lundu',
    ],
    'Selangor': [
      'Shah Alam',
      'Petaling Jaya',
      'Subang Jaya',
      'Klang',
      'Batu Caves',
      'Sepang',
      'Kuala Selangor',
      'Rawang',
    ],
    'Terengganu': [
      'Kuala Terengganu',
      'Marang',
      'Dungun',
      'Kemaman',
      'Besut',
      'Redang Island',
      'Perhentian Island',
    ],
    'Kuala Lumpur': [
      'Kuala Lumpur City Centre',
      'Bukit Bintang',
      'Chinatown Kuala Lumpur',
      'Brickfields',
      'Bukit Nanas',
      'Titiwangsa',
      'Batu Caves',
    ],
    'Labuan': [
      'Victoria Labuan',
      'Labuan',
    ],
    'Putrajaya': [
      'Putrajaya',
      'Precinct 1 Putrajaya',
      'Precinct 2 Putrajaya',
      'Precinct 4 Putrajaya',
    ],
  };

  Future<List<GeoapifyAttractionCandidate>> searchStateAttractions({
    required String state,
    int radiusMeters = 15000,
    int perAreaLimit = 35,
  }) async {
    _checkApiKey();

    final areas = stateSearchAreas[state] ?? [state];

    final Map<String, GeoapifyAttractionCandidate> deduped = {};

    for (final area in areas) {
      try {
        final center = await geocodeArea(
          area: area,
          state: state,
        );

        final fetched = await _searchAroundPoint(
          centerLat: center.lat,
          centerLon: center.lon,
          state: state,
          fallbackArea: area,
          radiusMeters: radiusMeters,
          limit: perAreaLimit,
        );

        for (final item in fetched) {
          final existing = deduped[item.placeId];

          if (existing == null ||
              item.qualityScore > existing.qualityScore) {
            deduped[item.placeId] = item;
          }
        }
      } catch (_) {
        // One bad geocoding area should not stop the whole state search.
      }
    }

    final result = deduped.values.toList();

    result.sort(
          (a, b) {
        final scoreCompare =
        b.qualityScore.compareTo(a.qualityScore);

        if (scoreCompare != 0) {
          return scoreCompare;
        }

        return a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        );
      },
    );

    return result;
  }

  Future<({double lat, double lon})> geocodeArea({
    required String area,
    required String state,
  }) async {
    final uri = Uri.https(
      'api.geoapify.com',
      '/v1/geocode/search',
      {
        'text': '$area, $state, Malaysia',
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
      throw Exception(
        'Could not locate $area, $state.',
      );
    }

    final first =
    Map<String, dynamic>.from(results.first as Map);

    final lat = _toDouble(first['lat']);
    final lon = _toDouble(first['lon']);

    if (lat == null || lon == null) {
      throw Exception('Invalid geocoding coordinates.');
    }

    return (lat: lat, lon: lon);
  }

  Future<List<GeoapifyAttractionCandidate>> _searchAroundPoint({
    required double centerLat,
    required double centerLon,
    required String state,
    required String fallbackArea,
    required int radiusMeters,
    required int limit,
  }) async {
    final uri = Uri.https(
      'api.geoapify.com',
      '/v2/places',
      {
        'categories':
        'tourism.attraction,tourism.sights,heritage,entertainment.museum',
        'filter':
        'circle:$centerLon,$centerLat,$radiusMeters',
        'bias':
        'proximity:$centerLon,$centerLat',
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

    for (final rawFeature in features) {
      final feature =
      Map<String, dynamic>.from(rawFeature as Map);

      final properties =
      Map<String, dynamic>.from(
        (feature['properties'] as Map?) ?? const {},
      );

      final name =
      (properties['name'] ?? '').toString().trim();

      final placeId =
      (properties['place_id'] ?? '').toString().trim();

      if (name.isEmpty || placeId.isEmpty) {
        continue;
      }

      final countryCode =
      (properties['country_code'] ?? '')
          .toString()
          .toLowerCase();

      if (countryCode.isNotEmpty &&
          countryCode != 'my') {
        continue;
      }

      final returnedState =
      (properties['state'] ?? '')
          .toString()
          .trim();

      // Avoid cross-border/state spillover where possible.
      if (returnedState.isNotEmpty &&
          !_sameState(returnedState, state)) {
        continue;
      }

      final categories =
      ((properties['categories'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();

      final area = _firstNonEmpty([
        properties['city'],
        properties['district'],
        properties['suburb'],
        properties['county'],
        fallbackArea,
      ]);

      final address =
      (properties['formatted'] ?? '')
          .toString()
          .trim();

      final website =
      (properties['website'] ?? '')
          .toString()
          .trim();

      final phone =
      (properties['contact'] is Map)
          ? ((properties['contact'] as Map)['phone'] ?? '')
          .toString()
          .trim()
          : '';

      final openingHours =
      (properties['opening_hours'] ?? '')
          .toString()
          .trim();

      final score = _qualityScore(
        name: name,
        address: address,
        categories: categories,
        website: website,
        phone: phone,
        openingHours: openingHours,
      );

      result.add(
        GeoapifyAttractionCandidate(
          placeId: placeId,
          name: name,
          state: state,
          area: area,
          address: address,
          latitude:
          _toDouble(properties['lat']) ?? centerLat,
          longitude:
          _toDouble(properties['lon']) ?? centerLon,
          categories: categories,
          categoryName:
          mapCategoryName(categories),
          qualityScore: score,
        ),
      );
    }

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
        highlights:
        _highlightsFromCategories(candidate.categories),
      );
    }

    final data = jsonDecode(response.body)
    as Map<String, dynamic>;

    final features =
        (data['features'] as List?) ?? const [];

    Map<String, dynamic>? details;

    for (final raw in features) {
      final feature =
      Map<String, dynamic>.from(raw as Map);

      final props =
      Map<String, dynamic>.from(
        (feature['properties'] as Map?) ?? const {},
      );

      if ((props['feature_type'] ?? '').toString() ==
          'details') {
        details = props;
        break;
      }
    }

    if (details == null) {
      return GeoapifyAttractionDetails(
        highlights:
        _highlightsFromCategories(candidate.categories),
      );
    }

    final contact =
    Map<String, dynamic>.from(
      (details['contact'] as Map?) ?? const {},
    );

    final media =
    Map<String, dynamic>.from(
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
    (details['description'] ?? '')
        .toString()
        .trim();

    if (description.isEmpty &&
        details['heritage'] is Map) {
      final heritage =
      Map<String, dynamic>.from(
        details['heritage'] as Map,
      );

      description =
          (heritage['description'] ?? '')
              .toString()
              .trim();
    }

    return GeoapifyAttractionDetails(
      description: description,
      openingTime: hours.$1,
      closingTime: hours.$2,
      phoneNumber:
      (contact['phone'] ?? '').toString().trim(),
      website:
      (details['website'] ?? '').toString().trim(),
      facilities: facilities,
      highlights:
      _highlightsFromCategories(candidate.categories),
      imageUrl:
      (media['image'] ?? '').toString().trim(),
    );
  }

  int _qualityScore({
    required String name,
    required String address,
    required List<String> categories,
    required String website,
    required String phone,
    required String openingHours,
  }) {
    int score = 0;

    if (name.trim().isNotEmpty) score += 2;
    if (address.trim().isNotEmpty) score += 2;
    if (website.trim().isNotEmpty) score += 3;
    if (phone.trim().isNotEmpty) score += 2;
    if (openingHours.trim().isNotEmpty) score += 2;

    final joined =
    categories.join('|').toLowerCase();

    if (joined.contains('tourism.attraction')) {
      score += 5;
    }

    if (joined.contains('tourism.sights')) {
      score += 5;
    }

    if (joined.contains('heritage')) {
      score += 4;
    }

    if (joined.contains('museum')) {
      score += 4;
    }

    if (joined.contains('unesco')) {
      score += 8;
    }

    if (joined.contains('viewpoint')) {
      score += 2;
    }

    if (joined.contains('monument')) {
      score += 2;
    }

    if (joined.contains('memorial')) {
      score += 1;
    }

    return score;
  }

  String mapCategoryName(
      List<String> categories,
      ) {
    final joined =
    categories.join('|').toLowerCase();

    if (joined.contains('heritage') ||
        joined.contains('historic') ||
        joined.contains('archaeological') ||
        joined.contains('monument')) {
      return 'Cultural & Heritage';
    }

    if (joined.contains('museum') ||
        joined.contains('gallery') ||
        joined.contains('artwork')) {
      return 'Arts & Culture';
    }

    if (joined.contains('viewpoint') ||
        joined.contains('natural') ||
        joined.contains('park') ||
        joined.contains('garden')) {
      return 'Nature & Scenic';
    }

    if (joined.contains('religion') ||
        joined.contains('place_of_worship')) {
      return 'Religious & Cultural';
    }

    return 'Tourist Attraction';
  }

  List<String> _highlightsFromCategories(
      List<String> categories,
      ) {
    final result = <String>[];

    final joined =
    categories.join('|').toLowerCase();

    if (joined.contains('heritage')) {
      result.add('Heritage Site');
    }

    if (joined.contains('unesco')) {
      result.add('UNESCO Heritage');
    }

    if (joined.contains('viewpoint')) {
      result.add('Scenic Viewpoint');
    }

    if (joined.contains('museum')) {
      result.add('Museum');
    }

    if (joined.contains('archaeological')) {
      result.add('Archaeological Site');
    }

    if (result.isEmpty) {
      result.add('Tourist Attraction');
    }

    return result;
  }

  (String, String) _parseOpeningHours(
      String raw,
      ) {
    final match = RegExp(
      r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})',
    ).firstMatch(raw);

    if (match == null) {
      return ('', '');
    }

    return (
    match.group(1) ?? '',
    match.group(2) ?? '',
    );
  }

  bool _sameState(
      String returned,
      String expected,
      ) {
    String clean(String value) {
      return value
          .toLowerCase()
          .replaceAll('federal territory of ', '')
          .replaceAll('wilayah persekutuan ', '')
          .trim();
    }

    final a = clean(returned);
    final b = clean(expected);

    return a == b ||
        a.contains(b) ||
        b.contains(a);
  }

  String _firstNonEmpty(
      List<dynamic> values,
      ) {
    for (final value in values) {
      final text =
      (value ?? '').toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  double? _toDouble(
      dynamic value,
      ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
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
