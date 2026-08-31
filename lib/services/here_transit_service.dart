import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../data/transport_data.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';
import 'here_polyline_service.dart';

/// Thrown whenever a live HERE API call can't produce usable ride options
/// (missing key, network error, unexpected response shape, ...). Callers
/// should catch this and fall back to [MockTransportRepository].
class HereApiException implements Exception {
  HereApiException(this.message);
  final String message;

  @override
  String toString() => 'HereApiException: $message';
}

/// Talks to the HERE Public Transit API v8
/// (https://developer.here.com/documentation/public-transit) to fetch a
/// real multi-modal transit itinerary between two points.
///
/// HERE's transit routing doesn't return fares or CO2 figures, so those are
/// estimated afterwards from each leg's distance using the same per-km
/// tables the offline mock generator uses - the timing/route data itself is
/// real, only cost/CO2 are estimates.
class HereTransitService implements TransportRepository {
  HereTransitService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://transit.router.hereapi.com/v8/routes';

  /// A separate HERE product (https://intermodal.router.hereapi.com) from
  /// the Public Transit API v8 used by [search] above - this one can
  /// include a "rented" bicycle section (a shared-bike leg) when HERE has
  /// bike-share operator data for the area, which the Public Transit API
  /// never returns. Used only by [searchBikeShare].
  static const _intermodalBaseUrl =
      'https://intermodal.router.hereapi.com/v8/routes';

  /// HERE's standard (non-transit) Routing API v8 - a third separate HERE
  /// product, used only by [searchDrive] to get a real driving/car leg,
  /// which neither of the two APIs above ever returns.
  static const _routingBaseUrl = 'https://router.hereapi.com/v8/routes';

  @override
  Future<List<RideOption>> search({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
  }) async {
    if (!ApiConfig.hasHereApiKey) {
      throw HereApiException('No HERE_API_KEY configured.');
    }

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'origin': from.coordinateString,
        'destination': to.coordinateString,
        'time': departAt.toUtc().toIso8601String(),
        // 'polyline' gets each section's real road/rail geometry, so the
        // navigation map can follow the actual route instead of drawing a
        // straight line between the origin and destination.
        'return': 'travelSummary,polyline',
        // Without this, HERE only returns its single best route - ask for
        // extra alternatives so the UI has more than one option to show.
        'alternatives': '5',
        'apiKey': ApiConfig.hereApiKey,
      },
    );

    late final http.Response response;
    try {
      response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      throw HereApiException('Network error calling HERE: $error');
    }

    if (response.statusCode != 200) {
      throw HereApiException(
        'HERE returned ${response.statusCode}: ${response.body}',
      );
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (error) {
      throw HereApiException('Could not parse HERE response: $error');
    }

    final routes = body['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw HereApiException('HERE returned no routes.');
    }

    final options = <RideOption>[];
    for (var i = 0; i < routes.length; i++) {
      try {
        options.add(
          _parseRoute(
            routes[i] as Map<String, dynamic>,
            index: i,
            from: from,
            to: to,
            fallbackStart: departAt,
          ),
        );
      } catch (_) {
        // Skip a single malformed route rather than failing the whole
        // search - a partial real result is still better than none.
      }
    }

    if (options.isEmpty) {
      throw HereApiException('None of the HERE routes could be parsed.');
    }
    return options;
  }

  /// Best-effort lookup for a real shared-bike option between [from] and
  /// [to], via the separate Intermodal Routing API (see [_intermodalBaseUrl]
  /// above) rather than the Public Transit API [search] uses. This is
  /// deliberately isolated from [search]: it's called *in addition to* it
  /// (see `TransportService`), never instead of it, and any failure here -
  /// network error, unexpected response shape, or simply no bike-share
  /// coverage for this area - just means zero bike options are added,
  /// never an error that could take down the (already working) transit
  /// results. Only routes that actually contain a real "rented" bicycle
  /// section are kept; pure walk/transit intermodal routes are discarded
  /// since [search] already covers that ground.
  Future<List<RideOption>> searchBikeShare({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
  }) async {
    if (!ApiConfig.hasHereApiKey) return const [];

    try {
      final uri = Uri.parse(_intermodalBaseUrl).replace(
        queryParameters: {
          'origin': from.coordinateString,
          'destination': to.coordinateString,
          'time': departAt.toUtc().toIso8601String(),
          'return': 'travelSummary,polyline',
          'alternatives': '3',
          'apiKey': ApiConfig.hereApiKey,
        },
      );

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

      // Logged (not shown in the UI - this is a debug-console breadcrumb,
      // visible in Android Studio's Run panel) because a silent "no bike
      // option" could mean several very different things: HERE genuinely
      // has no shared-bike data for this route, this HERE project doesn't
      // have the Intermodal Routing API enabled (it's a separate product
      // from the Public Transit API - see HereTransitService's class doc),
      // or an outright request error. Without this, all three look
      // identical from the UI, which makes the feature unverifiable.
      if (response.statusCode != 200) {
        debugPrint(
          '[searchBikeShare] HERE Intermodal Routing returned '
          '${response.statusCode}: ${response.body}',
        );
        return const [];
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        debugPrint('[searchBikeShare] HERE returned zero routes.');
        return const [];
      }

      final bikeOptions = <RideOption>[];
      for (var i = 0; i < routes.length; i++) {
        try {
          final route = routes[i] as Map<String, dynamic>;
          final sections = route['sections'] as List?;
          if (sections == null) continue;

          final sectionTypes = sections
              .map((raw) {
                final section = raw as Map<String, dynamic>;
                final transport = section['transport'] as Map<String, dynamic>?;
                return '${section['type']}/${transport?['mode']}';
              })
              .join(', ');

          final hasSharedBikeLeg = sections.any((raw) {
            final section = raw as Map<String, dynamic>;
            final transport = section['transport'] as Map<String, dynamic>?;
            return section['type'] == 'rented' &&
                transport?['mode'] == 'bicycle';
          });
          if (!hasSharedBikeLeg) {
            debugPrint(
              '[searchBikeShare] route $i has no shared-bike section - '
              'sections were: $sectionTypes',
            );
            continue;
          }

          bikeOptions.add(
            _parseRoute(
              route,
              index: i,
              from: from,
              to: to,
              fallbackStart: departAt,
              idPrefix: 'here-bike',
              tags: const ['Live Route', 'Shared Bike'],
            ),
          );
        } catch (_) {
          // Skip a single malformed route.
        }
      }
      return bikeOptions;
    } catch (error) {
      debugPrint('[searchBikeShare] failed: $error');
      return const [];
    }
  }

  /// Best-effort live driving-directions lookup via HERE's standard Routing
  /// API v8 (https://router.hereapi.com) - a THIRD separate HERE product
  /// from both the Public Transit API ([search]) and the Intermodal
  /// Routing API ([searchBikeShare]). This is what actually answers "car"
  /// as a mode: the Transit API only ever returns public-transit + walk
  /// combinations, it has no concept of a private car/e-hailing leg at
  /// all, so without a separate call to this API a live search could never
  /// show a driving option no matter how many transit alternatives HERE
  /// returns for that route. Isolated the same way [searchBikeShare] is:
  /// called *in addition to* the transit search, never instead of it, and
  /// any failure - network error, this API not enabled on the project,
  /// unexpected shape - just means no drive option gets added.
  Future<RideOption?> searchDrive({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
  }) async {
    if (!ApiConfig.hasHereApiKey) return null;

    try {
      final uri = Uri.parse(_routingBaseUrl).replace(
        queryParameters: {
          'transportMode': 'car',
          'origin': from.coordinateString,
          'destination': to.coordinateString,
          'departureTime': departAt.toUtc().toIso8601String(),
          'return': 'travelSummary,polyline',
          'apiKey': ApiConfig.hereApiKey,
        },
      );

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
          '[searchDrive] HERE Routing API returned '
          '${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        debugPrint('[searchDrive] HERE returned zero driving routes.');
        return null;
      }

      return _parseRoute(
        routes.first as Map<String, dynamic>,
        index: 0,
        from: from,
        to: to,
        fallbackStart: departAt,
        idPrefix: 'here-drive',
        tags: const ['Live Route'],
      );
    } catch (error) {
      debugPrint('[searchDrive] failed: $error');
      return null;
    }
  }

  RideOption _parseRoute(
    Map<String, dynamic> route, {
    required int index,
    required LocationPoint from,
    required LocationPoint to,
    required DateTime fallbackStart,
    String idPrefix = 'here',
    List<String> tags = const ['Live Route'],
  }) {
    final sections = route['sections'] as List?;
    if (sections == null || sections.isEmpty) {
      throw HereApiException('Route has no sections.');
    }

    var cursor = fallbackStart;
    var totalCostRm = 0.0;
    var totalCo2Kg = 0.0;
    final legs = <TripLeg>[];
    final modesUsed = <TransportMode>[];
    final routePath = <LocationPoint>[];

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i] as Map<String, dynamic>;
      final type = section['type'] as String?;
      final transport = section['transport'] as Map<String, dynamic>?;
      final isWalk = type == 'pedestrian' || transport?['mode'] == 'pedestrian';
      final mode = isWalk
          ? TransportMode.walk
          : TransportModeX.fromHereMode(transport?['mode'] as String?);

      final departure = section['departure'] as Map<String, dynamic>?;
      final arrival = section['arrival'] as Map<String, dynamic>?;
      final summary = section['travelSummary'] as Map<String, dynamic>?;
      final durationSeconds = (summary?['duration'] as num?)?.toInt();
      final lengthMeters = (summary?['length'] as num?)?.toDouble() ?? 0;

      final start = _parseTime(departure?['time'] as String?) ?? cursor;
      final end =
          _parseTime(arrival?['time'] as String?) ??
          start.add(Duration(seconds: durationSeconds ?? 300));

      final originName =
          (departure?['place'] as Map<String, dynamic>?)?['name'] as String? ??
          (i == 0 ? from.name : 'Transfer point');
      final destName =
          (arrival?['place'] as Map<String, dynamic>?)?['name'] as String? ??
          (i == sections.length - 1 ? to.name : 'Transfer point');

      // For a shared-bike ("rented") section, HERE names the operator
      // rather than a route/headsign - checked defensively in a couple of
      // plausible spots since the exact field placement for this section
      // type wasn't confirmable from this sandbox (no way to make a live
      // call here - see HereTransitService.searchBikeShare's doc comment).
      final serviceName =
          transport?['name'] as String? ??
          transport?['headsign'] as String? ??
          section['provider'] as String? ??
          transport?['provider'] as String? ??
          mode.label;

      if (!isWalk) modesUsed.add(mode);

      legs.add(
        TripLeg(
          mode: mode,
          title: isWalk ? 'Walk' : serviceName,
          subtitle: isWalk ? '⇄  Transfer' : '($originName → $destName)',
          start: start,
          end: end,
          isTransfer: isWalk && i != 0 && i != sections.length - 1,
        ),
      );

      final km = lengthMeters / 1000.0;
      totalCostRm += (kCostPerKmByMode[mode] ?? 0.1) * km;
      totalCo2Kg += (kCo2PerKmByMode[mode] ?? 0.05) * km;
      cursor = end;

      // Real road/rail geometry for this section, if HERE returned one -
      // best-effort only, see here_polyline_service.dart for why this is
      // wrapped so defensively.
      final polyline = section['polyline'] as String?;
      if (polyline != null) {
        try {
          final decoded = decodeHereFlexiblePolyline(polyline);
          if (looksLikePlausibleRoute(decoded)) {
            routePath.addAll(decoded);
          }
        } catch (_) {
          // Ignore - this section just won't contribute real geometry;
          // the whole route falls back to a straight line if nothing
          // decoded successfully.
        }
      }
    }

    if (totalCostRm < 1) totalCostRm = 1.5;

    final title = modesUsed.isEmpty
        ? 'Walk'
        : modesUsed.map((m) => m.label).toSet().join(' + ');

    return RideOption(
      id: '$idPrefix-${from.name}-${to.name}-$index-${fallbackStart.millisecondsSinceEpoch}'
          .hashCode
          .toString(),
      title: title,
      legs: legs,
      estCostRm: totalCostRm,
      co2Kg: totalCo2Kg,
      isLiveData: true,
      searchDepartAt: fallbackStart,
      tags: tags,
      path: routePath,
    );
  }

  DateTime? _parseTime(String? iso) {
    if (iso == null) return null;
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
