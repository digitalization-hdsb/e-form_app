import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/app_user.dart';

class AuthState {
  final AppUser? user;
  final bool isLoading;
  final bool isInitializing;

  const AuthState({this.user, this.isLoading = false, this.isInitializing = true});

  bool get isAuthenticated => user != null;

  AuthState copyWith({AppUser? user, bool? isLoading, bool? isInitializing, bool clearUser = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
    );
  }
}

/// Mirrors src/contexts/AuthContext.tsx: signs in via Supabase Auth, then
/// hydrates the app-level profile from the `users` table (role, department,
/// etc). Session persistence itself is handled by supabase_flutter.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session == null) {
        state = state.copyWith(clearUser: true, isInitializing: false);
        return;
      }
      await _hydrateProfile(session.user.id, fallbackEmail: session.user.email);
    });

    final currentSession = supabase.auth.currentSession;
    if (currentSession != null) {
      await _hydrateProfile(currentSession.user.id, fallbackEmail: currentSession.user.email);
    } else {
      state = state.copyWith(isInitializing: false);
    }
  }

  Future<void> _hydrateProfile(String userId, {String? fallbackEmail}) async {
    try {
      final data = await supabase.from('users').select('*').eq('id', userId).maybeSingle();
      if (data == null) {
        // No `users` row means registration was never completed via OTP
        // verification (see verifyOtp, the only place that creates this
        // row) — drop the Supabase session rather than leaving a verified
        // auth token sitting on the device for an unregistered account.
        await supabase.auth.signOut();
        state = state.copyWith(clearUser: true, isInitializing: false);
        return;
      }
      if (data['status'] == 'inactive') {
        await supabase.auth.signOut();
        state = state.copyWith(clearUser: true, isInitializing: false);
        return;
      }
      state = state.copyWith(user: AppUser.fromMap(data), isInitializing: false);
    } catch (_) {
      state = state.copyWith(isInitializing: false);
    }
  }

  Future<({bool success, String? error})> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final authResponse = await supabase.auth.signInWithPassword(email: email, password: password);
      final userId = authResponse.user?.id;
      if (userId == null) throw Exception('Sign-in did not return a user.');
      await _hydrateProfile(userId, fallbackEmail: authResponse.user?.email);
      state = state.copyWith(isLoading: false);
      return (success: true, error: null);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false);
      final isInvalid = e.message.toLowerCase().contains('invalid login credentials');
      return (
        success: false,
        error: isInvalid ? 'Email or password is incorrect. Please check your details and try again.' : e.message,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return (success: false, error: 'Unable to sign in. Please try again.');
    }
  }

  Future<({bool success, String? error})> register({
    required String name,
    required String email,
    required String employeeId,
    required String department,
    required String position,
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'name': name,
          'employeeId': employeeId,
          'department': department,
          'position': position,
          'phone': phone,
          'role': 'employee',
        },
      );
      state = state.copyWith(isLoading: false);
      return (success: true, error: null);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false);
      return (success: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return (success: false, error: 'Failed to register account.');
    }
  }

  Future<({bool success, String? error})> verifyOtp({required String email, required String token}) async {
    try {
      final response = await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
      final user = response.user;
      if (user == null) throw Exception('Could not verify the user account. Please request a new code and try again.');

      final existingProfile = await supabase.from('users').select('id').eq('id', user.id).maybeSingle();
      if (existingProfile == null) {
        final metadata = user.userMetadata ?? {};
        await supabase.from('users').insert({
          'id': user.id,
          'email': user.email,
          'name': (metadata['name'] ?? '').toString().trim(),
          'employeeId': (metadata['employeeId'] ?? '').toString().trim(),
          'department': (metadata['department'] ?? '').toString().trim(),
          'phone': (metadata['phone'] ?? '').toString().trim(),
          'position': (metadata['position'] ?? '').toString().trim(),
          'role': 'employee',
          'status': 'active',
        });
      }
      await supabase.auth.signOut();
      return (success: true, error: null);
    } on AuthException catch (e) {
      return (success: false, error: e.message);
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  Future<void> resendOtp(String email) async {
    await supabase.auth.resend(type: OtpType.signup, email: email);
  }

  Future<void> requestPasswordReset(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    final user = state.user;
    if (user == null) return false;
    try {
      final dbUpdates = Map<String, dynamic>.from(updates)..remove('role');
      if (dbUpdates.isNotEmpty) {
        await supabase.from('users').update(dbUpdates).eq('id', user.id);
      }
      await _hydrateProfile(user.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<({bool success, String? error})> changePassword(String oldPassword, String newPassword) async {
    final user = state.user;
    if (user == null) return (success: false, error: 'Not signed in.');
    try {
      await supabase.auth.signInWithPassword(email: user.email, password: oldPassword);
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      return (success: true, error: null);
    } on AuthException catch (e) {
      return (success: false, error: e.message);
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    state = state.copyWith(clearUser: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
