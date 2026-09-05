import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Web requires the GIS-rendered button; sign-in completion is observed via
/// `GoogleSignIn.onCurrentUserChanged`, not this widget's callbacks.
Widget buildGoogleAuthButton({required bool isBusy, required VoidCallback onPressed}) {
  return Center(child: web.renderButton());
}
