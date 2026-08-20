import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

/// Kept separate from Profile so password fields are only visible when the
/// user explicitly chooses to update their credentials.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  ({int score, String label, Color color}) _passwordStrength(String password) {
    if (password.isEmpty) {
      return (score: 0, label: '', color: AppColors.border);
    }
    var score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 10) score++;
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(password) ||
        RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) {
      score++;
    }
    return switch (score) {
      0 || 1 => (score: score, label: 'Weak', color: AppColors.destructive),
      2 => (score: score, label: 'Fair', color: AppColors.gold),
      3 => (score: score, label: 'Good', color: const Color(0xFF06B6D4)),
      _ => (score: score, label: 'Strong', color: AppColors.success),
    };
  }

  Future<void> _updatePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      showErrorSnackBar(context, 'Fill in all password fields.');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      showErrorSnackBar(context, 'New passwords do not match.');
      return;
    }
    if (_newPasswordController.text.length < 6) {
      showErrorSnackBar(
        context,
        'Password must be at least 6 characters long.',
      );
      return;
    }

    setState(() => _isSaving = true);
    final result = await ref
        .read(authProvider.notifier)
        .changePassword(
          _currentPasswordController.text,
          _newPasswordController.text,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result.success) {
      showSuccessSnackBar(context, 'Password changed successfully.');
      Navigator.of(context).pop();
    } else {
      showErrorSnackBar(context, result.error ?? 'Failed to update password.');
    }
  }

  Widget _passwordField(
    String label,
    TextEditingController controller,
    bool obscure,
    VoidCallback toggle, {
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: toggle,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final newPassword = _newPasswordController.text;
    final strength = _passwordStrength(newPassword);
    final confirmEntered = _confirmPasswordController.text.isNotEmpty;
    final passwordsMatch =
        confirmEntered && _confirmPasswordController.text == newPassword;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Change Password')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Keep your account secure',
              style: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _passwordField(
                    'Current Password',
                    _currentPasswordController,
                    _obscureCurrent,
                    () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  const SizedBox(height: 16),
                  _passwordField(
                    'New Password',
                    _newPasswordController,
                    _obscureNew,
                    () => setState(() => _obscureNew = !_obscureNew),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (newPassword.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: i < strength.score
                                    ? strength.color
                                    : AppColors.border,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Password strength',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        Text(
                          strength.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: strength.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: newPassword.length >= 6
                              ? AppColors.success
                              : AppColors.mutedForeground.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'At least 6 characters',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: newPassword.length >= 6
                              ? AppColors.success
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _passwordField(
                    'Confirm New Password',
                    _confirmPasswordController,
                    _obscureConfirm,
                    () => setState(() => _obscureConfirm = !_obscureConfirm),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (confirmEntered) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: passwordsMatch
                                ? AppColors.success
                                : AppColors.destructive,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          passwordsMatch
                              ? 'Passwords match'
                              : 'Passwords do not match',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: passwordsMatch
                                ? AppColors.success
                                : AppColors.destructive,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _updatePassword,
                      child: _isSaving
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryDark,
                              ),
                            )
                          : const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
