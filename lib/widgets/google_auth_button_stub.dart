import 'package:flutter/material.dart';

/// Non-web fallback: a normal button that triggers the imperative sign-in flow.
Widget buildGoogleAuthButton({required bool isBusy, required VoidCallback onPressed}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: isBusy ? null : onPressed,
      icon: isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.login),
      label: Text(isBusy ? 'Signing in...' : 'Continue with Google'),
    ),
  );
}
