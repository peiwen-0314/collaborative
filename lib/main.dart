import 'package:collaborative_asg/views/ride_home_page.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'views/admin_login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await _signInDevTestUserIfNeeded();

  runApp(const MyApp());
}

// ============================================================
// TEMP DEV SIGN-IN - delete this whole function (and the call to it
// above) once `home:` below is wired to the real login/register flow
// instead of opening TransportationPage directly.
//
// Screens like the transportation module's Saved List need a real,
// signed-in Firebase user - SavedTripsStore intentionally only ever
// reads FirebaseAuth.instance.currentUser, it has no local/guest
// fallback of its own. Since this app currently skips login and opens
// TransportationPage straight away, there is nobody signed in yet by
// the time those screens run. This signs into (or, the very first time,
// registers) one fixed throwaway account so a real Firebase user - with
// a real uid - exists during that testing. Once the real login screen
// is `home:`, whoever logs in there becomes `currentUser` instead, and
// nothing else in the app (including SavedTripsStore) needs to change.
// ============================================================
const _devTestEmail = 'dev-tester@ecotravel.local';
const _devTestPassword = 'DevTester123!';

Future<void> _signInDevTestUserIfNeeded() async {
  if (FirebaseAuth.instance.currentUser != null) {
    debugPrint(
      '[DevSignIn] already signed in as uid='
      '${FirebaseAuth.instance.currentUser!.uid} - saved trips for this '
      'run live under users/${FirebaseAuth.instance.currentUser!.uid}/'
      'saved_trips in the Firestore Console.',
    );
    return;
  }

  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _devTestEmail,
      password: _devTestPassword,
    );
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _devTestEmail,
        password: _devTestPassword,
      );
    } else {
      rethrow;
    }
  }
  // Printed every run (not just the first) so it's always easy to find -
  // the dev/test account is fixed (_devTestEmail), so this uid should be
  // stable across runs/devices; if it ever changes unexpectedly that
  // itself would explain "saved trips aren't where I expect" in the
  // Console.
  debugPrint(
    '[DevSignIn] signed in as uid=${FirebaseAuth.instance.currentUser?.uid} '
    '- saved trips for this run live under users/'
    '${FirebaseAuth.instance.currentUser?.uid}/saved_trips in the '
    'Firestore Console.',
  );
}
// ============================================================
// END TEMP DEV SIGN-IN
// ============================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoTravel',

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
        ),
        useMaterial3: true,
      ),

      // Temporary: directly open Admin Login
     // home: const AdminLoginPage(),
      home: const TransportationPage(),
    );
  }
}
