import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'auth/password_setup_screen.dart';
import 'auth/username_setup_screen.dart';
import 'home/home_shell.dart';
import 'onboarding_storyboard.dart';

/// Routes to the correct top-level screen based on auth state.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final status = auth.status;
    if (status == AuthStatus.unknown) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    switch (status) {
      case AuthStatus.unknown:
        return const SizedBox.shrink();
      case AuthStatus.needsOnboarding:
        return OnboardingScreen(onComplete: auth.completeOnboarding);
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
