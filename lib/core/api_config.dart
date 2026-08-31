/// Configuration for the (optional) live HERE Transit API integration.
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
/// The key is never hardcoded or committed to source control this way -
/// `--dart-define` values only exist for that one build/run.
class ApiConfig {
  const ApiConfig._();

  static const hereApiKey = String.fromEnvironment(
    'HERE_API_KEY',
    defaultValue: '',
  );

  static bool get hasHereApiKey => hereApiKey.trim().isNotEmpty;
}
