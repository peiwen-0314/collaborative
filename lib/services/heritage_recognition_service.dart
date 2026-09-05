import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/heritage_attraction.dart';
import 'heritage_firestore_service.dart';

class HeritageRecognitionResult {
  const HeritageRecognitionResult({
    required this.candidates,
    required this.attraction,
  });

  final List<String> candidates;
  final HeritageAttraction? attraction;
}

class HeritageRecognitionService {
  HeritageRecognitionService({
    HeritageFirestoreService? firestoreService,
  }) : _firestoreService =
      firestoreService ?? HeritageFirestoreService();

  // Real Android phone
  static const String baseUrl = 'http://192.168.100.90:8000';

  final HeritageFirestoreService _firestoreService;

  Future<HeritageRecognitionResult> recognize(
      File imageFile,
      ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/recognize'),
    );

    // ============================================================
    // DETERMINE IMAGE TYPE
    // ============================================================

    final extension =
    imageFile.path.split('.').last.toLowerCase();

    MediaType contentType;

    switch (extension) {
      case 'png':
        contentType = MediaType('image', 'png');
        break;

      case 'webp':
        contentType = MediaType('image', 'webp');
        break;

      case 'jpeg':
      case 'jpg':
      default:
        contentType = MediaType('image', 'jpeg');
        break;
    }

    // ============================================================
    // ADD IMAGE TO REQUEST
    // ============================================================

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: contentType,
      ),
    );

    // ============================================================
    // SEND TO FASTAPI BACKEND
    // ============================================================

    final streamedResponse = await request
        .send()
        .timeout(
      const Duration(seconds: 90),
    );

    final response =
    await http.Response.fromStream(streamedResponse);

    // ============================================================
    // CHECK BACKEND RESPONSE
    // ============================================================

    if (response.statusCode != 200) {
      throw Exception(
        'Recognition server returned '
            '${response.statusCode}: ${response.body}',
      );
    }

    // ============================================================
    // PARSE JSON
    // ============================================================

    final data =
    jsonDecode(response.body) as Map<String, dynamic>;

    final candidates =
    (data['candidate_names'] as List<dynamic>? ??
        <dynamic>[])
        .map((value) => value.toString())
        .where(
          (value) => value.trim().isNotEmpty,
    )
        .toList();

    // ============================================================
    // MATCH GOOGLE VISION RESULT WITH FIRESTORE
    // ============================================================

    final attraction =
    await _firestoreService
        .findByVisionCandidates(
      candidates,
    );

    // ============================================================
    // RETURN RESULT
    // ============================================================

    return HeritageRecognitionResult(
      candidates: candidates,
      attraction: attraction,
    );
  }
}