import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/heritage_data.dart';
import '../models/heritage_attraction.dart';

class HeritageRecognitionResult {
  const HeritageRecognitionResult({
    required this.candidates,
    required this.attraction,
  });

  final List<String> candidates;
  final HeritageAttraction? attraction;
}

class HeritageRecognitionService {
  // Android emulator -> computer localhost.
  // For a physical Android phone, replace this with your PC IPv4 address,
  // for example: http://192.168.0.20:8000
  static const String baseUrl = 'http://10.0.2.2:8000';

  Future<HeritageRecognitionResult> recognize(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/recognize'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
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

    return HeritageRecognitionResult(
      candidates: candidates,
      attraction: HeritageData.findByVisionCandidates(candidates),
    );
  }
}
