import 'dart:convert';

import 'package:flutter/services.dart';

/// Configuration for the transportation module's HERE integration.
///
/// This app works fully offline out of the box using realistic mock/demo
/// data (see `lib/data/transport_data.dart`), so it can be built and
/// demoed without any API key at all.
///
/// To pull real routes from HERE instead of the mock data:
///   1. Create a free key at https://developer.here.com (Basic/Freemium
///      plan: 30,000 free requests per service per month).
///   2. Run/build with the key injected at compile time, e.g.:
///        flutter run --dart-define=HERE_API_KEY=your_key_here
///        flutter build apk --dart-define=HERE_API_KEY=your_key_here
///
/// A compile-time define remains the preferred production path. For local
/// Android Studio runs, [ensureLoaded] also reads the git-ignored `env.json`
/// asset so a temporary IDE run configuration cannot silently disable HERE.
class ApiConfig {
  const ApiConfig._();

  static String _hereApiKey = const String.fromEnvironment(
    'HERE_API_KEY',
    defaultValue: '',
  );

  static Future<void>? _loadFuture;

  static String get hereApiKey => _hereApiKey;

  static bool get hasHereApiKey => hereApiKey.trim().isNotEmpty;

  static Future<void> ensureLoaded() {
    if (hasHereApiKey) return Future.value();
    return _loadFuture ??= _loadFromLocalAsset();
  }

  static Future<void> _loadFromLocalAsset() async {
    try {
      final raw = await rootBundle.loadString('env.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final key = json['HERE_API_KEY']?.toString().trim() ?? '';
      if (key.isNotEmpty) _hereApiKey = key;
    } catch (_) {
      // Missing local env file is allowed; the UI will show that live HERE
      // navigation is unavailable instead of failing application startup.
    }
  }
}
