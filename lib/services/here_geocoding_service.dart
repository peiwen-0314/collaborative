import 'dart:convert';

import 'package:http/http.dart' as http;

class HereCoordinates {
  final double latitude;
  final double longitude;
  final String matchedAddress;

  const HereCoordinates({
    required this.latitude,
    required this.longitude,
    required this.matchedAddress,
  });
}

class HereGeocodingService {
  static const String _apiKey = String.fromEnvironment('HERE_API_KEY');
  static const String _baseUrl =
      'https://geocode.search.hereapi.com/v1/geocode';

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<HereCoordinates?> geocodeAttraction({
    required String name,
    required String address,
    required String area,
    required String state,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'HERE_API_KEY is missing. Run Flutter with '
            '--dart-define=HERE_API_KEY=YOUR_KEY.',
      );
    }

    final queryParts = <String>[
      name.trim(),
      address.trim(),
      area.trim(),
      state.trim(),
      'Malaysia',
    ].where((part) => part.isNotEmpty).toList();

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'q': queryParts.join(', '),
        'in': 'countryCode:MYS',
        'limit': '1',
        'apiKey': _apiKey,
      },
    );

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'HERE geocoding failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final items = decoded['items'];
    if (items is! List || items.isEmpty) return null;

    final first = items.first;
    if (first is! Map) return null;

    final item = Map<String, dynamic>.from(first);
    final rawPosition = item['position'];
    if (rawPosition is! Map) return null;

    final position = Map<String, dynamic>.from(rawPosition);
    final latitude = _toDouble(position['lat']);
    final longitude = _toDouble(position['lng']);

    if (latitude == null || longitude == null) return null;

    final rawAddress = item['address'];
    String matchedAddress = (item['title'] ?? '').toString().trim();

    if (rawAddress is Map) {
      final addressMap = Map<String, dynamic>.from(rawAddress);
      matchedAddress =
          (addressMap['label'] ?? matchedAddress).toString().trim();
    }

    return HereCoordinates(
      latitude: latitude,
      longitude: longitude,
      matchedAddress: matchedAddress,
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
