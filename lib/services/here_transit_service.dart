import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../data/transport_data.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';
import 'debug_file_writer_stub.dart'
    if (dart.library.io) 'debug_file_writer_io.dart';
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
  HereTransitService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://transit.router.hereapi.com/v8/routes';

  /// A separate HERE product (https://intermodal.router.hereapi.com) from
  /// the Public Transit API v8 used by [search] above - this is the one
  /// that can actually combine transit with a taxi leg or a bicycle leg
  /// (rented/shared bike-share) in one
  /// real route, which the Public Transit API never returns at all: it
  /// only ever produces public-transit + walk combinations. Used by
  /// [searchIntermodal].
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
      response = await _client.get(uri).timeout(const Duration(seconds: 10));
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
    debugWriteHereResponse('search', body);

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

  /// Shared HTTP call + parse for the Intermodal Routing API - both
  /// Shared HTTP call + parse for the Intermodal Routing API, used by
  /// [searchIntermodal] with a specific [extraParams] to steer which real
  /// modes HERE is allowed to combine. Every route HERE actually returns
  /// is parsed and kept via the same generic [_parseRoute] the main
  /// [search] uses - no filtering by "does this contain the mode I was
  /// hoping for", since that would throw away real combinations (e.g. a
  /// real Transit + Taxi route) just because they weren't the specific
  /// one being searched for.
  Future<List<RideOption>> _queryIntermodal({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
    required Map<String, String> extraParams,
    required String idPrefix,
    required String logTag,
  }) async {
    if (!ApiConfig.hasHereApiKey) return const [];

    try {
      final uri = Uri.parse(_intermodalBaseUrl).replace(
        queryParameters: {
          'origin': from.coordinateString,
          'destination': to.coordinateString,
          'time': departAt.toUtc().toIso8601String(),
          // 'actions'/'intermediate' give richer per-section detail
          // (turn-by-turn, interchange points) this app doesn't parse
          // yet, but asking for them costs nothing and keeps this call
          // future-proof; the fields it does use today are the same
          // travelSummary/polyline the main search relies on.
          'return': 'travelSummary,polyline,actions,intermediate',
          'alternatives': '5',
          'apiKey': ApiConfig.hereApiKey,
          ...extraParams,
        },
      );

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

      // Logged (not shown in the UI - this is a debug-console breadcrumb,
      // visible in Android Studio's Run panel) because a silent "nothing
      // extra found" could mean several very different things: HERE
      // genuinely has no real intermodal combination worth offering for
      // this route, this HERE project doesn't have the Intermodal Routing
      // API enabled (it's a separate product from the Public Transit API
      // - see this class's doc), or an outright request error. Without
      // this, all three look identical from the UI, which makes the
      // feature unverifiable.
      if (response.statusCode != 200) {
        debugPrint(
          '[$logTag] HERE Intermodal Routing returned '
          '${response.statusCode}: ${response.body}',
        );
        return const [];
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      debugWriteHereResponse(logTag, body);
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        debugPrint('[$logTag] HERE returned zero routes.');
        return const [];
      }

      final options = <RideOption>[];
      for (var i = 0; i < routes.length; i++) {
        final route = routes[i] as Map<String, dynamic>;
        // Logged for every route, not just failures - this is the only
        // way to actually verify a section HERE calls "rented"/"vehicle"
        // bicycle (i.e. a real bike-share dock or a real personal-bike
        // leg it computed) rather than trust the parsed title alone.
        // Includes each section's real lat/lng so a specific station's
        // location can be checked against a map if it looks implausible
        // (see e.g. TransportService/HereTransitService's user-reported
        // "does this bike station really exist near here" checks).
        _logRouteSections(logTag, i, route);
        try {
          options.add(
            _parseRoute(
              route,
              index: i,
              from: from,
              to: to,
              fallbackStart: departAt,
              idPrefix: idPrefix,
              tags: const ['Live Route'],
            ),
          );
        } catch (_) {
          // Skip a single malformed route rather than losing the whole
          // call - a partial real result is still better than none.
        }
      }
      return options;
    } catch (error) {
      debugPrint('[$logTag] failed: $error');
      return const [];
    }
  }

  /// Debug-console breadcrumb (Android Studio's Run panel, not shown in
  /// the UI) listing every section HERE actually put in route [index]:
  /// its raw `type`/`transport.mode`, the real place name, and - when
  /// HERE included it - the real lat/lng of that place. This is what
  /// makes a surprising-looking result checkable: "the app claims there's
  /// a bike-share station at X" is either really true (HERE's own real
  /// operator data says so - check the printed coordinates on a map) or
  /// a genuine data-quality gap in HERE's coverage for this area, not
  /// something this app's parsing invented - and now there's a way to
  /// tell the difference from the console.
  void _logRouteSections(String logTag, int index, Map<String, dynamic> route) {
    final sections = route['sections'] as List?;
    if (sections == null) return;
    final summary = sections
        .map((raw) {
          final section = raw as Map<String, dynamic>;
          final transport = section['transport'] as Map<String, dynamic>?;
          final departure = section['departure'] as Map<String, dynamic>?;
          final place = departure?['place'] as Map<String, dynamic>?;
          final location = place?['location'] as Map<String, dynamic>?;
          final placeName = place?['name'] as String?;
          final lat = location?['lat'];
          final lng = location?['lng'];
          final coords = (lat != null && lng != null) ? ' @($lat,$lng)' : '';
          return '${section['type']}/${transport?['mode']}'
              '${placeName != null ? " [$placeName$coords]" : ''}';
        })
        .join(' -> ');
    debugPrint('[$logTag] route $index sections: $summary');
  }

  /// Real intermodal routes from HERE with every mode left at its default
  /// availability - per HERE's own Intermodal Routing API v8 reference,
  /// `transit[enable]`, `taxi[enable]` and `rented[enable]` (shared
  /// bike/scooter) all default to `routeHead,routeTail,entireRoute`
  /// (i.e. already allowed anywhere in the route) without passing
  /// anything special - `vehicle[enable]` (a *personal*, non-shared
  /// vehicle) is deliberately left at its own default of disabled and
  /// never opted into: this app's "Bike" is meant to mean real bike-
  /// *sharing* (a real dock you pick up from and drop off at), not a
  /// personal bike a rider already owns, so only the already-enabled
  /// `rented` category is worth asking HERE for here. `rented[modes]` is
  /// set explicitly to `bicycle` so a shared *bike* is what gets
  /// considered, not a shared scooter/moped HERE might otherwise also
  /// try. So this one call alone can legitimately come back with a real
  /// HERE-computed "Transit + Taxi" or "Transit + Shared Bike" route
  /// whenever HERE itself judges one is worth offering for this trip - no
  /// separate splicing/recombination needed on this app's side, since
  /// HERE already asserts it as one coherent real route with real
  /// waiting/transfer times built in.
  Future<List<RideOption>> searchIntermodal({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
  }) {
    return _queryIntermodal(
      from: from,
      to: to,
      departAt: departAt,
      extraParams: const {
        'rented[modes]': 'bicycle',
        // A slightly tighter walk radius than the API's own 2000m
        // default, to match the ~1.2-1.5km walk assumption the rest of
        // this app already uses elsewhere (see OsmBikeShareService /
        // RealTransitStopService).
        'pedestrian[maxDistance]': '1500',
      },
      idPrefix: 'here-intermodal',
      logTag: 'searchIntermodal',
    );
  }

  /// Best-effort live driving-directions lookup via HERE's standard Routing
  /// API v8 (https://router.hereapi.com) - a THIRD separate HERE product
  /// from both the Public Transit API ([search]) and the Intermodal
  /// Routing API ([searchIntermodal]). This is what actually answers "car"
  /// as a mode: the Transit API only ever returns public-transit + walk
  /// combinations, it has no concept of a private car/e-hailing leg at
  /// all, so without a separate call to this API a live search could never
  /// show a driving option no matter how many transit alternatives HERE
  /// returns for that route. Isolated the same way [searchIntermodal] is:
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
      debugWriteHereResponse('searchDrive', body);
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
    // The actual display label used for each non-walk leg - not just
    // TransportMode.bike.label for every bike leg. This app never asks
    // HERE for a personal-vehicle bicycle leg (see searchIntermodal's
    // doc - only `rented` bike-share is requested), but HERE's `vehicle`
    // (personal bike) and `rented` (bike-share) section types both map
    // to the same TransportMode.bike enum value regardless, so this is
    // kept as a defensive check: if a personal-bike section ever showed
    // up anyway, collapsing it to "Shared Bike" would misrepresent a real
    // bike-share station that was never actually asserted. See the
    // serviceName fallback below.
    final modeLabels = <String>[];
    final routePath = <LocationPoint>[];

    // Computed once per route (not per section) - see
    // MockTransportRepository._buildOption's identical comment for why
    // the search's own starting point is enough here too.
    final searchIsPenang = isPenangArea(from);

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
      final startPoint = _sectionPoint(departure, originName);
      final endPoint = _sectionPoint(arrival, destName);

      // A real personal-bike leg (HERE section type "vehicle") has no
      // operator to name - falling all the way through to mode.label
      // would show "Shared Bike" for it, wrongly implying a real docked
      // bike-share station exists there when HERE never asserted one;
      // only an actual "rented" section is a real shared-bike claim (see
      // the defensive-check note above). For a shared-bike ("rented")
      // section, HERE
      // names the operator rather than a route/headsign - checked
      // defensively in a couple of plausible spots since the exact field
      // placement for this section type wasn't confirmable from this
      // sandbox (no way to make a live call here - see
      // HereTransitService.searchIntermodal's doc comment).
      final isPersonalBike = mode == TransportMode.bike && type == 'vehicle';
      final genericModeLabel = isPersonalBike ? 'Bike' : mode.label;
      final serviceName =
          transport?['name'] as String? ??
          transport?['headsign'] as String? ??
          section['provider'] as String? ??
          transport?['provider'] as String? ??
          genericModeLabel;

      if (!isWalk) modeLabels.add(genericModeLabel);

      final km = lengthMeters / 1000.0;
      // Only a walk genuinely sandwiched between two other legs is a
      // "Transfer" - the very first/last section of a route is just
      // the access/egress walk, same convention OsmBikeShareService
      // uses for its own walk legs. Matching the subtitle text to this
      // (not always saying "Transfer") keeps it consistent with
      // isTransfer, which drives the timeline's white-vs-green styling
      // (see TimelineItem/_TimelineCard) - a leg that says "Transfer"
      // but renders green (or vice versa) previously read as a bug.
      final isWalkTransfer = isWalk && i != 0 && i != sections.length - 1;

      legs.add(
        TripLeg(
          mode: mode,
          title: isWalk ? 'Walk' : serviceName,
          subtitle: isWalk
              ? (isWalkTransfer ? '⇄  Transfer' : '⇄  Walk')
              : '($originName → $destName)',
          start: start,
          end: end,
          isTransfer: isWalkTransfer,
          // Real distance HERE itself reported for this exact section -
          // not derived from an assumed speed constant. Left set even for
          // walk legs (harmless) so TransportService can splice new
          // combination options together from real single-mode legs using
          // each leg's own real distance for its cost/CO2 share - see
          // TripLeg.distanceKm's doc.
          distanceKm: km,
          startPoint: startPoint,
          endPoint: endPoint,
        ),
      );
      totalCostRm += estimateFareRm(
        mode,
        km,
        isPenangArea: searchIsPenang,
      );
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

    // The RM1.50 floor guards against an unrealistically tiny computed
    // fare for a route that DOES ride something real (e.g. one very
    // short bus hop) - it was never meant to apply to a route that's
    // genuinely just walking the whole way, which should cost exactly
    // RM0.00 (see estimateFareRm's TransportMode.walk case). Applying it
    // unconditionally used to show a real "Walk only" alternative (see
    // TripDetailsPage's Edit-a-leg picker) as costing RM1.50 for no
    // reason.
    if (modeLabels.isNotEmpty && totalCostRm < 1) totalCostRm = 1.5;

    final title = modeLabels.isEmpty ? 'Walk' : modeLabels.toSet().join(' + ');

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

  LocationPoint? _sectionPoint(
    Map<String, dynamic>? event,
    String fallbackName,
  ) {
    final place = event?['place'] as Map<String, dynamic>?;
    final location =
        place?['location'] as Map<String, dynamic>? ??
        place?['originalLocation'] as Map<String, dynamic>?;
    final lat = location?['lat'] as num?;
    final lng = location?['lng'] as num?;
    if (lat == null || lng == null) return null;
    final latitude = lat.toDouble();
    final longitude = lng.toDouble();
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return LocationPoint(
      name: place?['name'] as String? ?? fallbackName,
      lat: latitude,
      lng: longitude,
    );
  }

  void dispose() => _client.close();
}
