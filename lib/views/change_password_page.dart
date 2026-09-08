import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';

// Pushed from ProfilePage's "Change Password" tile. Changes the
// password directly in-app (current password -> new password) via
// Firebase Auth reauthentication, instead of emailing a reset link.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color pageBackground = Color(0xFFF8FAF8);
  static const Color textColor = Color(0xFF212121);
  static const Color secondaryText = Color(0xFF777777);
  static const Color borderColor = Color(0xFFE1E5E1);

  final AuthController authController = AuthController();

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool hideCurrentPassword = true;
  bool hideNewPassword = true;
  bool hideConfirmPassword = true;
  bool isSubmitting = false;

  Map<String, bool> passwordChecklist = const {
    'At least 8 characters': false,
    'An uppercase letter': false,
    'A lowercase letter': false,
    'A number': false,
    'A special character': false,
  };

  @override
  void initState() {
    super.initState();
    newPasswordController.addListener(_refreshChecklist);
  }

  void _refreshChecklist() {
    setState(() {
      passwordChecklist = authController.passwordRuleChecklist(
        newPasswordController.text,
      );
    });
  }

  @override
  void dispose() {
    newPasswordController.removeListener(_refreshChecklist);
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : mainGreen,
      ),
    );
  }

  Future<void> _submit() async {
    if (isSubmitting) return;

    setState(() => isSubmitting = true);

    final error = await authController.changePassword(
      currentPassword: currentPasswordController.text,
      newPassword: newPasswordController.text,
      confirmPassword: confirmPasswordController.text,
    );

    if (!mounted) return;
    setState(() => isSubmitting = false);

    if (error != null) {
      _showSnack(error, isError: true);
      return;
    }

    _showSnack('Password changed successfully');
    Navigator.pop(context);
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    required VoidCallback onToggleVisibility,
    required bool hidden,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13.5, color: secondaryText),
      prefixIcon: Icon(icon, size: 20, color: mainGreen),
      suffixIcon: IconButton(
        onPressed: onToggleVisibility,
        icon: Icon(
          hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 19,
          color: secondaryText,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: mainGreen, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Change Password',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update your password',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter your current password and choose a new one.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Current Password',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: currentPasswordController,
                obscureText: hideCurrentPassword,
                textInputAction: TextInputAction.next,
                decoration: _decoration(
                  hint: 'Enter current password',
                  icon: Icons.lock_outline,
                  hidden: hideCurrentPassword,
                  onToggleVisibility: () {
                    setState(() {
                      hideCurrentPassword = !hideCurrentPassword;
                    });
                  },
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'New Password',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: newPasswordController,
                obscureText: hideNewPassword,
                textInputAction: TextInputAction.next,
                decoration: _decoration(
                  hint: 'Enter new password',
                  icon: Icons.lock_reset_outlined,
                  hidden: hideNewPassword,
                  onToggleVisibility: () {
                    setState(() {
                      hideNewPassword = !hideNewPassword;
                    });
                  },
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
                              rule.value ? Icons.check_circle : Icons.cancel,
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

              const SizedBox(height: 12),

              const Text(
                'Confirm New Password',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: confirmPasswordController,
                obscureText: hideConfirmPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: _decoration(
                  hint: 'Re-enter new password',
                  icon: Icons.lock_reset_outlined,
                  hidden: hideConfirmPassword,
                  onToggleVisibility: () {
                    setState(() {
                      hideConfirmPassword = !hideConfirmPassword;
                    });
                  },
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: mainGreen,
                    disabledBackgroundColor: const Color(0xFFB8C9BA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Update Password',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
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
