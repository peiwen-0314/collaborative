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

class HereApiException implements Exception {
  HereApiException(this.message);
  final String message;

  @override
  String toString() => 'HereApiException: $message';
}

class HereTransitService implements TransportRepository {
  HereTransitService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://transit.router.hereapi.com/v8/routes';

  static const _intermodalBaseUrl =
      'https://intermodal.router.hereapi.com/v8/routes';

  static const _routingBaseUrl = 'https://router.hereapi.com/v8/routes';

  static const _tightPedestrianParams = {
    'pedestrian[maxDistance]': '1125',
    'pedestrian[speed]': '1.25',
  };

  @override
  Future<List<RideOption>> search({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
  }) async {
    if (!ApiConfig.hasHereApiKey) {
      throw HereApiException('No HERE_API_KEY configured.');
    }

    try {
      return await _fetchRoutes(
        from: from,
        to: to,
        departAt: departAt,
        pedestrianParams: _tightPedestrianParams,
      );
    } on HereApiException catch (error) {
      if (error.message != 'HERE returned no routes.') rethrow;
    }

    return _fetchRoutes(
      from: from,
      to: to,
      departAt: departAt,
      pedestrianParams: const {},
    );
  }

  Future<List<RideOption>> _fetchRoutes({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
    required Map<String, String> pedestrianParams,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'origin': from.coordinateString,
        'destination': to.coordinateString,
        'departureTime': malaysiaWallClockToInstant(departAt).toIso8601String(),
        'return': 'travelSummary,polyline',
        // Without this, HERE only returns its single best route - ask for
        // extra alternatives so the UI has more than one option to show.
        'alternatives': '5',
        ...pedestrianParams,
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
          'departureTime': malaysiaWallClockToInstant(departAt).toIso8601String(),
          'return': 'travelSummary,polyline,actions,intermediate',
          'alternatives': '5',
          'apiKey': ApiConfig.hereApiKey,
          ...extraParams,
        },
      );

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

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
        'pedestrian[maxDistance]': '1125',
        'pedestrian[speed]': '1.25',
      },
      idPrefix: 'here-intermodal',
      logTag: 'searchIntermodal',
    );
  }

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
          'departureTime': malaysiaWallClockToInstant(departAt).toIso8601String(),
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

    final normalizedStart = instantToMalaysiaWallClock(fallbackStart);
    var cursor = normalizedStart;
    var totalCostRm = 0.0;
    var totalCo2Kg = 0.0;
    final legs = <TripLeg>[];
    final modeLabels = <String>[];
    final routePath = <LocationPoint>[];

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
      final isWalkTransfer = isWalk && i != 0 && i != sections.length - 1;

      final polyline = section['polyline'] as String?;

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
          distanceKm: km,
          startPoint: startPoint,
          endPoint: endPoint,
          encodedPolyline: polyline,
        ),
      );
      totalCostRm += estimateFareRm(
        mode,
        km,
        isPenangArea: searchIsPenang,
      );
      totalCo2Kg += (kCo2PerKmByMode[mode] ?? 0.05) * km;
      cursor = end;

      if (polyline != null) {
        try {
          final decoded = decodeHereFlexiblePolyline(polyline);
          if (looksLikePlausibleRoute(decoded)) {
            routePath.addAll(decoded);
          }
        } catch (_) {
        }
      }
    }

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
      searchDepartAt: normalizedStart,
      tags: tags,
      path: routePath,
    );
  }

  DateTime? _parseTime(String? iso) {
    if (iso == null) return null;
    try {
      return instantToMalaysiaWallClock(DateTime.parse(iso));
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
