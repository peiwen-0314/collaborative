import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import 'reset_password_success_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState
    extends State<ForgotPasswordPage> {
  final TextEditingController emailController =
  TextEditingController();

  final AuthController authController =
  AuthController();

  bool isLoading = false;

  static const Color mainGreen =
  Color(0xFF2E7D32);

  // ============================================================
  // SEND RESET EMAIL
  // ============================================================

  Future<void> sendResetEmail() async {
    setState(() {
      isLoading = true;
    });

    final String? error =
    await authController.forgotPassword(
      email: emailController.text,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (error == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResetPasswordSuccessPage(
                email: emailController.text.trim(),
              ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor:
          Colors.red.shade700,
          behavior:
          SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
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
              // HEADER
              // =================================================

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  28,
                ),

                child: Column(
                  children: [

                    // Back Button
                    Align(
                      alignment:
                      Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons
                              .arrow_back_ios_new_rounded,
                          color: mainGreen,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Icon Circle
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: mainGreen
                            .withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: mainGreen,
                        size: 40,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // EcoTravel
                    const Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.eco,
                          color: mainGreen,
                          size: 28,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'EcoTravel',
                          style: TextStyle(
                            color: mainGreen,
                            fontSize: 23,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // =================================================
              // FORM
              // =================================================

              Padding(
                padding:
                const EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  30,
                ),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight:
                        FontWeight.bold,
                        color: mainGreen,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'No worries! Enter the email address associated with your account and we will send you a password reset link.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color:
                        Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 26),

                    // Email Field
                    TextField(
                      controller:
                      emailController,
                      keyboardType:
                      TextInputType
                          .emailAddress,
                      textInputAction:
                      TextInputAction.done,
                      onSubmitted: (_) {
                        if (!isLoading) {
                          sendResetEmail();
                        }
                      },
                      decoration:
                      InputDecoration(
                        hintText:
                        'Email Address',

                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors
                              .grey.shade500,
                        ),

                        prefixIcon:
                        const Icon(
                          Icons
                              .email_outlined,
                          color: mainGreen,
                          size: 20,
                        ),

                        filled: true,
                        fillColor:
                        Colors.white,

                        contentPadding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 14,
                          horizontal: 14,
                        ),

                        enabledBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                          borderSide:
                          BorderSide(
                            color: mainGreen
                                .withOpacity(
                              0.30,
                            ),
                          ),
                        ),

                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                          borderSide:
                          const BorderSide(
                            color: mainGreen,
                            width: 1.3,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Send Button
                    SizedBox(
                      width:
                      double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : sendResetEmail,

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
                          elevation: 0,

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),
                        ),

                        child: isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2,
                            color:
                            Colors.white,
                          ),
                        )
                            : const Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                          children: [
                            Icon(
                              Icons
                                  .send_outlined,
                              size: 18,
                            ),
                            SizedBox(
                              width: 8,
                            ),
                            Text(
                              'Send Reset Link',
                              style:
                              TextStyle(
                                fontSize:
                                14,
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ],
                        ),
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
}