import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_loading_indicator.dart';

/// A dedicated "Reset your password" screen, pushed from the login page's
/// "Forgot Password?" link — mirrors the same flow as LoginPage.tsx's
/// reset-request form (single email field, "Send Reset Link"), as its own
/// screen rather than an in-place swap, matching the standard mobile
/// pattern of pushing a new page for a distinct task.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  bool _isSending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(
        () =>
            _error = 'Please enter your email address to reset your password.',
      );
      return;
    }
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).requestPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _sent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Icon(
                _sent ? Icons.mark_email_read_outlined : Icons.lock_reset,
                size: 56,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                _sent ? 'Check your inbox' : 'Reset your password',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _sent
                    ? "We've sent a password reset link to ${_emailController.text.trim()}. Open it to set a new password."
                    : 'Enter the email linked to your account and we will send you a reset link.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: AppColors.cardShadow,
                ),
                child: _sent ? _successContent() : _formContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Email Address for Password Reset',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.mail_outline),
            hintText: 'Enter your email to receive a reset link',
          ),
          onSubmitted: (_) => _send(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: AppColors.destructive, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isSending ? null : _send,
          child: _isSending
              ? AppLoadingIndicator(size: 22, color: AppColors.primaryDark)
              : const Text('Send Reset Link'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to Login'),
        ),
      ],
    );
  }

  Widget _successContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to Login'),
        ),
      ],
    );
  }
}
