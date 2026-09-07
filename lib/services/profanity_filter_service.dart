import 'package:cloud_functions/cloud_functions.dart';

/// Result of running [ProfanityFilterService.check] on a piece of text.
class ProfanityCheckResult {
  const ProfanityCheckResult({
    required this.isFlagged,
    this.matchedWord,
    this.errorMessage,
  });

  final bool isFlagged;
  final String? matchedWord;
  final String? errorMessage;
}

/// Combines the multilingual local word list with Google Cloud Natural
/// Language moderation through a secured Firebase callable function.
class ProfanityFilterService {
  const ProfanityFilterService._();

  static const Set<String> _englishWords = {
    'fuck', 'fucking', 'fucker', 'motherfucker',
    'shit', 'shitty', 'bullshit',
    'bitch', 'bastard', 'asshole', 'dick', 'piss',
    'cunt', 'damn', 'douche', 'prick', 'slut', 'whore',
  };

  static const Set<String> _malayWords = {
    'bodoh', 'sial', 'bangang', 'bangsat', 'puki', 'pukimak',
    'babi', 'anjing', 'lancau', 'celaka', 'keparat', 'sundal', 'pantat',
  };

  static const Set<String> _chineseWords = {
    '笨蛋', '混蛋', '傻逼', '妈的', '他妈的', '王八蛋', '白痴',
  };

  static final Set<String> _allWords = {
    ..._englishWords,
    ..._malayWords,
    ..._chineseWords,
  };

  /// Checks [text] before saving a user-submitted post, review or comment.
  static Future<ProfanityCheckResult> check(String text) async {
    final lower = text.toLowerCase();
    for (final word in _allWords) {
      if (lower.contains(word)) {
        return ProfanityCheckResult(isFlagged: true, matchedWord: word);
      }
    }
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('moderateText');
      final response = await callable.call<Map<String, dynamic>>({'text': text});
      final data = response.data;
      return ProfanityCheckResult(
        isFlagged: data['isFlagged'] == true,
        matchedWord: data['reason'] as String?,
      );
    } on FirebaseFunctionsException catch (error) {
      return ProfanityCheckResult(
        isFlagged: false,
        errorMessage: error.message ?? 'Text moderation is unavailable.',
      );
    } catch (_) {
      return const ProfanityCheckResult(
        isFlagged: false,
        errorMessage: 'Text moderation is unavailable. Please try again.',
      );
    }
  }
}
