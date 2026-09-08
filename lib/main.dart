import 'package:collaborative_asg/views/ride_home_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'views/admin_login_page.dart';
import 'views/login_page.dart';
import 'widgets/attraction_detection_listener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'EcoTravel',

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
        ),
        useMaterial3: true,
      ),

      builder: (context, child) {
        return AttractionDetectionListener(
          navigatorKey: navigatorKey,
          child: child ?? const SizedBox.shrink(),
        );
      },

      home: const LoginPage(),
      // home: const AdminLoginPage(),
    );
  }
}