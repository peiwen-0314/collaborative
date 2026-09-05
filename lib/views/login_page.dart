import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../controllers/personalization_controller.dart';
import 'home_page.dart';
import 'interest_selection_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final AuthController authController = AuthController();

  bool isLoading = false;
  bool hidePassword = true;

  final Color mainGreen = const Color(0xFF2E7D32);

  Future<void> login() async {
    setState(() {
      isLoading = true;
    });

    String? error = await authController.login(
      email: emailController.text,
      password: passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (error == null) {
      final personalization =
      PersonalizationController();

      final needsOnboarding =
      await personalization.needsOnboarding();

      personalization.dispose();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => needsOnboarding
              ? const InterestSelectionPage()
              : const HomePage(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [

              // =====================================
              // TOP BACKGROUND SECTION
              // =====================================
              SizedBox(
                height: 430,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [

                    // Background Image
                    Image.asset(
                      'assets/images/backgroundImg.png',
                      fit: BoxFit.cover,
                    ),

                    // Light overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.10),
                            Colors.white.withOpacity(0.20),
                            Colors.white.withOpacity(0.80),
                          ],
                        ),
                      ),
                    ),

                    // Logo + Title
                    Positioned(
                      left: 30,
                      bottom: 45,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.eco,
                                size: 55,
                                color: mainGreen,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'EcoTravel',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: mainGreen,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Travel Smart, Travel Green',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: mainGreen,
                            ),
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            'Plan sustainable trips,\n'
                                'explore responsibly,\n'
                                'and protect our planet.',
                            style: TextStyle(
                              fontSize: 17,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // =====================================
              // LOGIN FORM
              // =====================================
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const SizedBox(height: 10),

                    Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: mainGreen,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Login to continue your eco-friendly journey.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Email
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: mainGreen,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                        const EdgeInsets.symmetric(
                          vertical: 18,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: mainGreen.withOpacity(0.25),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: mainGreen,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Password
                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: mainGreen,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: mainGreen,
                          ),
                          onPressed: () {
                            setState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                        const EdgeInsets.symmetric(
                          vertical: 18,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: mainGreen.withOpacity(0.25),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: mainGreen,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 5),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // Later connect forgot password page
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: mainGreen,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(16),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                          height: 24,
                          width: 24,
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
                              'Login',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.eco),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Divider
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                          ),
                          child: Text(
                            'or continue with',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Social buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Google login later
                            },
                            icon: const Icon(
                              Icons.g_mobiledata,
                              size: 28,
                            ),
                            label: const Text('Google'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                              Colors.black87,
                              padding:
                              const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              side: BorderSide(
                                color:
                                Colors.grey.shade300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Facebook login later
                            },
                            icon: const Icon(
                              Icons.facebook,
                            ),
                            label: const Text('Facebook'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                              Colors.black87,
                              padding:
                              const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              side: BorderSide(
                                color:
                                Colors.grey.shade300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Register
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account?",
                          style: TextStyle(
                            color: Colors.grey,
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
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: mainGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 35),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}