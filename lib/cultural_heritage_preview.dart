import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:collaborative_asg/firebase_options.dart';

import 'views/cultural_heritage_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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