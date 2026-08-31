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
  HeritageRecognitionService({HeritageFirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? HeritageFirestoreService();

  static const String baseUrl = 'http://10.0.2.2:8000';
  final HeritageFirestoreService _firestoreService;

  Future<HeritageRecognitionResult> recognize(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/recognize'),
    );
    final extension = imageFile.path.split('.').last.toLowerCase();

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
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: contentType,
      ),
    );
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception(
        'Recognition server returned ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = (data['candidate_names'] as List<dynamic>? ?? <dynamic>[])
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty)
        .toList();

    final attraction =
    await _firestoreService.findByVisionCandidates(candidates);

    return HeritageRecognitionResult(
      candidates: candidates,
      attraction: attraction,
    );
  }
}
