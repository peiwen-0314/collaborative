import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import 'login_page.dart';

class ResetPasswordSuccessPage extends StatefulWidget {
  final String email;

  const ResetPasswordSuccessPage({
    super.key,
    required this.email,
  });

  @override
  State<ResetPasswordSuccessPage> createState() =>
      _ResetPasswordSuccessPageState();
}

class _ResetPasswordSuccessPageState
    extends State<ResetPasswordSuccessPage> {
  static const Color mainGreen = Color(0xFF2E7D32);

  final AuthController authController = AuthController();

  Timer? _timer;

  int _secondsRemaining = 60;

  bool isResending = false;

  // ============================================================
  // START COUNTDOWN
  // ============================================================

  @override
  void initState() {
    super.initState();

    startCountdown();
  }

  void startCountdown() {
    _timer?.cancel();

    setState(() {
      _secondsRemaining = 60;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (_secondsRemaining > 0) {
          setState(() {
            _secondsRemaining--;
          });
        } else {
          timer.cancel();
        }
      },
    );
  }

  // ============================================================
  // RESEND PASSWORD RESET EMAIL
  // ============================================================

  Future<void> resendEmail() async {
    if (_secondsRemaining > 0) {
      return;
    }

    setState(() {
      isResending = true;
    });

    final String? error =
    await authController.forgotPassword(
      email: widget.email,
    );

    if (!mounted) return;

    setState(() {
      isResending = false;
    });

    if (error == null) {
      // Restart 60 second countdown
      startCountdown();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset email sent again.',
          ),
          backgroundColor: mainGreen,
          behavior: SnackBarBehavior.floating,
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
    _timer?.cancel();

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
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
          ),

          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [

              // =================================================
              // SUCCESS ICON
              // =================================================

              Container(
                width: 105,
                height: 105,

                decoration: BoxDecoration(
                  color: mainGreen.withOpacity(
                    0.10,
                  ),
                  shape: BoxShape.circle,
                ),

                child: Center(
                  child: Container(
                    width: 74,
                    height: 74,

                    decoration: const BoxDecoration(
                      color: mainGreen,
                      shape: BoxShape.circle,
                    ),

                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: Colors.white,
                      size: 37,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // =================================================
              // TITLE
              // =================================================

              const Text(
                'Check Your Email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mainGreen,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'We have sent a password reset link to',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 7),

              // Email
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: mainGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Please check your inbox and follow the instructions in the email to reset your password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 32),

              // =================================================
              // BACK TO LOGIN
              // =================================================

              SizedBox(
                width: double.infinity,
                height: 48,

                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const LoginPage(),
                      ),
                          (route) => false,
                    );
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,

                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),

                  child: const Text(
                    'Back to Login',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // =================================================
              // RESEND EMAIL SECTION
              // =================================================

              // Countdown OR Resend Button
              if (_secondsRemaining > 0)
                Text(
                  'Request email again? $_secondsRemaining sec',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                )
              else
                TextButton.icon(
                  onPressed:
                  isResending ? null : resendEmail,

                  icon: isResending
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: mainGreen,
                    ),
                  )
                      : const Icon(
                    Icons.refresh_rounded,
                    color: mainGreen,
                    size: 12,
                  ),

                  label: Text(
                    isResending
                        ? 'Sending...'
                        : 'Resend Email',
                    style: const TextStyle(
                      color: mainGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}