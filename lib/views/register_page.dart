import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController =
  TextEditingController();

  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController passwordController =
  TextEditingController();

  final TextEditingController confirmPasswordController =
  TextEditingController();

  final AuthController authController =
  AuthController();

  bool isLoading = false;

  bool hidePassword = true;
  bool hideConfirmPassword = true;

  bool passwordFulfilled = false;

  Map<String, bool> passwordChecklist =
  const {
    'At least 8 characters': false,
    'An uppercase letter': false,
    'A lowercase letter': false,
    'A number': false,
    'A special character': false,
  };

  static const Color mainGreen =
  Color(0xFF2E7D32);

  static const Color fulfilledCyan =
  Color(0xFF00BCD4);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    passwordController.addListener(
      _checkPasswordFulfilled,
    );
  }

  // ============================================================
  // PASSWORD CHECK
  // ============================================================

  void _checkPasswordFulfilled() {
    final checklist =
    authController.passwordRuleChecklist(
      passwordController.text,
    );

    setState(() {
      passwordChecklist = checklist;

      passwordFulfilled =
          checklist.values.every(
                (met) => met,
          );
    });
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> register() async {
    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    final String? error =
    await authController.register(
      name: nameController.text,
      email: emailController.text,
      password: passwordController.text,
      confirmPassword:
      confirmPasswordController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = false;
    });

    // ==========================================================
    // SUCCESS
    // ==========================================================

    if (error == null) {
      ScaffoldMessenger.of(context)
          .hideCurrentSnackBar();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.white,
              ),
              SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  'Account registered successfully. Please login.',
                ),
              ),
            ],
          ),
          backgroundColor:
          mainGreen,
          behavior:
          SnackBarBehavior.floating,
          duration:
          Duration(
            seconds: 2,
          ),
        ),
      );

      // Give the user time to see the success message.
      await Future.delayed(
        const Duration(
          milliseconds: 1200,
        ),
      );

      if (!mounted) {
        return;
      }

      // RegisterPage was opened from LoginPage,
      // so pop returns directly to LoginPage.
      Navigator.pop(
        context,
      );

      return;
    }

    // ==========================================================
    // ERROR
    // ==========================================================

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          error,
        ),
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
    passwordController.removeListener(
      _checkPasswordFulfilled,
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

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
      Colors.white,

      body: SafeArea(
        child:
        SingleChildScrollView(
          child: Column(
            children: [
              // ==================================================
              // TOP BACKGROUND SECTION
              // ==================================================

              SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.30)
                    .clamp(235.0, 300.0),
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/backgroundImg.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),

                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.03),
                            Colors.white.withOpacity(0.08),
                            Colors.white.withOpacity(0.55),
                          ],
                        ),
                      ),
                    ),

                    // Back button
                    Positioned(
                      left: 4,
                      top: 4,
                      child: IconButton(
                        onPressed: isLoading
                            ? null
                            : () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: mainGreen,
                          size: 20,
                        ),
                      ),
                    ),

                    // Same branding size as Login Page
                    Positioned(
                      left: 28,
                      right: 28,
                      bottom: 35,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.eco,
                                size: 38,
                                color: mainGreen,
                              ),
                              SizedBox(width: 7),
                              Text(
                                'EcoTravel',
                                style: TextStyle(
                                  fontSize: 32,
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: mainGreen,
                            ),
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'Plan sustainable trips,\n'
                                'explore responsibly,\n'
                                'and protect our planet.',
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.30,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // REGISTER FORM
              // ==================================================

              Padding(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal:
                  28,
                ),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

                  children: [
                    const SizedBox(
                      height: 10,
                    ),

                    // =============================================
                    // TITLE
                    // =============================================

                    const Text(
                      'Create Account',

                      style:
                      TextStyle(
                        fontSize: 30,

                        fontWeight:
                        FontWeight.bold,

                        color:
                        mainGreen,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    const Text(
                      'Join EcoTravel and start your sustainable journey.',

                      style:
                      TextStyle(
                        fontSize: 16,

                        color:
                        Colors.grey,
                      ),
                    ),

                    const SizedBox(
                      height: 30,
                    ),

                    // =============================================
                    // FULL NAME
                    // =============================================

                    TextField(
                      controller:
                      nameController,

                      enabled:
                      !isLoading,

                      textInputAction:
                      TextInputAction
                          .next,

                      textCapitalization:
                      TextCapitalization
                          .words,

                      decoration:
                      inputDecoration(
                        hint:
                        'Full Name',

                        icon:
                        Icons
                            .person_outline,
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // =============================================
                    // EMAIL
                    // =============================================

                    TextField(
                      controller:
                      emailController,

                      enabled:
                      !isLoading,

                      keyboardType:
                      TextInputType
                          .emailAddress,

                      textInputAction:
                      TextInputAction
                          .next,

                      decoration:
                      inputDecoration(
                        hint:
                        'Email',

                        icon:
                        Icons
                            .email_outlined,
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // =============================================
                    // PASSWORD
                    // =============================================

                    TextField(
                      controller:
                      passwordController,

                      enabled:
                      !isLoading,

                      obscureText:
                      hidePassword,

                      textInputAction:
                      TextInputAction
                          .next,

                      decoration:
                      inputDecoration(
                        hint:
                        'Password',

                        icon:
                        Icons
                            .lock_outline,

                        valid:
                        passwordFulfilled,

                        suffix:
                        IconButton(
                          onPressed: () {
                            setState(
                                  () {
                                hidePassword =
                                !hidePassword;
                              },
                            );
                          },

                          icon:
                          Icon(
                            hidePassword
                                ? Icons
                                .visibility_off_outlined
                                : Icons
                                .visibility_outlined,

                            color:
                            passwordFulfilled
                                ? fulfilledCyan
                                : mainGreen,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    // =============================================
                    // PASSWORD CHECKLIST
                    // =============================================

                    Padding(
                      padding:
                      const EdgeInsets
                          .only(
                        left: 4,
                      ),

                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                        children: [
                          for (final rule
                          in passwordChecklist
                              .entries)
                            Padding(
                              padding:
                              const EdgeInsets
                                  .only(
                                bottom: 3,
                              ),

                              child:
                              Row(
                                children: [
                                  Icon(
                                    rule.value
                                        ? Icons
                                        .check_circle
                                        : Icons
                                        .cancel,

                                    size:
                                    14,

                                    color:
                                    rule.value
                                        ? Colors
                                        .green
                                        .shade600
                                        : Colors
                                        .red
                                        .shade400,
                                  ),

                                  const SizedBox(
                                    width:
                                    6,
                                  ),

                                  Text(
                                    rule.key,

                                    style:
                                    TextStyle(
                                      fontSize:
                                      11,

                                      color:
                                      rule.value
                                          ? Colors
                                          .green
                                          .shade700
                                          : Colors
                                          .red
                                          .shade400,

                                      fontWeight:
                                      rule.value
                                          ? FontWeight
                                          .w600
                                          : FontWeight
                                          .normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // =============================================
                    // CONFIRM PASSWORD
                    // =============================================

                    TextField(
                      controller:
                      confirmPasswordController,

                      enabled:
                      !isLoading,

                      obscureText:
                      hideConfirmPassword,

                      textInputAction:
                      TextInputAction
                          .done,

                      onSubmitted: (_) {
                        if (!isLoading) {
                          register();
                        }
                      },

                      decoration:
                      inputDecoration(
                        hint:
                        'Confirm Password',

                        icon:
                        Icons
                            .lock_outline,

                        suffix:
                        IconButton(
                          onPressed: () {
                            setState(
                                  () {
                                hideConfirmPassword =
                                !hideConfirmPassword;
                              },
                            );
                          },

                          icon:
                          Icon(
                            hideConfirmPassword
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
                      height: 12,
                    ),

                    // =============================================
                    // CREATE ACCOUNT BUTTON
                    // =============================================

                    SizedBox(
                      width:
                      double.infinity,

                      height:
                      55,

                      child:
                      ElevatedButton(
                        onPressed:
                        isLoading
                            ? null
                            : register,

                        style:
                        ElevatedButton
                            .styleFrom(
                          backgroundColor:
                          mainGreen,

                          foregroundColor:
                          Colors.white,

                          disabledBackgroundColor:
                          mainGreen
                              .withOpacity(
                            0.55,
                          ),

                          elevation:
                          0,

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              16,
                            ),
                          ),
                        ),

                        child:
                        isLoading
                            ? const SizedBox(
                          height:
                          24,

                          width:
                          24,

                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2,

                            color:
                            Colors
                                .white,
                          ),
                        )
                            : const Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .center,

                          children: [
                            Text(
                              'Create Account',

                              style:
                              TextStyle(
                                fontSize:
                                18,

                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),

                            SizedBox(
                              width:
                              10,
                            ),

                            Icon(
                              Icons
                                  .eco,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 28,
                    ),

                    // =============================================
                    // LOGIN LINK
                    // =============================================

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .center,

                      children: [
                        const Text(
                          'Already have an account?',

                          style:
                          TextStyle(
                            color:
                            Colors.grey,
                          ),
                        ),

                        TextButton(
                          onPressed:
                          isLoading
                              ? null
                              : () {
                            Navigator.pop(
                              context,
                            );
                          },

                          child:
                          const Text(
                            'Login',

                            style:
                            TextStyle(
                              color:
                              mainGreen,

                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 35,
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
  // INPUT DECORATION
  // ============================================================

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
    bool valid = false,
  }) {
    final Color activeColor =
    valid
        ? fulfilledCyan
        : mainGreen;

    return InputDecoration(
      hintText:
      hint,

      prefixIcon:
      Icon(
        icon,
        color:
        activeColor,
      ),

      suffixIcon:
      suffix,

      filled:
      true,

      fillColor:
      Colors.white,

      contentPadding:
      const EdgeInsets
          .symmetric(
        vertical:
        18,
      ),

      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          16,
        ),

        borderSide:
        BorderSide(
          color:
          valid
              ? fulfilledCyan
              : mainGreen
              .withOpacity(
            0.25,
          ),

          width:
          valid
              ? 1.5
              : 1,
        ),
      ),

      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          16,
        ),

        borderSide:
        BorderSide(
          color:
          activeColor,

          width:
          1.5,
        ),
      ),

      errorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          16,
        ),

        borderSide:
        const BorderSide(
          color:
          Colors.red,
        ),
      ),
    );
  }
}