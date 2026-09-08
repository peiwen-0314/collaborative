import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ReviewModerationResult {
  const ReviewModerationResult({
    required this.allowed,
    required this.message,
    this.source,
    this.debugCode,
  });

  final bool allowed;
  final String message;
  final String? source;

  /// Safe diagnostic code such as "openai_429".
  /// This never contains the API key.
  final String? debugCode;

  factory ReviewModerationResult.fromJson(
      Map<String, dynamic> json,
      ) {
    return ReviewModerationResult(
      allowed: json['allowed'] == true,
      message: (json['message'] ?? '').toString(),
      source: json['source']?.toString(),
      debugCode: json['debugCode']?.toString(),
    );
  }
}

class ReviewModerationService {
  ReviewModerationService._();

  static final ReviewModerationService instance =
  ReviewModerationService._();

  static const String _endpoint =
      'https://us-central1-ecotravel-5ad49.cloudfunctions.net/moderateReview';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<ReviewModerationResult> moderate(
      String reviewText,
      ) async {
    final text = reviewText.trim();

    // Rating is required, but review text is optional.
    // If the user leaves the review text empty, there is nothing to moderate.
    if (text.isEmpty) {
      return const ReviewModerationResult(
        allowed: true,
        message: 'No review text to moderate.',
        source: 'validation',
        debugCode: 'no_text',
      );
    }

    final user = _auth.currentUser;

    if (user == null) {
      return const ReviewModerationResult(
        allowed: false,
        message: 'Please login before submitting a review.',
        source: 'authentication',
      );
    }

    final idToken = await user.getIdToken(true);

    try {
      final response = await http
          .post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'text': text,
        }),
      )
          .timeout(
        const Duration(seconds: 30),
      );

      Map<String, dynamic> body = <String, dynamic>{};

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (_) {
        // Leave the parsed body empty.
      }

      if (response.statusCode == 200) {
        return ReviewModerationResult.fromJson(
          body,
        );
      }

      if (response.statusCode == 401) {
        return ReviewModerationResult(
          allowed: false,
          message:
          (body['message'] ??
              'Your session has expired. Please login again.')
              .toString(),
          source: 'authentication',
          debugCode: body['debugCode']?.toString(),
        );
      }

      if (response.statusCode == 429) {
        return ReviewModerationResult(
          allowed: false,
          message:
          (body['message'] ??
              'Review checking is temporarily rate-limited. Please try again shortly.')
              .toString(),
          source: 'rate-limit',
          debugCode: body['debugCode']?.toString(),
        );
      }

      return ReviewModerationResult(
        allowed: false,
        message:
        (body['message'] ??
            'Unable to check review content right now. Please try again.')
            .toString(),
        source: body['source']?.toString() ?? 'server',
        debugCode:
        body['debugCode']?.toString() ??
            'function_${response.statusCode}',
      );
    } catch (error) {
      return ReviewModerationResult(
        allowed: false,
        message:
        'Unable to reach the review checker. Please check your connection and try again.',
        source: 'network',
        debugCode: error.runtimeType.toString(),
      );
    }
  }
}
