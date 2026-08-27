import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // EMAIL / PASSWORD LOGIN
  // ============================================================
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    final UserCredential credential =
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    return credential.user;
  }

  // ============================================================
  // EMAIL / PASSWORD REGISTER
  // ============================================================
  Future<User?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final UserCredential credential =
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final User? firebaseUser = credential.user;

    if (firebaseUser != null) {
      final UserModel newUser = UserModel(
        uid: firebaseUser.uid,
        name: name.trim(),
        email: email.trim(),
        role: 'user',
      );

      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(newUser.toMap());
    }

    return firebaseUser;
  }

  // ============================================================
  // GOOGLE SIGN IN
  // google_sign_in 7.2.0
  // ============================================================
  Future<User?> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn.instance;

    // Initialize Google Sign-In
    await googleSignIn.initialize();

    // Open Google account selector
    final GoogleSignInAccount googleUser =
    await googleSignIn.authenticate();

    // Get Google authentication information
    final GoogleSignInAuthentication googleAuth =
        googleUser.authentication;

    // Create Firebase credential
    final OAuthCredential credential =
    GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    // Login to Firebase
    final UserCredential userCredential =
    await _auth.signInWithCredential(credential);

    final User? firebaseUser = userCredential.user;

    // ==========================================================
    // SAVE GOOGLE USER TO FIRESTORE
    // ==========================================================
    if (firebaseUser != null) {
      final DocumentReference<Map<String, dynamic>> userDocument =
      _firestore
          .collection('users')
          .doc(firebaseUser.uid);

      final DocumentSnapshot<Map<String, dynamic>> snapshot =
      await userDocument.get();

      // Only create document for new Google user
      if (!snapshot.exists) {
        final UserModel newUser = UserModel(
          uid: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'User',
          email: firebaseUser.email ?? '',
        );

        await userDocument.set(
          newUser.toMap(),
        );
      }
    }

    return firebaseUser;
  }
  // ============================================================
  // FORGET PASSWORD
  // ============================================================

  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  // ============================================================
  // ADMIN LOGIN
  // ============================================================

  Future<User?> loginAdmin({
    required String email,
    required String password,
  }) async {
    final UserCredential credential =
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final User? user = credential.user;

    if (user == null) {
      return null;
    }

    final document =
    await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!document.exists) {
      await _auth.signOut();
      throw Exception('Admin profile not found');
    }

    final data = document.data();

    if (data == null || data['role'] != 'admin') {
      await _auth.signOut();
      throw Exception('Unauthorized admin access');
    }

    return user;
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  Future<void> logout() async {
    await _auth.signOut();

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Ignore if user logged in using email/password.
    }
  }

  // ============================================================
  // CURRENT USER
  // ============================================================
  User? get currentUser {
    return _auth.currentUser;
  }
}