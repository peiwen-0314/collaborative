class HereConfig {
  HereConfig._();

  /// Provide this at run/build time:
  ///
  /// flutter run --dart-define=HERE_API_KEY=YOUR_KEY
  ///
  /// Do not commit the real key to source control.
  static const String apiKey =
  String.fromEnvironment('HERE_API_KEY');

  static bool get hasApiKey =>
      apiKey.trim().isNotEmpty;
}
