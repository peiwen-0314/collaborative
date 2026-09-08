import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/here_config.dart';
import '../models/here_matrix_result.dart';

class HereMatrixPoint {
  final double latitude;
  final double longitude;

  const HereMatrixPoint({
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lng': longitude,
    };
  }
}

class HereMatrixRoutingService {
  HereMatrixRoutingService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _baseUrl =
      'https://matrix.router.hereapi.com/v8/matrix';

  Future<HereMatrixResult> calculateCarMatrix({
    required List<HereMatrixPoint> points,
    required DateTime departureTime,
  }) async {
    if (!HereConfig.hasApiKey) {
      throw StateError(
        'HERE_API_KEY is missing. Run Flutter with '
        '--dart-define=HERE_API_KEY=YOUR_KEY.',
      );
    }

    if (points.length < 2) {
      throw ArgumentError(
        'HERE Matrix needs at least 2 points.',
      );
    }

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'async': 'false',
        'apiKey': HereConfig.apiKey,
      },
    );

    final body = <String, dynamic>{
      'origins':
          points.map((point) => point.toJson()).toList(),

      // Omitting destinations makes this a square matrix:
      // every origin is also used as every destination.
      'regionDefinition': {
        'type': 'world',
      },

      'departureTime':
          _toRfc3339WithOffset(departureTime),

      'routingMode': 'fast',
      'transportMode': 'car',

      'matrixAttributes': [
        'travelTimes',
        'distances',
      ],
    };

    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw HereMatrixRoutingException(
        statusCode: response.statusCode,
        message:
            'HERE Matrix request failed: ${response.body}',
      );
    }

    final decoded =
        jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Unexpected HERE Matrix response.',
      );
    }

    final matrixRaw = decoded['matrix'];

    if (matrixRaw is! Map) {
      throw const HereMatrixRoutingException(
        message:
            'HERE Matrix response has no matrix.',
      );
    }

    final matrix =
        Map<String, dynamic>.from(matrixRaw);

    final numOrigins =
        (matrix['numOrigins'] as num?)?.toInt() ??
            points.length;

    final numDestinations =
        (matrix['numDestinations'] as num?)?.toInt() ??
            points.length;

    List<int?> readIntList(String key) {
      final raw = matrix[key];

      if (raw is! List) {
        return const [];
      }

      return raw.map<int?>((value) {
        if (value == null) {
          return null;
        }

        if (value is num) {
          return value.toInt();
        }

        return int.tryParse(
          value.toString(),
        );
      }).toList();
    }

    final travelTimes =
        readIntList('travelTimes');

    final distances =
        readIntList('distances');

    final errorCodes =
        readIntList('errorCodes');

    if (travelTimes.isEmpty) {
      throw const HereMatrixRoutingException(
        message:
            'HERE Matrix returned no travel times.',
      );
    }

    return HereMatrixResult(
      numOrigins: numOrigins,
      numDestinations: numDestinations,
      travelTimesSeconds: travelTimes,
      distancesMeters: distances,
      errorCodes: errorCodes,
    );
  }

  String _toRfc3339WithOffset(
    DateTime value,
  ) {
    final local = value.toLocal();
    final offset = local.timeZoneOffset;

    String two(int number) =>
        number.toString().padLeft(2, '0');

    final totalMinutes =
        offset.inMinutes.abs();

    final offsetHours =
        totalMinutes ~/ 60;

    final offsetMinutes =
        totalMinutes % 60;

    final sign =
        offset.isNegative ? '-' : '+';

    return '${local.year}-'
        '${two(local.month)}-'
        '${two(local.day)}T'
        '${two(local.hour)}:'
        '${two(local.minute)}:'
        '${two(local.second)}'
        '$sign'
        '${two(offsetHours)}:'
        '${two(offsetMinutes)}';
  }

  void dispose() {
    _client.close();
  }
}

class HereMatrixRoutingException
    implements Exception {
  final int? statusCode;
  final String message;

  const HereMatrixRoutingException({
    this.statusCode,
    required this.message,
  });

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }

    return 'HERE Matrix error '
        '$statusCode: $message';
  }
}
