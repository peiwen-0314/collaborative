import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_home_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() =>
      _AdminLoginPageState();
}

class _AdminLoginPageState
    extends State<AdminLoginPage> {
  static const Color mainGreen =
  Color(0xFF2E7D32);

  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController passwordController =
  TextEditingController();

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool hidePassword = true;
  bool isLoading = false;

  // ============================================================
  // ADMIN LOGIN
  // ============================================================

  Future<void> loginAdmin() async {
    if (isLoading) return;

    final email =
    emailController.text.trim();

    final password =
        passwordController.text;

    // ============================================================
    // BASIC VALIDATION
    // ============================================================

    if (email.isEmpty) {
      _showError(
        'Please enter your admin email.',
      );
      return;
    }

    if (password.isEmpty) {
      _showError(
        'Please enter your password.',
      );
      return;
    }

    if (!_isValidEmail(email)) {
      _showError(
        'Please enter a valid email address.',
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // ============================================================
      // 1. FIREBASE AUTHENTICATION
      // ============================================================

      final UserCredential credential =
      await _auth
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user =
          credential.user;

      if (user == null) {
        throw StateError(
          'Unable to retrieve the logged-in user.',
        );
      }

      // ============================================================
      // 2. READ USER PROFILE FROM FIRESTORE
      //
      // Expected structure:
      //
      // users
      //   └── {Firebase UID}
      //        ├── email: "admin@gmail.com"
      //        ├── name: "Admin"
      //        ├── role: "admin"
      //        └── uid: "..."
      // ============================================================

      final DocumentSnapshot<
          Map<String, dynamic>> userDoc =
      await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await _auth.signOut();

        if (!mounted) return;

        _showError(
          'This account is not registered as an administrator.',
        );

        return;
      }

      final Map<String, dynamic>? data =
      userDoc.data();

      final String role =
      (data?['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      // ============================================================
      // 3. ADMIN ROLE CHECK
      // ============================================================

      if (role != 'admin') {
        await _auth.signOut();

        if (!mounted) return;

        _showError(
          'Access denied. Administrator account required.',
        );

        return;
      }

      // ============================================================
      // 4. OPTIONAL UID FIELD CHECK
      //
      // You currently store uid inside the Firestore document too.
      // This makes sure it matches Firebase Authentication.
      // ============================================================

      final String storedUid =
      (data?['uid'] ?? '')
          .toString()
          .trim();

      if (storedUid.isNotEmpty &&
          storedUid != user.uid) {
        await _auth.signOut();

        if (!mounted) return;

        _showError(
          'Administrator account information is invalid.',
        );

        return;
      }

      // ============================================================
      // 5. LOGIN SUCCESS
      // ============================================================

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
          const AdminHomePage(),
        ),
      );
    }

    // ============================================================
    // FIREBASE AUTH ERRORS
    // ============================================================

    on FirebaseAuthException catch (error) {
      if (!mounted) return;

      String message;

      switch (error.code) {
        case 'invalid-email':
          message =
          'Please enter a valid email address.';
          break;

        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          message =
          'Incorrect email or password.';
          break;

        case 'user-disabled':
          message =
          'This account has been disabled.';
          break;

        case 'too-many-requests':
          message =
          'Too many login attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message =
          'Unable to connect. Please check your internet connection.';
          break;

        default:
          message =
          'Unable to login. Please try again.';
      }

      _showError(message);
    }

    // ============================================================
    // OTHER ERRORS
    // ============================================================

    catch (error) {
      if (!mounted) return;

      _showError(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // EMAIL VALIDATION
  // ============================================================

  bool _isValidEmail(
      String email,
      ) {
    final emailPattern = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    return emailPattern
        .hasMatch(email);
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showError(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          Colors.red.shade700,
          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F7F5),

      body: Center(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(24),

          child: Container(
            width: 430,
            padding:
            const EdgeInsets.all(36),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(18),

              boxShadow: [
                BoxShadow(
                  color:
                  Colors.black
                      .withValues(
                    alpha: 0.08,
                  ),
                  blurRadius: 20,
                  offset:
                  const Offset(0, 8),
                ),
              ],
            ),

            child: Column(
              mainAxisSize:
              MainAxisSize.min,

              crossAxisAlignment:
              CrossAxisAlignment
                  .start,

              children: [
                // ==================================================
                // HEADER
                // ==================================================

                const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.eco,
                        size: 52,
                        color: mainGreen,
                      ),

                      SizedBox(
                        height: 8,
                      ),

                      Text(
                        'EcoTravel Admin',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight:
                          FontWeight
                              .bold,
                          color:
                          mainGreen,
                        ),
                      ),

                      SizedBox(
                        height: 5,
                      ),

                      Text(
                        'Administration Portal',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                          Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 32,
                ),

                const Text(
                  'Admin Login',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // ==================================================
                // EMAIL
                // ==================================================

                TextField(
                  controller:
                  emailController,

                  keyboardType:
                  TextInputType
                      .emailAddress,

                  textInputAction:
                  TextInputAction.next,

                  enabled: !isLoading,

                  decoration:
                  inputDecoration(
                    hint:
                    'Admin Email',
                    icon: Icons
                        .email_outlined,
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                // ==================================================
                // PASSWORD
                // ==================================================

                TextField(
                  controller:
                  passwordController,

                  obscureText:
                  hidePassword,

                  textInputAction:
                  TextInputAction.done,

                  enabled: !isLoading,

                  onSubmitted: (_) {
                    if (!isLoading) {
                      loginAdmin();
                    }
                  },

                  decoration:
                  inputDecoration(
                    hint: 'Password',
                    icon: Icons
                        .lock_outline,

                    suffix:
                    IconButton(
                      onPressed:
                      isLoading
                          ? null
                          : () {
                        setState(
                              () {
                            hidePassword =
                            !hidePassword;
                          },
                        );
                      },

                      icon: Icon(
                        hidePassword
                            ? Icons
                            .visibility_off_outlined
                            : Icons
                            .visibility_outlined,

                        color:
                        mainGreen,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                // ==================================================
                // LOGIN BUTTON
                // ==================================================

                SizedBox(
                  width:
                  double.infinity,
                  height: 50,

                  child:
                  ElevatedButton(
                    onPressed:
                    isLoading
                        ? null
                        : loginAdmin,

                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      mainGreen,

                      foregroundColor:
                      Colors.white,

                      elevation: 0,

                      disabledBackgroundColor:
                      mainGreen
                          .withValues(
                        alpha: 0.55,
                      ),

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                          12,
                        ),
                      ),
                    ),

                    child:
                    isLoading
                        ? const SizedBox(
                      width: 22,
                      height: 22,

                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,
                        color:
                        Colors.white,
                      ),
                    )
                        : const Text(
                      'Login',
                      style:
                      TextStyle(
                        fontSize:
                        15,
                        fontWeight:
                        FontWeight
                            .bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 14,
                ),

                const Center(
                  child: Text(
                    'Authorized administrators only',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                      Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,

      prefixIcon: Icon(
        icon,
        color: mainGreen,
      ),

      suffixIcon: suffix,

      filled: true,

      fillColor:
      const Color(0xFFF9FAF9),

      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),

        borderSide: BorderSide(
          color:
          mainGreen.withValues(
            alpha: 0.20,
          ),
        ),
      ),

      disabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),

        borderSide:
        const BorderSide(
          color:
          Color(0xFFE0E0E0),
        ),
      ),

      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),

        borderSide:
        const BorderSide(
          color: mainGreen,
          width: 1.4,
        ),
      ),

      errorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),

        borderSide:
        const BorderSide(
          color: Colors.red,
        ),
      ),

      focusedErrorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),

        borderSide:
        const BorderSide(
          color: Colors.red,
          width: 1.4,
        ),
      ),
    );
  }
}