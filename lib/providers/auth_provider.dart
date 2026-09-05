import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

enum AuthStatus { unknown, signedOut, needsUsername, authenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService authService;
  final TokenStorage tokenStorage;
  // No extra scopes: requesting them forces web into the access-token OAuth
  // flow instead of the ID-token/credential flow the backend needs.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: defaultTargetPlatform == TargetPlatform.android
        ? '832786798168-jsqikmgbbp22agj3bjf6tpdjdpll5p02.apps.googleusercontent.com'
        : null,
  );

  AuthProvider({required this.authService, required this.tokenStorage}) {
    _restore();
    if (kIsWeb) {
      // On web, sign-in only completes reliably through the rendered GIS
      // button; this stream delivers the resulting account (with idToken).
      // An onError handler is required: FedCM aborts stale silent-auth
      // requests on hot restart, and an unhandled stream error is fatal.
      _googleSignIn.onCurrentUserChanged.listen(
        _handleWebAccountChanged,
        onError: (Object error, StackTrace stack) {
          debugPrint('Google sign-in stream error (ignored): $error');
        },
      );
    }
  }

  AuthStatus status = AuthStatus.unknown;
  String? username;
  String? displayName;
  String? avatarUrl;
  String? errorMessage;
  bool isBusy = false;

  Future<void> _restore() async {
    final token = await tokenStorage.accessToken;
    final storedUsername = await tokenStorage.username;
    if (token == null) {
      status = AuthStatus.signedOut;
    } else if (storedUsername == null) {
      status = AuthStatus.needsUsername;
    } else {
      username = storedUsername;
      status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  Future<void> _handleWebAccountChanged(GoogleSignInAccount? account) async {
    if (account == null || status == AuthStatus.authenticated) return;
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception('Google sign-in did not return an ID token.');
      }
      await _completeSignIn(idToken);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _completeSignIn(String idToken) async {
    final AuthSession session = await authService.signInWithGoogle(idToken);
    displayName = session.displayName;
    avatarUrl = session.avatarUrl;
    username = session.username;
    status = session.needsUsername ? AuthStatus.needsUsername : AuthStatus.authenticated;
  }

  Future<void> signInWithGoogle() async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        // user cancelled
        isBusy = false;
        notifyListeners();
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception('Google sign-in did not return an ID token.');
      }
      await _completeSignIn(idToken);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }


  void onUsernameSet(String value) {
    username = value;
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> signOut() async {
    await authService.logout();
    await _googleSignIn.signOut();
    username = null;
    displayName = null;
    avatarUrl = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  /// Called by the API client when a refresh fails; forces sign-out state.
  void forceSignOut() {
    tokenStorage.clear();
    username = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
