import 'dart:convert';

import 'package:http/http.dart' as http;

/// Looks up a free-to-use photo for a named place (e.g. "Ayer Itam") using
/// Wikipedia's public REST API - no API key needed, unlike Google Places
/// Photos / Unsplash / etc, none of which this module has a key for.
/// Works well for towns, neighbourhoods and named landmarks (they have a
/// Wikipedia article with a lead image); returns null for anything too
/// specific to have its own article (an ordinary bus stop or street
/// address), so callers need a non-photo fallback - see
/// TripDetailsPage's `_DestinationMap`.
class DestinationPhotoService {
  const DestinationPhotoService._();

  static final Uri _searchBase = Uri.parse(
    'https://en.wikipedia.org/w/api.php',
  );

  /// A short in-memory cache so reopening the same trip's details page
  /// (or two options that share a destination) doesn't refetch every
  /// time - this only lives for the app session, not persisted.
  static final Map<String, String?> _cache = {};

  static Future<String?> fetchPhotoUrl(String placeName) async {
    final query = placeName.trim();
    if (query.isEmpty) return null;
    if (_cache.containsKey(query)) return _cache[query];

    try {
      final title = await _bestMatchingTitle(query);
      if (title == null) return _cache[query] = null;

      final summaryUri = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/'
        '${Uri.encodeComponent(title)}',
      );
      final response = await http
          .get(summaryUri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return _cache[query] = null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // A disambiguation page (or any article with no lead image) is
      // still a legitimate "no photo" result, not an error.
      final thumbnail = data['thumbnail'] as Map<String, dynamic>?;
      final original = data['originalimage'] as Map<String, dynamic>?;
      final url =
          (original?['source'] as String?) ??
          (thumbnail?['source'] as String?);
      return _cache[query] = url;
    } catch (_) {
      return _cache[query] = null;
    }
  }

  /// Wikipedia's summary endpoint needs a real page title, not free text
  /// - "Ayer Itam" happens to already be one, but plenty of place names
  /// aren't quite the article title Wikipedia uses. This runs a real
  /// search first and takes its top hit's title instead of guessing the
  /// title directly.
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
