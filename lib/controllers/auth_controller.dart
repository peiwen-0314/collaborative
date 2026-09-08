import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user.dart';
import '../services/auth_service.dart';

class AuthController {
  final AuthService _authService = AuthService();

  // ============================================================
  // LOGIN
  // ============================================================
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Please fill in all fields';
    }

    try {
      await _authService.login(
        email: email,
        password: password,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      print('LOGIN ERROR CODE: ${e.code}');
      print('LOGIN ERROR MESSAGE: ${e.message}');

      if (e.code == 'invalid-email') {
        return 'Invalid email address';
      }

      if (e.code == 'user-not-found') {
        return 'Account not found';
      }

      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        return 'Incorrect email or password';
      }

      if (e.code == 'user-disabled') {
        return 'This account has been disabled';
      }

      if (e.code == 'too-many-requests') {
        return 'Too many attempts. Please try again later';
      }

      return e.message ?? 'Login failed';
    } catch (e) {
      print('LOGIN ERROR: $e');
      return 'Login failed. Please try again';
    }
  }

  Map<String, bool> passwordRuleChecklist(String password) {
    return {
      'At least 8 characters': password.length >= 8,
      'An uppercase letter': RegExp(r'[A-Z]').hasMatch(password),
      'A lowercase letter': RegExp(r'[a-z]').hasMatch(password),
      'A number': RegExp(r'[0-9]').hasMatch(password),
      'A special character': RegExp(r'[^a-zA-Z0-9]').hasMatch(password),
    };
  }

  bool isPasswordValid(String password) =>
      passwordRuleChecklist(password).values.every((met) => met);

  String? _passwordRuleError(String password) {
    for (final rule in passwordRuleChecklist(password).entries) {
      if (!rule.value) {
        return 'Password must include: ${rule.key}';
      }
    }
    return null;
  }

  // ============================================================
  // REGISTER
  // ============================================================
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (name.trim().isEmpty ||
        email.trim().isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      return 'Please fill in all fields';
    }

    if (password != confirmPassword) {
      return 'Passwords do not match';
    }

    final passwordRuleError = _passwordRuleError(password);
    if (passwordRuleError != null) {
      return passwordRuleError;
    }

    try {
      await _authService.register(
        name: name,
        email: email,
        password: password,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      print('REGISTER AUTH ERROR CODE: ${e.code}');
      print('REGISTER AUTH ERROR MESSAGE: ${e.message}');

      if (e.code == 'email-already-in-use') {
        return 'Email is already registered';
      }

      if (e.code == 'invalid-email') {
        return 'Invalid email address';
      }

      if (e.code == 'weak-password') {
        return 'Password is too weak';
      }

      if (e.code == 'operation-not-allowed') {
        return 'Email/password registration is not enabled';
      }

      return e.message ?? 'Registration failed';
    } on FirebaseException catch (e) {
      print('REGISTER FIRESTORE ERROR CODE: ${e.code}');
      print('REGISTER FIRESTORE ERROR MESSAGE: ${e.message}');

      if (e.code == 'permission-denied') {
        return 'Unable to save user profile. Firestore permission denied';
      }

      return e.message ?? 'Unable to save user information';
    } catch (e) {
      print('REGISTER ERROR: $e');
      return 'Registration failed. Please try again';
    }
  }

  // ============================================================
  // GOOGLE LOGIN
  // ============================================================
  Future<String?> signInWithGoogle() async {
    try {
      final User? user =
      await _authService.signInWithGoogle();

      if (user == null) {
        return 'Google sign in was not completed';
      }

      return null;
    } on FirebaseAuthException catch (e) {
      print('GOOGLE FIREBASE AUTH ERROR CODE: ${e.code}');
      print('GOOGLE FIREBASE AUTH ERROR: ${e.message}');

      if (e.code == 'account-exists-with-different-credential') {
        return 'An account already exists with this email';
      }

      if (e.code == 'invalid-credential') {
        return 'Google authentication failed';
      }

      if (e.code == 'user-disabled') {
        return 'This account has been disabled';
      }

      return e.message ?? 'Google sign in failed';
    } on FirebaseException catch (e) {
      print('GOOGLE FIREBASE ERROR CODE: ${e.code}');
      print('GOOGLE FIREBASE ERROR: ${e.message}');

      if (e.code == 'permission-denied') {
        return 'Firestore permission denied';
      }

      return e.message ?? 'Google sign in failed';
    } catch (e) {
      print('GOOGLE SIGN IN ERROR: $e');

      // User closing Google account selector should not crash app.
      final String message = e.toString();

      if (message.toLowerCase().contains('cancel')) {
        return 'Google sign in cancelled';
      }

      return 'Google sign in failed';
    }
  }

  // ============================================================
  // FORGET PASSWORD
  // ============================================================

  Future<String?> forgotPassword({
    required String email,
  }) async {
    if (email.trim().isEmpty) {
      return 'Please enter your email address';
    }

    try {
      await _authService.sendPasswordResetEmail(
        email: email,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      print('RESET PASSWORD ERROR CODE: ${e.code}');
      print('RESET PASSWORD ERROR MESSAGE: ${e.message}');

      if (e.code == 'invalid-email') {
        return 'Invalid email address';
      }

      if (e.code == 'user-not-found') {
        return 'No account found with this email';
      }

      if (e.code == 'too-many-requests') {
        return 'Too many requests. Please try again later';
      }

      return e.message ?? 'Unable to send reset email';
    } catch (e) {
      print('RESET PASSWORD ERROR: $e');

      return 'Unable to send reset email. Please try again';
    }
  }

  // ============================================================
  // ADMIN LOGIN
  // ============================================================
  Future<String?> loginAdmin({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Please enter email and password';
    }

    try {
      final user = await _authService.loginAdmin(
        email: email,
        password: password,
      );

      if (user == null) {
        return 'Admin login failed';
      }

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        return 'Invalid admin email or password';
      }

      return e.message ?? 'Admin login failed';
    } catch (e) {
      if (e.toString().contains('Unauthorized admin access')) {
        return 'You are not authorized as admin';
      }

      return 'Admin login failed';
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  Future<void> logout() async {
    await _authService.logout();
  }

  // ============================================================
  // CURRENT USER PROFILE
  // ============================================================
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      return await _authService.getCurrentUserProfile();
    } catch (e) {
      print('GET PROFILE ERROR: $e');
      return null;
    }
  }

  String? get currentUserEmail => _authService.currentUser?.email;

  // ============================================================
  // PROFILE PICTURE / UPDATE PROFILE
  // ============================================================
  Future<String> uploadProfilePicture(XFile image) {
    return _authService.uploadProfilePicture(image);
  }

  Future<void> updateProfile({String? name, String? photoUrl}) {
    return _authService.updateProfile(name: name, photoUrl: photoUrl);
  }

  // ============================================================
  // CHANGE PASSWORD (in-app)
  // ============================================================
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      return 'Please fill in all fields';
    }

    if (newPassword != confirmPassword) {
      return 'New passwords do not match';
    }

    final passwordRuleError = _passwordRuleError(newPassword);
    if (passwordRuleError != null) {
      return passwordRuleError;
    }

    if (newPassword == currentPassword) {
      return 'New password must be different from your current password';
    }

    return _authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}