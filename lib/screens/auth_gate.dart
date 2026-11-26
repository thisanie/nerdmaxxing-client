import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'auth/password_setup_screen.dart';
import 'auth/username_setup_screen.dart';
import 'home/home_shell.dart';
import 'onboarding_screen.dart';

/// Routes to the correct top-level screen based on auth state.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _loadOnboardingState();
  }

  Future<void> _loadOnboardingState() async {
    var show = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      show = !(preferences.getBool('has_seen_onboarding_v1') ?? false);
    } catch (_) {
      // Keep onboarding available if local preferences cannot be read.
    }
    if (mounted) setState(() => _showOnboarding = show);
  }

  Future<void> _completeOnboarding() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('has_seen_onboarding_v1', true);
    } catch (_) {
      // Continue to auth even if the preference cannot be saved.
    }
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;
    if (status == AuthStatus.unknown || _showOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_showOnboarding!) {
      return OnboardingScreen(onComplete: _completeOnboarding);
    }

    switch (status) {
      case AuthStatus.unknown:
        return const SizedBox.shrink();
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.needsUsername:
        return const UsernameSetupScreen();
      case AuthStatus.needsPasswordSetup:
        return const PasswordSetupScreen();
      case AuthStatus.authenticated:
        return const HomeShell();
    }
  }
}
