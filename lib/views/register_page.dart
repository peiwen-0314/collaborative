import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
  TextEditingController();

  final AuthController authController = AuthController();

  bool isLoading = false;
  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool passwordFulfilled = false;
  Map<String, bool> passwordChecklist = const {
    'At least 8 characters': false,
    'An uppercase letter': false,
    'A lowercase letter': false,
    'A number': false,
    'A special character': false,
  };

  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color fulfilledCyan = Color(0xFF00BCD4);

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_checkPasswordFulfilled);
  }

  void _checkPasswordFulfilled() {
    final checklist =
        authController.passwordRuleChecklist(passwordController.text);
    setState(() {
      passwordChecklist = checklist;
      passwordFulfilled = checklist.values.every((met) => met);
    });
  }

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

  @override
  void dispose() {
    passwordController.removeListener(_checkPasswordFulfilled);
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
              // Same hero treatment as LoginPage, with a back button
              // overlaid on top since this page is pushed on top of it.
              // =====================================
              SizedBox(
                height: 430,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/backgroundImg.png',
                      fit: BoxFit.cover,
                    ),

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

                    Positioned(
                      left: 4,
                      top: 4,
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
              // REGISTER FORM
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
                      'Create Account',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: mainGreen,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Join EcoTravel and start your sustainable journey.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Full Name
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: inputDecoration(
                        hint: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Email
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: inputDecoration(
                        hint: 'Email',
                        icon: Icons.email_outlined,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Password
                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      textInputAction: TextInputAction.next,
                      decoration: inputDecoration(
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        valid: passwordFulfilled,
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
                            color: passwordFulfilled ? fulfilledCyan : mainGreen,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final rule in passwordChecklist.entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                children: [
                                  Icon(
                                    rule.value
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 14,
                                    color: rule.value
                                        ? Colors.green.shade600
                                        : Colors.red.shade400,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    rule.key,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: rule.value
                                          ? Colors.green.shade700
                                          : Colors.red.shade400,
                                      fontWeight: rule.value
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Confirm Password
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
                              hideConfirmPassword = !hideConfirmPassword;
                            });
                          },
                          icon: Icon(
                            hideConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: mainGreen,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Create Account Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                          mainGreen.withOpacity(0.55),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
                              'Create Account',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.eco),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account?',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Login',
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

  // Same input styling as LoginPage's own fields - [valid] lights the
  // field up fulfilledCyan instead of the usual mainGreen, used by the
  // Password field so it turns cyan the moment it fulfils the rules
  // (see passwordFulfilled/_checkPasswordFulfilled) rather than only
  // showing red/green feedback once Submit is pressed.
  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
    bool valid = false,
  }) {
    final Color activeColor = valid ? fulfilledCyan : mainGreen;
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: activeColor,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 18,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: valid ? fulfilledCyan : mainGreen.withOpacity(0.25),
          width: valid ? 1.5 : 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: activeColor,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
    );
  }
}
