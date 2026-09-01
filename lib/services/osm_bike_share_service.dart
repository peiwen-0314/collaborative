import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;

import '../data/transport_data.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';
import 'here_transit_service.dart';
import 'transit_hop_finder.dart';

/// Finds a real shared-bike option using OpenStreetMap community map data,
/// completely independent of HERE.
///
/// Context: HereTransitService.searchIntermodal talks to HERE's Intermodal
/// Routing API, which can return a live "rented bicycle" leg *if* HERE has
/// bike-share operator data for the area - but as of testing this app
/// against real Malaysian routes (including George Town, Penang, where the
/// LinkBike bike-share system genuinely operates), HERE returns zero such
/// legs. That's not a bug in this app; a check of MobilityData's global GBFS
/// registry and of LinkBike's own website turned up no public real-time data
/// feed for Malaysia at all, from any source.
///
/// OpenStreetMap is a different kind of source: instead of the *operator*
/// publishing live availability, it relies on volunteer mappers tagging the
/// physical location of a bike-rental station (`amenity=bicycle_rental`).
/// That data is real (these are actual, real-world station coordinates) but
/// it's static/community-maintained, not a live bike-count feed - so unlike
/// HERE's version, this can't say "3 bikes available right now", only
/// "there is a real bike-share station near here". Queried live via the
/// free, keyless Overpass API (https://overpass-api.de) every time this is
/// called - no API key, no quota to manage.
///
/// Deliberately isolated the same way HereTransitService.searchIntermodal is:
/// called *in addition to* the main search (works with or without a HERE
/// key - Overpass needs none), and any failure - network error, rate limit,
/// unexpected shape, or simply no station near this particular route - just
/// means zero bike options are added, never an error that could take down
/// the rest of the results.
class OsmBikeShareService {
  OsmBikeShareService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _overpassUrls = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  /// How far someone is assumed willing to walk to/from a bike station.
  /// 1.2km at the walk speed this app already uses elsewhere (4.5km/h) is
  /// about a 16 minute walk each way - generous enough to actually find a
  /// real station, not so far that "bike-share" stops making sense next to
  /// just walking the whole trip.
  static const _stationSearchRadiusMeters = 1200;

  static const _distance = ll.Distance();

  Future<List<RideOption>> searchBikeShare({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
    // Optional: when given (and a HERE key is configured), a long walk
    // to/from the bike station can be swapped for a real HERE transit
    // hop instead - see `findTransitHop`. Left null, this behaves
    // exactly as before (plain walk legs only).
    HereTransitService? here,
  }) async {
    try {
      final query =
          '[out:json][timeout:15];'
          '('
          'nwr["amenity"="bicycle_rental"](around:$_stationSearchRadiusMeters,${from.lat},${from.lng});'
          'nwr["amenity"="bicycle_rental"](around:$_stationSearchRadiusMeters,${to.lat},${to.lng});'
          'nwr["bicycle_rental"="docking_station"](around:$_stationSearchRadiusMeters,${from.lat},${from.lng});'
          'nwr["bicycle_rental"="docking_station"](around:$_stationSearchRadiusMeters,${to.lat},${to.lng});'
          ');'
          'out center tags;';

      http.Response? response;
      for (final endpoint in _overpassUrls) {
        try {
          final uri = Uri.parse(
            endpoint,
          ).replace(queryParameters: {'data': query});
          final candidate = await _client
              .get(
                uri,
                // A browser (kIsWeb) refuses to let JS set 'User-Agent' at
                // all - it's on the fetch/XHR forbidden-header list, and
                // trying anyway can throw before the request is even sent,
                // which silently killed every Overpass call (and so every
                // Shared Bike option) when running on Chrome/web. Only
                // send it on native platforms, where it's just a polite
                // courtesy to the Overpass operator, not a requirement.
                headers: kIsWeb
                    ? null
                    : const {
                        'User-Agent': 'collab_assignment_flutter_app/1.0',
                      },
              )
              .timeout(const Duration(seconds: 12));
          if (candidate.statusCode == 200) {
            response = candidate;
            break;
          }
          debugPrint(
            '[OsmBikeShareService] $endpoint returned '
            '${candidate.statusCode}. Trying another mirror.',
          );
        } catch (error) {
          // Logged now (used to be swallowed silently) - a web CORS
          // rejection, a network error, and a timeout all used to look
          // identical from the outside (just "no Shared Bike option
          // appeared", no clue why); this makes that diagnosable.
          debugPrint(
            '[OsmBikeShareService] $endpoint request failed: $error. '
            'Trying another mirror.',
          );
        }
      }
      if (response == null) return const [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = body['elements'] as List?;
      if (elements == null || elements.isEmpty) {
        debugPrint(
          '[OsmBikeShareService] No mapped bicycle_rental stations within '
          '${_stationSearchRadiusMeters}m of either end of this route.',
        );
        return const [];
      }

      final stations = <_OsmStation>[];
      for (final raw in elements) {
        try {
          final element = raw as Map<String, dynamic>;
          final center = element['center'] as Map<String, dynamic>?;
          final lat =
              (element['lat'] as num?)?.toDouble() ??
              (center?['lat'] as num?)?.toDouble();
          final lon =
              (element['lon'] as num?)?.toDouble() ??
              (center?['lon'] as num?)?.toDouble();
          if (lat == null || lon == null) continue;
          final tags = element['tags'] as Map<String, dynamic>? ?? const {};
          final baseName =
              (tags['name'] as String?) ??
              (tags['network'] as String?) ??
              (tags['operator'] as String?) ??
              'Bike Station';
          final capacity = tags['capacity']?.toString();
          final name = capacity == null
              ? baseName
              : '$baseName · $capacity docks';
          stations.add(
            _OsmStation(
              osmKey: '${element['type']}:${element['id']}',
              name: name,
              point: LocationPoint(name: name, lat: lat, lng: lon),
            ),
          );
        } catch (_) {
          // Skip a single malformed element.
        }
      }
      if (stations.isEmpty) return const [];

      final pair = _bestStationPair(stations, from, to);
      final nearestToOrigin = pair?.pickup;
      final nearestToDest = pair?.dropoff;

      if (nearestToOrigin == null || nearestToDest == null) {
        // Logged with full coordinates (not just a count) so a route that
        // "almost" works can actually be diagnosed - e.g. "found stations
        // but they're clustered near the destination, none near the
        // origin" is a completely different fix (pick a different origin)
        // than "found nothing anywhere in this city" (no OSM coverage at
        // all here).
        final stationList = stations
            .map((s) => '${s.name} (${s.point.lat}, ${s.point.lng})')
            .join(' | ');
        debugPrint(
          '[OsmBikeShareService] Found ${stations.length} station(s), but '
          'not one near each end of the route - a bike leg needs a station '
          'to pick up from AND a station to drop off at. '
          'origin=(${from.lat}, ${from.lng}) dest=(${to.lat}, ${to.lng}) '
          'stations found: $stationList',
        );
        return const [];
      }

      // Logged on the SUCCESS path too, not just failures - a "Shared
      // Bike" card showing up is a real claim ("there's a real docked
      // bike-share station here"), and that claim is only checkable if
      // its exact source is visible. osm.org/<type>/<id> opens the exact
      // OSM node this app used - if it's a real, community-mapped station
      // it'll show right there (name, tags, edit history); if the link
      // is broken or the location looks wrong, that's a real OSM data
      // quality issue for this specific station, not something this
      // app's code invented.
      debugPrint(
        '[OsmBikeShareService] using pickup=${nearestToOrigin.name} '
        '(${nearestToOrigin.point.lat},${nearestToOrigin.point.lng}) '
        'https://www.openstreetmap.org/${nearestToOrigin.osmKey.replaceFirst(':', '/')} '
        '| dropoff=${nearestToDest.name} '
        '(${nearestToDest.point.lat},${nearestToDest.point.lng}) '
        'https://www.openstreetmap.org/${nearestToDest.osmKey.replaceFirst(':', '/')}',
      );

      return await _buildOptions(
        from: from,
        to: to,
        pickupStation: nearestToOrigin,
        dropoffStation: nearestToDest,
        departAt: departAt,
        here: here,
      );
    } catch (error) {
      debugPrint('[OsmBikeShareService] failed: $error');
      return const [];
    }
  }

  ({_OsmStation pickup, _OsmStation dropoff})? _bestStationPair(
    List<_OsmStation> stations,
    LocationPoint from,
    LocationPoint to,
  ) {
    ({_OsmStation pickup, _OsmStation dropoff})? best;
    var bestScore = double.infinity;
    for (final pickup in stations) {
      final walkTo = _distance(
        ll.LatLng(from.lat, from.lng),
        ll.LatLng(pickup.point.lat, pickup.point.lng),
      );
      if (walkTo > _stationSearchRadiusMeters) continue;
      for (final dropoff in stations) {
        if (pickup.osmKey == dropoff.osmKey) continue;
        final walkFrom = _distance(
          ll.LatLng(dropoff.point.lat, dropoff.point.lng),
          ll.LatLng(to.lat, to.lng),
        );
        if (walkFrom > _stationSearchRadiusMeters) continue;
        final bikeMeters = _distance(
          ll.LatLng(pickup.point.lat, pickup.point.lng),
          ll.LatLng(dropoff.point.lat, dropoff.point.lng),
        );
        if (bikeMeters < 350) continue;
        // Walking dominates inconvenience; a small bike-distance weight
        // breaks ties without choosing a faraway dock just to save a few
        // metres of walking at one end.
        final score = walkTo + walkFrom + bikeMeters * 0.08;
        if (score < bestScore) {
          bestScore = score;
          best = (pickup: pickup, dropoff: dropoff);
        }
      }
    }
    return best;
  }

  /// Builds the walk-based "Shared Bike" option, and - only when a real
  /// HERE bus/train hop exists for the walk to and/or from the station -
  /// a second option that rides that hop instead. Both are returned
  /// side by side rather than this service silently picking one for the
  /// rider: a bus that's slower than walking is still a real, valid
  /// choice for someone who'd rather sit down than walk 10+ minutes, so
  /// the rider gets to compare "walk to the station" against "take the
  /// bus to the station" themselves - see findTransitHop's doc comment
  /// for why a slower-than-walking hop is no longer silently discarded.
  Future<List<RideOption>> _buildOptions({
    required LocationPoint from,
    required LocationPoint to,
    required _OsmStation pickupStation,
    required _OsmStation dropoffStation,
    required DateTime departAt,
    HereTransitService? here,
  }) async {
    final walkToStationKm =
        _distance(
          ll.LatLng(from.lat, from.lng),
          ll.LatLng(pickupStation.point.lat, pickupStation.point.lng),
        ) /
        1000.0;
    final bikeKm =
        _distance(
          ll.LatLng(pickupStation.point.lat, pickupStation.point.lng),
          ll.LatLng(dropoffStation.point.lat, dropoffStation.point.lng),
        ) /
        1000.0;
    final walkFromStationKm =
        _distance(
          ll.LatLng(dropoffStation.point.lat, dropoffStation.point.lng),
          ll.LatLng(to.lat, to.lng),
        ) /
        1000.0;

    // Built first (always walk both ends) so its own real, sequentially-
    // computed timeline can anchor the last-mile HERE query below -
    // see `afterBikeCursor`.
    final walkOption = _composeOption(
      from: from,
      to: to,
      pickupStation: pickupStation,
      dropoffStation: dropoffStation,
      departAt: departAt,
      walkToStationKm: walkToStationKm,
      bikeKm: bikeKm,
      walkFromStationKm: walkFromStationKm,
      firstMileHop: null,
      lastMileHop: null,
    );

    // First mile: only bother asking HERE for a real bus/train hop when
    // the plain walk to the pickup station is long enough to be worth
    // checking (see `kLongWalkThresholdKm`) - a station two minutes away
    // should just stay a walk.
    final hopFirst = walkToStationKm > kLongWalkThresholdKm
        ? await findTransitHop(
            here: here,
            from: from,
            to: pickupStation.point,
            departAt: departAt,
            plainWalkKm: walkToStationKm,
          )
        : null;
    if (hopFirst == null && walkToStationKm <= kLongWalkThresholdKm) {
      debugPrint(
        '[OsmBikeShareService] first-mile walk to '
        '${pickupStation.name} is ${walkToStationKm.toStringAsFixed(2)}km '
        '(<= ${kLongWalkThresholdKm}km threshold) - not worth checking a '
        'bus for.',
      );
    }

    // Last mile: same idea, from the drop-off station to the real
    // destination - anchored to when the bike ride would actually end
    // IN THE TRANSIT VARIANT specifically (not the walk-only option's
    // timing), which differs whenever a first-mile hop was found: a
    // real bus/train rarely takes exactly as long as the plain walk it
    // replaces, so anchoring to the wrong timeline here previously
    // produced a last-mile bus spliced in at the wrong time (arriving
    // before it even departed, in the worst case).
    final cursorAfterFirstMile = hopFirst != null
        ? hopFirst.legs.last.end
        : departAt.add(
            Duration(
              minutes: ((walkToStationKm / 4.5) * 60).clamp(1, 999).round(),
            ),
          );
    final afterBikeCursor = cursorAfterFirstMile.add(
      Duration(minutes: ((bikeKm / 15.0) * 60).clamp(1, 999).round()),
    );
    final hopLast = walkFromStationKm > kLongWalkThresholdKm
        ? await findTransitHop(
            here: here,
            from: dropoffStation.point,
            to: to,
            departAt: afterBikeCursor,
            plainWalkKm: walkFromStationKm,
          )
        : null;
    if (hopLast == null && walkFromStationKm <= kLongWalkThresholdKm) {
      debugPrint(
        '[OsmBikeShareService] last-mile walk from '
        '${dropoffStation.name} is ${walkFromStationKm.toStringAsFixed(2)}km '
        '(<= ${kLongWalkThresholdKm}km threshold) - not worth checking a '
        'bus for.',
      );
    }

    if (hopFirst == null && hopLast == null) return [walkOption];

    final transitOption = _composeOption(
      from: from,
      to: to,
      pickupStation: pickupStation,
      dropoffStation: dropoffStation,
      departAt: departAt,
      walkToStationKm: walkToStationKm,
      bikeKm: bikeKm,
      walkFromStationKm: walkFromStationKm,
      firstMileHop: hopFirst,
      lastMileHop: hopLast,
    );
    return [walkOption, transitOption];
  }

  /// Builds one concrete "Shared Bike" itinerary. Pass null for
  /// [firstMileHop]/[lastMileHop] to walk that leg (the original
  /// behaviour); pass a real hop from [findTransitHop] to ride it
  /// instead - its own real legs/cost/CO2 (a genuine HERE API response
  /// for that exact hop) are spliced in as-is, never reshaped to fit a
  /// guessed timeline.
  RideOption _composeOption({
    required LocationPoint from,
    required LocationPoint to,
    required _OsmStation pickupStation,
    required _OsmStation dropoffStation,
    required DateTime departAt,
    required double walkToStationKm,
    required double bikeKm,
    required double walkFromStationKm,
    RideOption? firstMileHop,
    RideOption? lastMileHop,
  }) {
    var cursor = departAt;
    final legs = <TripLeg>[];
    var totalCostRm = 0.0;
    var totalCo2Kg = 0.0;

    void addLeg(TransportMode mode, String title, String subtitle, double km) {
      final speedKmh = mode == TransportMode.bike ? 15.0 : 4.5;
      final minutes = ((km / speedKmh) * 60).clamp(1, 999).round();
      final start = cursor;
      final end = start.add(Duration(minutes: minutes));
      legs.add(
        // Unlike a walk *between* two vehicles, walking to the pickup
        // station or from the drop-off station is the entry/exit of the
        // whole trip - matches the convention HereTransitService and the
        // mock generator already use, where only walks sandwiched between
        // two other legs count as a "transfer".
        TripLeg(
          mode: mode,
          title: title,
          subtitle: subtitle,
          start: start,
          end: end,
          isTransfer: false,
          distanceKm: km,
        ),
      );
      totalCostRm += (kCostPerKmByMode[mode] ?? 0.1) * km;
      totalCo2Kg += (kCo2PerKmByMode[mode] ?? 0.0) * km;
      cursor = end;
    }

    if (firstMileHop != null) {
      // This hop is now the LEADING segment of the whole trip, not a
      // standalone route - its own last leg (arriving at the bike
      // station) needs restyling from "end of a route" to "mid-trip
      // transfer" so the timeline shows it correctly (see
      // asLeadingSegment's doc comment).
      legs.addAll(asLeadingSegment(firstMileHop.legs));
      totalCostRm += firstMileHop.estCostRm;
      totalCo2Kg += firstMileHop.co2Kg;
      cursor = firstMileHop.legs.last.end;
    } else {
      addLeg(
        TransportMode.walk,
        'Walk to ${pickupStation.name}',
        '⇄  Walk',
        walkToStationKm,
      );
    }

    addLeg(
      TransportMode.bike,
      'Shared Bike',
      '(${pickupStation.name} → ${dropoffStation.name})',
      bikeKm,
    );

    if (lastMileHop != null) {
      // Same idea in reverse: this hop's own first leg (walking from
      // the bike drop-off to its bus stop) is a mid-trip transfer here,
      // not the start of a standalone route.
      legs.addAll(asTrailingSegment(lastMileHop.legs));
      totalCostRm += lastMileHop.estCostRm;
      totalCo2Kg += lastMileHop.co2Kg;
      cursor = lastMileHop.legs.last.end;
    } else {
      addLeg(
        TransportMode.walk,
        'Walk to destination',
        '⇄  Walk',
        walkFromStationKm,
      );
    }

    if (totalCostRm < 0.5) totalCostRm = 0.5;

    final usedTransit = firstMileHop != null || lastMileHop != null;
    // Both hops' real bus numbers grouped into ONE "Bus (104 + 11)"
    // segment - not a separate "Bus" word per hop, which used to read
    // as "Bus + Shared Bike + Bus" (two buses, unclear they're
    // different real routes) instead of naming them.
    final busLabels = <String>[
      if (firstMileHop != null) ...hopRouteLabels(firstMileHop),
      if (lastMileHop != null) ...hopRouteLabels(lastMileHop),
    ];
    final title = busLabels.isEmpty
        ? 'Shared Bike'
        : 'Bus (${busLabels.join(' + ')}) + Shared Bike';
    final tags = <String>['Real Bike Station', 'Low Carbon'];
    if (usedTransit) tags.add('Bus to Station');

    final idSuffix = usedTransit ? 'transit' : 'walk';
    final id =
        'osm-bike-$idSuffix-${from.name}-${to.name}-${departAt.millisecondsSinceEpoch}'
            .hashCode
            .toString();

    return RideOption(
      id: id,
      title: title,
      // Splicing a hop's own boundary walk (asLeadingSegment/
      // asTrailingSegment above) next to this option's own walk-to/from-
      // station leg can otherwise leave two "Walk" boxes back to back -
      // see mergeAdjacentWalkLegs' doc comment.
      legs: mergeAdjacentWalkLegs(legs),
      estCostRm: totalCostRm,
      co2Kg: totalCo2Kg,
      isLiveData: true,
      searchDepartAt: departAt,
      tags: tags,
      path: [from, pickupStation.point, dropoffStation.point, to],
    );
  }

  void dispose() => _client.close();
}

class _OsmStation {
  const _OsmStation({
    required this.osmKey,
    required this.name,
    required this.point,
  });
  final String osmKey;
  final String name;
  final LocationPoint point;
}
