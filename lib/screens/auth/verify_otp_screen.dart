import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_logo_header.dart';

// Must match the Email OTP length configured in the Supabase project.
const _emailOtpLength = 8;

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyOtpScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  String _otp = '';
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  bool _isVerifying = false;
  bool _isResending = false;
  int _cooldown = 0;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.email.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showErrorSnackBar(
          context,
          'No email address provided. Redirecting to register.',
        );
        context.go('/register');
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_otp.length != _emailOtpLength) {
      setState(
        () => _error = 'Please enter the complete $_emailOtpLength-digit code.',
      );
      return;
    }
    setState(() => _isVerifying = true);
    final result = await ref
        .read(authProvider.notifier)
        .verifyOtp(email: widget.email, token: _otp);
    setState(() => _isVerifying = false);

    if (!mounted) return;
    if (result.success) {
      showSuccessSnackBar(
        context,
        'Email confirmed and account registered successfully. You can now log in.',
      );
      context.go('/login');
    } else {
      setState(() => _error = result.error);
    }
  }

  Future<void> _resend() async {
    if (_isResending || _cooldown > 0) return;
    setState(() => _isResending = true);
    try {
      await ref.read(authProvider.notifier).resendOtp(widget.email);
      if (mounted) {
        showSuccessSnackBar(
          context,
          'A new verification code has been sent to your email.',
        );
        _startCooldown();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Widget _otpCells() {
    return GestureDetector(
      onTap: _otpFocusNode.requestFocus,
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            IgnorePointer(
              child: Row(
                children: List.generate(_emailOtpLength, (index) {
                  final hasDigit = index < _otp.length;
                  final isActive = index == _otp.length && !_isVerifying;
                  final borderColor = _error != null
                      ? AppColors.destructive
                      : (isActive || hasDigit
                            ? AppColors.primary
                            : AppColors.border);
                  return Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      margin: EdgeInsets.only(
                        right: index == _emailOtpLength - 1 ? 0 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: borderColor,
                          width: isActive ? 2 : 1.25,
                        ),
                      ),
                      child: Text(
                        hasDigit ? _otp[index] : '',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Positioned.fill(
              child: TextField(
                controller: _otpController,
                focusNode: _otpFocusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_emailOtpLength),
                ],
                maxLength: _emailOtpLength,
                cursorColor: Colors.transparent,
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                  fillColor: Colors.transparent,
                ),
                onChanged: (value) {
                  setState(() {
                    _otp = value;
                    _error = null;
                  });
                  if (value.length == _emailOtpLength) _submit();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                AppLogoHeader(
                  title: 'Verify Your Email',
                  subtitle:
                      'Enter the $_emailOtpLength-digit code sent to ${widget.email}',
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    children: [
                      _otpCells(),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: AppColors.destructive),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isVerifying ? null : _submit,
                          child: _isVerifying
                              ? SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryDark,
                                  ),
                                )
                              : const Text('Verify Account'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Didn't get a code? "),
                          GestureDetector(
                            onTap: _resend,
                            child: Text(
                              _isResending
                                  ? 'Sending...'
                                  : (_cooldown > 0
                                        ? 'Resend in ${_cooldown}s'
                                        : 'Resend code'),
                              style: TextStyle(
                                color: (_isResending || _cooldown > 0)
                                    ? AppColors.mutedForeground
                                    : Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
