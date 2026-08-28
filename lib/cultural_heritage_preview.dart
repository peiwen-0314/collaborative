import 'package:flutter/material.dart';
import 'views/cultural_heritage_page.dart';

void main() {
  runApp(const CulturalHeritagePreviewApp());
}

class CulturalHeritagePreviewApp extends StatelessWidget {
  const CulturalHeritagePreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoTravel Cultural & Heritage',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const CulturalHeritagePage(),
    );
  }
}