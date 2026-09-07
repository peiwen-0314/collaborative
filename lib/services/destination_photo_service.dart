import 'dart:convert';

import 'package:http/http.dart' as http;

class DestinationPhotoService {
  const DestinationPhotoService._();

  static final Uri _searchBase = Uri.parse(
    'https://en.wikipedia.org/w/api.php',
  );

  static final Map<String, String?> _cache = {};

  static Future<String?> fetchPhotoUrl(String placeName) async {
    final query = placeName.trim();
    if (query.isEmpty) return null;
    if (_cache.containsKey(query)) return _cache[query];

    for (final candidate in _candidateQueries(query)) {
      final url = await _fetchPhotoForQuery(candidate);
      if (url != null) return _cache[query] = url;
    }
    return _cache[query] = null;
  }

  static List<String> _candidateQueries(String placeName) {
    final segments = placeName
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length <= 1) return [placeName];

    final candidates = <String>[placeName];
    for (var dropCount = 1; dropCount < segments.length; dropCount++) {
      candidates.add(segments.skip(dropCount).join(', '));
    }
    return candidates;
  }

  static Future<String?> _fetchPhotoForQuery(String query) async {
    try {
      final title = await _bestMatchingTitle(query);
      if (title == null) return null;

      final summaryUri = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/'
        '${Uri.encodeComponent(title)}',
      );
      final response = await http
          .get(summaryUri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final thumbnail = data['thumbnail'] as Map<String, dynamic>?;
      final original = data['originalimage'] as Map<String, dynamic>?;
      return (original?['source'] as String?) ??
          (thumbnail?['source'] as String?);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _bestMatchingTitle(String query) async {
    final uri = _searchBase.replace(
      queryParameters: {
        'action': 'query',
        'list': 'search',
        'srsearch': query,
        'srlimit': '1',
        'format': 'json',
        'origin': '*',
      },
    );
    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results =
        (data['query'] as Map<String, dynamic>?)?['search'] as List?;
    if (results == null || results.isEmpty) return null;
    return (results.first as Map<String, dynamic>)['title'] as String?;
  }
}
