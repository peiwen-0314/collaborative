import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import 'forgot_password_page.dart';
import 'home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController passwordController =
  TextEditingController();

  final AuthController authController = AuthController();

  // ============================================================
  // VARIABLES
  // ============================================================

  bool isLoading = false;
  bool isGoogleLoading = false;
  bool hidePassword = true;

  static const Color mainGreen = Color(0xFF2E7D32);

  // ============================================================
  // EMAIL LOGIN
  // ============================================================

  Future<void> login() async {
    setState(() {
      isLoading = true;
    });

    final String? error = await authController.login(
      email: emailController.text,
      password: passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (error == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
      );
    } else {
      showError(error);
    }
  }

  // ============================================================
  // GOOGLE LOGIN
  // ============================================================

  Future<void> googleLogin() async {
    setState(() {
      isGoogleLoading = true;
    });

    final String? error =
    await authController.signInWithGoogle();

    if (!mounted) return;

    setState(() {
      isGoogleLoading = false;
    });

    if (error == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
      );
    } else {
      showError(error);
    }
  }

  // ============================================================
  // SHOW ERROR
  // ============================================================

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
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
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [

              // =================================================
              // TOP BACKGROUND IMAGE
              // =================================================

              SizedBox(
                height: 260,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [

                    // Background Image
                    Image.asset(
                      'assets/images/backgroundImg.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),

                    // Soft white gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.75),
                          ],
                        ),
                      ),
                    ),

                    // ======================================
                    // LOGO AND TEXT
                    // ======================================
                    Positioned(
                      left: 18,
                      bottom: 50,
                      right: 18,
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [

                          Row(
                            children: [
                              const Icon(
                                Icons.eco,
                                size: 34,
                                color: mainGreen,
                              ),

                              const SizedBox(width: 6),

                              const Text(
                                'EcoTravel',
                                style: TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.bold,
                                  color: mainGreen,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 3),

                          const Text(
                            'Travel Smart, Travel Green',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: mainGreen,
                            ),
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'Plan sustainable trips,\n'
                                'explore responsibly,\n'
                                'and protect our planet.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // =================================================
              // LOGIN SECTION
              // =================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  6,
                  16,
                  22,
                ),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    // =================================================
                    // WELCOME
                    // =================================================

                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: mainGreen,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Login to continue your eco-friendly journey.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // =================================================
                    // EMAIL
                    // =================================================

                    TextField(
                      controller: emailController,
                      keyboardType:
                      TextInputType.emailAddress,
                      textInputAction:
                      TextInputAction.next,

                      decoration: inputDecoration(
                        hint: 'Email',
                        icon: Icons.email_outlined,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // =================================================
                    // PASSWORD
                    // =================================================

                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      textInputAction:
                      TextInputAction.done,

                      onSubmitted: (_) {
                        if (!isLoading &&
                            !isGoogleLoading) {
                          login();
                        }
                      },

                      decoration: inputDecoration(
                        hint: 'Password',
                        icon: Icons.lock_outline,

                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              hidePassword =
                              !hidePassword;
                            });
                          },

                          icon: Icon(
                            hidePassword
                                ? Icons
                                .visibility_off_outlined
                                : Icons
                                .visibility_outlined,
                            color: mainGreen,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 2),

                    // =================================================
                    // FORGOT PASSWORD
                    // =================================================

                    Align(
                      alignment: Alignment.centerRight,

                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                              const ForgotPasswordPage(),
                            ),
                          );
                        },

                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 4,
                          ),
                        ),

                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: mainGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 5),

                    // =================================================
                    // LOGIN BUTTON
                    // =================================================

                    SizedBox(
                      width: double.infinity,
                      height: 45,

                      child: ElevatedButton(
                        onPressed:
                        isLoading || isGoogleLoading
                            ? null
                            : login,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainGreen,
                          foregroundColor: Colors.white,

                          disabledBackgroundColor:
                          mainGreen.withOpacity(0.55),

                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12),
                          ),
                        ),

                        child: isLoading

                        // Loading
                            ? const SizedBox(
                          width: 20,
                          height: 20,

                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )

                        // Normal
                            : const Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [

                            Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),

                            SizedBox(width: 7),

                            Icon(
                              Icons.eco,
                              size: 17,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // =================================================
                    // OR CONTINUE WITH
                    // =================================================

                    Row(
                      children: [

                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade300,
                          ),
                        ),

                        Padding(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),

                          child: Text(
                            'or continue with',
                            style: TextStyle(
                              fontSize: 10,
                              color:
                              Colors.grey.shade600,
                            ),
                          ),
                        ),

                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // =================================================
                    // GOOGLE LOGIN BUTTON
                    // =================================================

                    SizedBox(
                      width: double.infinity,
                      height: 45,

                      child: OutlinedButton(
                        onPressed:
                        isLoading || isGoogleLoading
                            ? null
                            : googleLogin,

                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,

                          backgroundColor: Colors.white,

                          side: BorderSide(
                            color: Colors.grey.shade300,
                          ),

                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12),
                          ),
                        ),

                        child: isGoogleLoading

                        // Google Loading
                            ? const SizedBox(
                          width: 20,
                          height: 20,

                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            color: mainGreen,
                          ),
                        )

                        // Google Button
                            : Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [

                            // REAL GOOGLE ICON
                            Image.asset(
                              'assets/images/googleIcon.png',
                              width: 20,
                              height: 20,
                              fit: BoxFit.contain,
                            ),

                            const SizedBox(width: 9),

                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // =================================================
                    // SIGN UP
                    // =================================================

                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment:
                        WrapCrossAlignment.center,

                        children: [

                          Text(
                            "Don't have an account?",
                            style: TextStyle(
                              fontSize: 12,
                              color:
                              Colors.grey.shade600,
                            ),
                          ),

                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,

                                MaterialPageRoute(
                                  builder: (_) =>
                                  const RegisterPage(),
                                ),
                              );
                            },

                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 12,
                                color: mainGreen,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // REUSABLE TEXT FIELD DESIGN
  // ============================================================

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,

      hintStyle: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade500,
      ),

      prefixIcon: Icon(
        icon,
        color: mainGreen,
        size: 19,
      ),

      suffixIcon: suffix,

      filled: true,
      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(
        vertical: 13,
        horizontal: 12,
      ),

      // Normal Border
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),

        borderSide: BorderSide(
          color: mainGreen.withOpacity(0.30),
        ),
      ),

      // Focus Border
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),

        borderSide: const BorderSide(
          color: mainGreen,
          width: 1.3,
        ),
      ),

      // Error Border
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),

        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
    );
  }
}