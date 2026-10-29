import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Non-web fallback: a normal button that triggers the imperative sign-in flow.
Widget buildGoogleAuthButton({
  required bool isBusy,
  required VoidCallback onPressed,
  String label = 'Continue with Google',
}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: isBusy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      icon: isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.login_rounded),
      label: Text(isBusy ? 'Signing in...' : label),
    ),
  );
}
