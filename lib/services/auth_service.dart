import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Loaded from env.json when the app is started with:
  // flutter run --dart-define-from-file=env.json
  static const String _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  Future<void> _ensureGamificationProfile(User user) async {
    final gamificationRef =
    _firestore.collection('gamification').doc(user.uid);

    final snapshot = await gamificationRef.get();

    // Do not overwrite existing gamification data.
    if (snapshot.exists) return;

    await gamificationRef.set({
      'level': 1,
      'levelTitle': 'Eco Explorer',
      'currentXp': 0,
      'requiredXp': 1000,
      'totalPoints': 0,
      'collectedStamps': 0,
      'completedChallenges': 0,
      'carbonSaved': 0.0,
      'treeGrowth': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

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

    final user = credential.user;

    if (user != null) {
      await _ensureGamificationProfile(user);
    }

    return user;
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

      await _ensureGamificationProfile(firebaseUser);
    }

    return firebaseUser;
  }

  // ============================================================
  // GOOGLE SIGN IN
  // google_sign_in 7.2.x
  // ============================================================
  Future<User?> signInWithGoogle() async {
    User? firebaseUser;

    if (kIsWeb) {
      final GoogleAuthProvider provider =
      GoogleAuthProvider();

      final UserCredential userCredential =
      await _auth.signInWithPopup(provider);

      firebaseUser =
          userCredential.user;
    } else {
      final GoogleSignIn googleSignIn =
          GoogleSignIn.instance;

      await googleSignIn.initialize();

      final GoogleSignInAccount googleUser =
      await googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final OAuthCredential credential =
      GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
      await _auth.signInWithCredential(
        credential,
      );

      firebaseUser =
          userCredential.user;
    }

    if (firebaseUser != null) {
      final userDocument =
      _firestore
          .collection('users')
          .doc(firebaseUser.uid);

      final snapshot =
      await userDocument.get();

      if (!snapshot.exists) {
        final UserModel newUser =
        UserModel(
          uid: firebaseUser.uid,
          name:
          firebaseUser.displayName ??
              'User',
          email:
          firebaseUser.email ?? '',
        );

        await userDocument.set(
          newUser.toMap(),
        );
      }

      await _ensureGamificationProfile(
        firebaseUser,
      );
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
    final bool isGoogleUser =
        _auth.currentUser?.providerData.any(
              (info) => info.providerId == 'google.com',
        ) ??
            false;

    await _auth.signOut();

    if (!isGoogleUser) return;

    try {
      await GoogleSignIn.instance.signOut().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      // Firebase sign-out already logged the user out of EcoTravel.
    }
  }

  // ============================================================
  // CURRENT USER
  // ============================================================
  User? get currentUser {
    return _auth.currentUser;
  }

  // ============================================================
  // CURRENT USER PROFILE (Firestore users/{uid} doc)
  // ============================================================
  Future<UserModel?> getCurrentUserProfile() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;

    final document =
    await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final data = document.data();
    if (data == null) return null;

    return UserModel.fromMap(data);
  }

  // ============================================================
  // CHANGE PASSWORD (in-app, while already signed in)
  // ============================================================
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final User? user = _auth.currentUser;
    final String? email = user?.email;

    if (user == null || email == null || email.isEmpty) {
      return 'No signed-in account found';
    }

    final bool usesPasswordSignIn =
    user.providerData.any(
          (info) => info.providerId == 'password',
    );

    if (!usesPasswordSignIn) {
      return 'This account signed in with Google and has no app password to change';
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(
        credential,
      );

      await user.updatePassword(
        newPassword,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      print('CHANGE PASSWORD ERROR CODE: ${e.code}');
      print('CHANGE PASSWORD ERROR MESSAGE: ${e.message}');

      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        return 'Current password is incorrect';
      }

      if (e.code == 'weak-password') {
        return 'New password is too weak';
      }

      if (e.code == 'requires-recent-login') {
        return 'Please log out and log in again, then retry';
      }

      return e.message ?? 'Unable to change password';
    } catch (e) {
      print('CHANGE PASSWORD ERROR: $e');

      return 'Unable to change password. Please try again';
    }
  }

  // ============================================================
  // PROFILE PICTURE
  // ============================================================
  Future<String> uploadProfilePicture(XFile image) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Please log in to change your profile picture.',
      );
    }

    final bytes = await image.readAsBytes();

    final ref = FirebaseStorage.instance.ref(
      'profile_pictures/${user.uid}',
    );

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/jpeg',
      ),
    );

    return ref.getDownloadURL();
  }

  // ============================================================
  // UPDATE PROFILE (users/{uid} doc)
  // ============================================================
  Future<void> updateProfile({
    String? name,
    String? photoUrl,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Please log in to update your profile.',
      );
    }

    final updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };

    if (updates.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .update(updates);
  }
}