import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/here_config.dart';
import '../models/here_route_info.dart';

class HereRoutingService {
  HereRoutingService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _baseUrl =
      'https://router.hereapi.com/v8/routes';

  Future<HereRouteInfo> getCarRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    DateTime? departureTime,
  }) async {
    if (!HereConfig.hasApiKey) {
      throw StateError(
        'HERE_API_KEY is missing. Run Flutter with '
            '--dart-define=HERE_API_KEY=YOUR_KEY.',
      );
    }

    final query = <String, String>{
      'transportMode': 'car',
      'routingMode': 'fast',
      'origin':
      '$originLatitude,$originLongitude',
      'destination':
      '$destinationLatitude,$destinationLongitude',
      'return': 'summary',
      'apiKey': HereConfig.apiKey,
    };

    if (departureTime != null) {
      query['departureTime'] =
          _toLocalRfc3339(departureTime);
    }

    final uri = Uri.parse(_baseUrl)
        .replace(queryParameters: query);

    final response = await _client.get(uri);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw HereRoutingException(
        statusCode: response.statusCode,
        message:
        'HERE Routing request failed: ${response.body}',
      );
    }

    final decoded =
    jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Unexpected HERE Routing response.',
      );
    }

    final routes = decoded['routes'];

    if (routes is! List || routes.isEmpty) {
      throw const HereRoutingException(
        message: 'HERE returned no route.',
      );
    }

    final route = routes.first;

    if (route is! Map) {
      throw const FormatException(
        'Invalid HERE route data.',
      );
    }

    final sections = route['sections'];

    if (sections is! List || sections.isEmpty) {
      throw const HereRoutingException(
        message: 'HERE route has no sections.',
      );
    }

    int totalLengthMeters = 0;
    int totalDurationSeconds = 0;
    DateTime? routeDeparture;
    DateTime? routeArrival;

    for (int i = 0; i < sections.length; i++) {
      final rawSection = sections[i];

      if (rawSection is! Map) {
        continue;
      }

      final section =
      Map<String, dynamic>.from(rawSection);

      final rawSummary = section['summary'];

      if (rawSummary is Map) {
        final summary =
        Map<String, dynamic>.from(rawSummary);

        final length = summary['length'];
        final duration = summary['duration'];

        if (length is num) {
          totalLengthMeters += length.round();
        }

        if (duration is num) {
          totalDurationSeconds += duration.round();
        }
      }

      if (i == 0) {
        final departure = section['departure'];

        if (departure is Map) {
          final time = departure['time'];

          if (time is String) {
            routeDeparture =
                DateTime.tryParse(time);
          }
        }
      }

      if (i == sections.length - 1) {
        final arrival = section['arrival'];

        if (arrival is Map) {
          final time = arrival['time'];

          if (time is String) {
            routeArrival =
                DateTime.tryParse(time);
          }
        }
      }
    }

    if (totalDurationSeconds <= 0) {
      throw const HereRoutingException(
        message:
        'HERE returned an invalid route duration.',
      );
    }

    return HereRouteInfo(
      distanceKm:
      totalLengthMeters / 1000.0,
      durationSeconds:
      totalDurationSeconds,
      durationMinutes:
      (totalDurationSeconds / 60).ceil(),
      departureTime:
      routeDeparture,
      arrivalTime:
      routeArrival,
    );
  }

  String _toLocalRfc3339(
      DateTime value,
      ) {
    // HERE accepts RFC3339 without an explicit offset and then interprets
    // that time as local time at the route origin.
    final local = value.toLocal();

    String two(int number) =>
        number.toString().padLeft(2, '0');

    return '${local.year}-'
        '${two(local.month)}-'
        '${two(local.day)}T'
        '${two(local.hour)}:'
        '${two(local.minute)}:'
        '${two(local.second)}';
  }

  void dispose() {
    _client.close();
  }
}

class HereRoutingException implements Exception {
  final int? statusCode;
  final String message;

  const HereRoutingException({
    this.statusCode,
    required this.message,
  });

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }

    return 'HERE Routing error $statusCode: $message';
  }
}
