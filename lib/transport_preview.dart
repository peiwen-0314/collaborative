import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'views/ride_home_page.dart';

/// Standalone entry point for previewing/demoing just the transportation
/// module, without going through the app's login flow - same idea as
/// `cultural_heritage_preview.dart` for the heritage module.
///
/// Run with: flutter run -t lib/transport_preview.dart
void main() {
  runApp(const TransportPreviewApp());
}

class TransportPreviewApp extends StatelessWidget {
  const TransportPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoTravel Transportation',
      theme: buildAppTheme(),
      home: const TransportationPage(),
    );
  }
}
