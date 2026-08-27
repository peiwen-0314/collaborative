import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController nameController =
  TextEditingController();

  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController passwordController =
  TextEditingController();

  final TextEditingController confirmPasswordController =
  TextEditingController();

  final AuthController authController = AuthController();

  // ============================================================
  // VARIABLES
  // ============================================================

  bool isLoading = false;
  bool hidePassword = true;
  bool hideConfirmPassword = true;

  static const Color mainGreen = Color(0xFF2E7D32);

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> register() async {
    setState(() {
      isLoading = true;
    });

    final String? error = await authController.register(
      name: nameController.text,
      email: emailController.text,
      password: passwordController.text,
      confirmPassword: confirmPasswordController.text,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
              // TOP HEADER
              // =================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  24,
                ),

                child: Column(
                  children: [

                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: mainGreen,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // =================================================
              // REGISTER FORM
              // =================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  5,
                  16,
                  25,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // =================================================
                    // TITLE
                    // =================================================

                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: mainGreen,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Join EcoTravel and start your sustainable journey.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // =================================================
                    // FULL NAME
                    // =================================================

                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: inputDecoration(
                        hint: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                    ),

                    const SizedBox(height: 13),

                    // =================================================
                    // EMAIL
                    // =================================================

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: inputDecoration(
                        hint: 'Email',
                        icon: Icons.email_outlined,
                      ),
                    ),

                    const SizedBox(height: 13),

                    // =================================================
                    // PASSWORD
                    // =================================================

                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      textInputAction: TextInputAction.next,
                      decoration: inputDecoration(
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: mainGreen,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 13),

                    // =================================================
                    // CONFIRM PASSWORD
                    // =================================================

                    TextField(
                      controller: confirmPasswordController,
                      obscureText: hideConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!isLoading) {
                          register();
                        }
                      },
                      decoration: inputDecoration(
                        hint: 'Confirm Password',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              hideConfirmPassword =
                              !hideConfirmPassword;
                            });
                          },
                          icon: Icon(
                            hideConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: mainGreen,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // =================================================
                    // CREATE ACCOUNT BUTTON
                    // =================================================

                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                          mainGreen.withOpacity(0.55),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
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

                    const SizedBox(height: 18),

                    // =================================================
                    // LOGIN LINK
                    // =================================================

                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),

                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 12,
                                color: mainGreen,
                                fontWeight: FontWeight.bold,
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
  // REUSABLE INPUT DESIGN
  // Same design as Login Page
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

      // Normal
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: mainGreen.withOpacity(0.30),
        ),
      ),

      // Focus
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: mainGreen,
          width: 1.3,
        ),
      ),

      // Error
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
    );
  }
}