import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;

import '../data/transport_data.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';

/// Finds a real shared-bike option using OpenStreetMap community map data,
/// completely independent of HERE.
///
/// Context: HereTransitService.searchBikeShare talks to HERE's Intermodal
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
/// Deliberately isolated the same way HereTransitService.searchBikeShare is:
/// called *in addition to* the main search (works with or without a HERE
/// key - Overpass needs none), and any failure - network error, rate limit,
/// unexpected shape, or simply no station near this particular route - just
/// means zero bike options are added, never an error that could take down
/// the rest of the results.
class OsmBikeShareService {
  OsmBikeShareService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';

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
  }) async {
    try {
      final query =
          '[out:json][timeout:15];'
          '('
          'node["amenity"="bicycle_rental"](around:$_stationSearchRadiusMeters,${from.lat},${from.lng});'
          'node["amenity"="bicycle_rental"](around:$_stationSearchRadiusMeters,${to.lat},${to.lng});'
          ');'
          'out body;';

      final uri = Uri.parse(_overpassUrl).replace(queryParameters: {'data': query});

      final response = await _client
          .get(uri, headers: const {'User-Agent': 'collab_assignment_flutter_app/1.0'})
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint(
          '[OsmBikeShareService] Overpass returned ${response.statusCode}: '
          '${response.body}',
        );
        return const [];
      }

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
          final lat = (element['lat'] as num?)?.toDouble();
          final lon = (element['lon'] as num?)?.toDouble();
          if (lat == null || lon == null) continue;
          final tags = element['tags'] as Map<String, dynamic>? ?? const {};
          stations.add(
            _OsmStation(
              name: (tags['name'] as String?) ?? (tags['network'] as String?) ?? 'Bike Station',
              point: LocationPoint(
                name: (tags['name'] as String?) ?? (tags['network'] as String?) ?? 'Bike Station',
                lat: lat,
                lng: lon,
              ),
            ),
          );
        } catch (_) {
          // Skip a single malformed element.
        }
      }
      if (stations.isEmpty) return const [];

      final nearestToOrigin = _nearestWithin(stations, from, _stationSearchRadiusMeters);
      final nearestToDest = _nearestWithin(stations, to, _stationSearchRadiusMeters);

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
      if (nearestToOrigin.point == nearestToDest.point) {
        // Both ends of the trip are within range of the exact same single
        // station - too short a trip for a meaningful bike leg (walking
        // the whole way already covers this case).
        return const [];
      }

      return [
        _buildOption(
          from: from,
          to: to,
          pickupStation: nearestToOrigin,
          dropoffStation: nearestToDest,
          departAt: departAt,
        ),
      ];
    } catch (error) {
      debugPrint('[OsmBikeShareService] failed: $error');
      return const [];
    }
  }

  _OsmStation? _nearestWithin(List<_OsmStation> stations, LocationPoint point, num maxMeters) {
    _OsmStation? best;
    var bestDistance = double.infinity;
    for (final station in stations) {
      final meters = _distance(
        ll.LatLng(point.lat, point.lng),
        ll.LatLng(station.point.lat, station.point.lng),
      );
      if (meters <= maxMeters && meters < bestDistance) {
        best = station;
        bestDistance = meters;
      }
    }
    return best;
  }

  RideOption _buildOption({
    required LocationPoint from,
    required LocationPoint to,
    required _OsmStation pickupStation,
    required _OsmStation dropoffStation,
    required DateTime departAt,
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
        TripLeg(mode: mode, title: title, subtitle: subtitle, start: start, end: end, isTransfer: false),
      );
      totalCostRm += (kCostPerKmByMode[mode] ?? 0.1) * km;
      totalCo2Kg += (kCo2PerKmByMode[mode] ?? 0.0) * km;
      cursor = end;
    }

    final walkToStationKm = _distance(ll.LatLng(from.lat, from.lng), ll.LatLng(pickupStation.point.lat, pickupStation.point.lng)) / 1000.0;
    final bikeKm = _distance(
          ll.LatLng(pickupStation.point.lat, pickupStation.point.lng),
          ll.LatLng(dropoffStation.point.lat, dropoffStation.point.lng),
        ) /
        1000.0;
    final walkFromStationKm = _distance(ll.LatLng(dropoffStation.point.lat, dropoffStation.point.lng), ll.LatLng(to.lat, to.lng)) / 1000.0;

    addLeg(TransportMode.walk, 'Walk to ${pickupStation.name}', '⇄  Walk', walkToStationKm);
    addLeg(TransportMode.bike, 'Shared Bike', '(${pickupStation.name} → ${dropoffStation.name})', bikeKm);
    addLeg(TransportMode.walk, 'Walk to destination', '⇄  Walk', walkFromStationKm);

    if (totalCostRm < 0.5) totalCostRm = 0.5;

    return RideOption(
      id: 'osm-bike-${from.name}-${to.name}-${departAt.millisecondsSinceEpoch}'.hashCode.toString(),
      title: 'Shared Bike',
      legs: legs,
      estCostRm: totalCostRm,
      co2Kg: totalCo2Kg,
      isLiveData: true,
      searchDepartAt: departAt,
      tags: const ['Real Bike Station (OSM)', 'Low Carbon'],
      path: [from, pickupStation.point, dropoffStation.point, to],
    );
  }

  void dispose() => _client.close();
}

class _OsmStation {
  const _OsmStation({required this.name, required this.point});
  final String name;
  final LocationPoint point;
}
