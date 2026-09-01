import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;

import '../models/location_point.dart';
import '../models/transport_mode.dart';

/// What real bus/rail infrastructure OpenStreetMap has mapped near a
/// specific From/To pair, from [RealTransitStopService.findNearby].
class RealTransitAvailability {
  const RealTransitAvailability({
    this.busNearFrom,
    this.busNearTo,
    this.railNearFrom,
    this.railModeNearFrom,
    this.railNearTo,
    this.railModeNearTo,
  });

  final LocationPoint? busNearFrom;
  final LocationPoint? busNearTo;
  final LocationPoint? railNearFrom;
  final TransportMode? railModeNearFrom;
  final LocationPoint? railNearTo;
  final TransportMode? railModeNearTo;

  bool get busAvailable => busNearFrom != null && busNearTo != null;

  /// Only counts as a real rail option if both ends are near a station of
  /// the *same* kind of rail - being near an MRT station at one end and
  /// only a KTM Komuter station at the other isn't one real trip anyone
  /// could actually ride end to end without an extra transfer this app
  /// doesn't model.
  bool get railAvailable =>
      railNearFrom != null &&
      railNearTo != null &&
      railModeNearFrom != null &&
      railModeNearFrom == railModeNearTo;

  TransportMode? get railMode => railAvailable ? railModeNearFrom : null;
}

/// Finds real, community-mapped bus stops and rail stations (MRT/LRT/
/// monorail vs KTM Komuter, distinguished by OSM's `station` tag) near a
/// From/To pair, via OpenStreetMap's free, keyless Overpass API.
///
/// This is the same data source and approach as OsmBikeShareService,
/// generalised to the other scheduled modes: "Bus"/"MRT"/"KTM Komuter"
/// should only ever be offered as a route option when there's a genuine
/// stop/station within walking distance of BOTH ends to actually board
/// and alight at - not because the two points happen to fall inside some
/// distance bracket that "usually has a bus". See
/// `MockTransportRepository._templatesFor` for how this feeds the offline
/// combination generator.
class RealTransitStopService {
  RealTransitStopService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';

  /// How far someone is assumed willing to walk to/from a bus stop or
  /// rail station. Deliberately tighter than OsmBikeShareService's 1.2km
  /// bike-dock radius - bus stops in particular are usually far more
  /// closely spaced in a real network, so a wide radius here would make
  /// "Bus" look available even when the nearest real stop is an
  /// unrealistic walk away.
  static const _searchRadiusMeters = 900;

  static const _distance = ll.Distance();

  Future<RealTransitAvailability> findNearby({
    required LocationPoint from,
    required LocationPoint to,
  }) async {
    try {
      final query =
          '[out:json][timeout:15];'
          '('
          'node["highway"="bus_stop"](around:$_searchRadiusMeters,${from.lat},${from.lng});'
          'node["highway"="bus_stop"](around:$_searchRadiusMeters,${to.lat},${to.lng});'
          'node["amenity"="bus_station"](around:$_searchRadiusMeters,${from.lat},${from.lng});'
          'node["amenity"="bus_station"](around:$_searchRadiusMeters,${to.lat},${to.lng});'
          'node["railway"="station"](around:$_searchRadiusMeters,${from.lat},${from.lng});'
          'node["railway"="station"](around:$_searchRadiusMeters,${to.lat},${to.lng});'
          'node["railway"="halt"](around:$_searchRadiusMeters,${from.lat},${from.lng});'
          'node["railway"="halt"](around:$_searchRadiusMeters,${to.lat},${to.lng});'
          ');'
          'out body;';

      final uri = Uri.parse(_overpassUrl).replace(queryParameters: {'data': query});

      final response = await _client
          .get(uri, headers: const {'User-Agent': 'collab_assignment_flutter_app/1.0'})
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint('[RealTransitStopService] Overpass returned ${response.statusCode}: ${response.body}');
        return const RealTransitAvailability();
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = (body['elements'] as List?) ?? const [];

      final busStops = <LocationPoint>[];
      final railStations = <_RailStation>[];

      for (final raw in elements) {
        try {
          final element = raw as Map<String, dynamic>;
          final lat = (element['lat'] as num?)?.toDouble();
          final lon = (element['lon'] as num?)?.toDouble();
          if (lat == null || lon == null) continue;
          final tags = element['tags'] as Map<String, dynamic>? ?? const {};
          final name = (tags['name'] as String?) ?? 'Stop';

          if (tags['highway'] == 'bus_stop' || tags['amenity'] == 'bus_station') {
            busStops.add(LocationPoint(name: name, lat: lat, lng: lon));
          } else if (tags['railway'] == 'station' || tags['railway'] == 'halt') {
            // `station=subway/light_rail/monorail` covers Malaysia's
            // MRT/LRT/monorail lines; anything else mapped as a rail
            // station/halt (usually untagged, or `station=train`) is
            // treated as KTM Komuter-style heavy rail.
            final stationTag = tags['station'] as String?;
            final mode =
                (stationTag == 'subway' || stationTag == 'light_rail' || stationTag == 'monorail')
                ? TransportMode.mrt
                : TransportMode.train;
            railStations.add(
              _RailStation(point: LocationPoint(name: name, lat: lat, lng: lon), mode: mode),
            );
          }
        } catch (_) {
          // Skip a single malformed element.
        }
      }

      final railFrom = _nearestRail(railStations, from);
      final railTo = _nearestRail(railStations, to);

      final availability = RealTransitAvailability(
        busNearFrom: _nearest(busStops, from),
        busNearTo: _nearest(busStops, to),
        railNearFrom: railFrom?.point,
        railModeNearFrom: railFrom?.mode,
        railNearTo: railTo?.point,
        railModeNearTo: railTo?.mode,
      );

      debugPrint(
        '[RealTransitStopService] bus: from=${availability.busNearFrom?.name} '
        'to=${availability.busNearTo?.name} | rail: from=${availability.railNearFrom?.name} '
        '(${availability.railModeNearFrom}) to=${availability.railNearTo?.name} '
        '(${availability.railModeNearTo})',
      );

      return availability;
    } catch (error) {
      debugPrint('[RealTransitStopService] failed: $error');
      return const RealTransitAvailability();
    }
  }

  LocationPoint? _nearest(List<LocationPoint> points, LocationPoint from) {
    LocationPoint? best;
    var bestDistance = double.infinity;
    for (final point in points) {
      final meters = _distance(ll.LatLng(from.lat, from.lng), ll.LatLng(point.lat, point.lng));
      if (meters <= _searchRadiusMeters && meters < bestDistance) {
        best = point;
        bestDistance = meters;
      }
    }
    return best;
  }

  _RailStation? _nearestRail(List<_RailStation> stations, LocationPoint from) {
    _RailStation? best;
    var bestDistance = double.infinity;
    for (final station in stations) {
      final meters = _distance(
        ll.LatLng(from.lat, from.lng),
        ll.LatLng(station.point.lat, station.point.lng),
      );
      if (meters <= _searchRadiusMeters && meters < bestDistance) {
        best = station;
        bestDistance = meters;
      }
    }
    return best;
  }

  void dispose() => _client.close();
}

class _RailStation {
  const _RailStation({required this.point, required this.mode});
  final LocationPoint point;
  final TransportMode mode;
}
