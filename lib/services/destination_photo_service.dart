import 'dart:convert';

import 'package:http/http.dart' as http;

/// Looks up a free-to-use photo for a named place (e.g. "Ayer Itam") using
/// Wikipedia's public REST API - no API key needed, unlike Google Places
/// Photos / Unsplash / etc, none of which this module has a key for.
///
/// A destination name is very often a full geocoded address ("Jalan Ayer
/// Itam, George Town, Penang, Malaysia") rather than a landmark - the
/// street/POI itself essentially never has its own Wikipedia article, so
/// searching the whole string as-is used to fail constantly and fall
/// through to TripDetailsPage's `_DestinationMap` (a map pin, not a
/// photo - not what a "show me a picture of where I'm going" header
/// should be). [fetchPhotoUrl] instead tries a series of real, still-
/// genuinely-that-place queries, broadest-last: the full address first,
/// then each comma-separated address progressively stripped of its
/// leading (most specific) segment - "George Town, Penang, Malaysia",
/// then "Penang, Malaysia", then "Malaysia" - stopping at the first one
/// that has a real Wikipedia lead photo. This is still always a real
/// photo of a real place the destination is actually in (never an
/// invented or generic stock image), just not always of the exact
/// street - only once every single one of those (down to the country
/// itself) somehow has no photo does a caller fall back to
/// `_DestinationMap`.
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

    for (final candidate in _candidateQueries(query)) {
      final url = await _fetchPhotoForQuery(candidate);
      if (url != null) return _cache[query] = url;
    }
    return _cache[query] = null;
  }

  /// Real, broadest-last search queries for [placeName] - see this
  /// class's own doc comment. A plain place name with no commas (e.g.
  /// just "Ayer Itam") has nothing to strip, so it's tried once, as-is.
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

  /// One real Wikipedia lookup for a single candidate query - null (not
  /// an error) whenever that specific query's top search hit doesn't
  /// exist or has no lead image, so [fetchPhotoUrl] can just move on to
  /// the next, broader candidate.
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
      // A disambiguation page (or any article with no lead image) is
      // still a legitimate "no photo for this candidate" result, not an
      // error - the caller just tries the next, broader candidate.
      final thumbnail = data['thumbnail'] as Map<String, dynamic>?;
      final original = data['originalimage'] as Map<String, dynamic>?;
      return (original?['source'] as String?) ??
          (thumbnail?['source'] as String?);
    } catch (_) {
      return null;
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
