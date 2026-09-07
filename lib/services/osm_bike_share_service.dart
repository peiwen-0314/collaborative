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

class OsmBikeShareService {
  OsmBikeShareService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _overpassUrls = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  static const _stationSearchRadiusMeters = 1200;

  static const _distance = ll.Distance();

  Future<List<RideOption>> searchBikeShare({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
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
        final score = walkTo + walkFrom + bikeMeters * 0.08;
        if (score < bestScore) {
          bestScore = score;
          best = (pickup: pickup, dropoff: dropoff);
        }
      }
    }
    return best;
  }

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
