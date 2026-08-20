import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback.dart';
import '../../core/supabase_config.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/percent_loading_indicator.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  List<String> _departments = [];
  String? _selectedDepartment;
  bool _loadingDepartments = true;
  bool _isRegistering = false;
  bool _registerLoadingDone = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final data = await supabase
          .from('departments')
          .select('name')
          .order('name');
      setState(() {
        _departments = (data as List).map((e) => e['name'] as String).toList();
        _loadingDepartments = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to load departments. Please refresh and try again.';
        _loadingDepartments = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _employeeIdController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  ({int score, String label, Color color}) _passwordStrength(String password) {
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password))
      score++;
    if (RegExp(r'[0-9]').hasMatch(password) ||
        RegExp(r'[^a-zA-Z0-9]').hasMatch(password))
      score++;

    if (password.isEmpty) return (score: 0, label: '', color: AppColors.border);
    return switch (score) {
      0 || 1 => (score: score, label: 'Weak', color: AppColors.destructive),
      2 => (score: score, label: 'Fair', color: AppColors.gold),
      3 => (score: score, label: 'Good', color: const Color(0xFF06B6D4)),
      _ => (score: score, label: 'Strong', color: AppColors.success),
    };
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _employeeIdController.text.isEmpty ||
        _selectedDepartment == null ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'Please fill in all required fields!');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (_passwordController.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters long.');
      return;
    }

    setState(() {
      _isRegistering = true;
      _registerLoadingDone = false;
    });
    final result = await ref
        .read(authProvider.notifier)
        .register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          employeeId: _employeeIdController.text.trim(),
          department: _selectedDepartment!,
          position: _positionController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    setState(() => _registerLoadingDone = true);
    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() => _isRegistering = false);

    if (result.success) {
      showSuccessSnackBar(context, 'Registration successful! Please check your email for a verification code.');
      context.push('/verify-otp', extra: _emailController.text.trim());
    } else {
      setState(() => _error = result.error);
    }
  }

  static const _heroBullets = [
    (Icons.check_circle_outline, 'Submit departmental forms digitally'),
    (Icons.fact_check_outlined, 'Track requests and approval progress'),
    (Icons.notifications_active_outlined, 'Receive timely status updates'),
    (Icons.shield_outlined, 'Access company records securely'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mirrors RegisterPage.tsx's purple gradient hero aside — same
            // background photo as the login screen, with a brand-purple
            // gradient overlay (distinct from login's navy) and the feature
            // bullets that sell the point of creating an account.
            Stack(
              children: [
                ClipRect(
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      Image.asset(
                        'assets/images/login_bg.jpg',
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        height: 300,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xF2282063),
                              Color(0xEB40358F),
                              Color(0xE05B4DAF),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  left: -50,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Image.asset(
                            'assets/images/logo_white.png',
                            height: 64,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Welcome to HDSB\nManagement System',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (final bullet in _heroBullets)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  bullet.$1,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  size: 17,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    bullet.$2,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
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
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Your Account',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  _buildForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _labeledField('Full Name *', _nameController),
        const SizedBox(height: 14),
        _labeledField(
          'Email Address *',
          _emailController,
          keyboardType: TextInputType.emailAddress,
          icon: Icons.mail_outline,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _labeledField('Staff ID *', _employeeIdController)),
            const SizedBox(width: 12),
            Expanded(
              child: _labeledField(
                'Phone No.',
                _phoneController,
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          borderRadius: BorderRadius.circular(14),
          dropdownColor: AppColors.card,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.mutedForeground,
          ),
          initialValue: _selectedDepartment,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Department *',
            hintText: _loadingDepartments
                ? 'Loading departments…'
                : 'Select Department',
          ),
          items: _departments
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: _loadingDepartments
              ? null
              : (value) => setState(() => _selectedDepartment = value),
        ),
        const SizedBox(height: 14),
        _labeledField('Position', _positionController),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password *',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_passwordController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final strength = _passwordStrength(_passwordController.text);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Text(
                    strength.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: strength.color,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'Confirm Password *',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_confirmPasswordController.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _confirmPasswordController.text == _passwordController.text
                ? 'Passwords match'
                : 'Passwords do not match',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _confirmPasswordController.text == _passwordController.text
                  ? AppColors.success
                  : AppColors.destructive,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.destructive.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.destructive.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_rounded, color: AppColors.destructive, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppColors.destructive, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: (_isRegistering || _loadingDepartments) ? null : _submit,
          child: _isRegistering
              ? PercentLoadingIndicator(
                  completed: _registerLoadingDone,
                  size: 34,
                  color: Colors.white,
                  trackColor: Colors.white.withValues(alpha: 0.3),
                )
              : const Text('Create Account'),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Already have an account? '),
            GestureDetector(
              onTap: () => context.pop(),
              child: const Text(
                'Sign in',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _labeledField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
    );
  }
}
