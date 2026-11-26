import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../services/app_cache.dart';
import '../services/push_notification_service.dart';
import '../services/token_storage.dart';

enum AuthStatus {
  unknown,
  signedOut,
  needsUsername,
  needsPasswordSetup,
  needsOnboarding,
  authenticated,
}

class AuthProvider extends ChangeNotifier {
  static const _pendingOnboardingUserKey = 'pending_onboarding_user_id';

  final AuthService authService;
  final PushNotificationService pushNotificationService;
  final TokenStorage tokenStorage;
  // No extra scopes: requesting them forces web into the access-token OAuth
  // flow instead of the ID-token/credential flow the backend needs.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: defaultTargetPlatform == TargetPlatform.android
        ? '832786798168-jsqikmgbbp22agj3bjf6tpdjdpll5p02.apps.googleusercontent.com'
        : null,
  );

  AuthProvider({
    required this.authService,
    required this.pushNotificationService,
    required this.tokenStorage,
  }) {
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
  String? userId;
  String? displayName;
  String? avatarUrl;
  String? errorMessage;
  bool isBusy = false;
  bool _isNewUser = false;

  void clearErrorMessage() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _restore() async {
    final token = await tokenStorage.accessToken;
    final storedUsername = await tokenStorage.username;
    userId = await tokenStorage.userId;
    _isNewUser = await _hasPendingOnboarding(userId);
    username = storedUsername;
    if (token == null) {
      status = AuthStatus.signedOut;
    } else if (storedUsername == null) {
      status = AuthStatus.needsUsername;
    } else if (_isNewUser) {
      status = AuthStatus.needsOnboarding;
    } else {
      status = AuthStatus.authenticated;
    }
    if (token != null) {
      unawaited(pushNotificationService.registerCurrentToken());
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
    await _trackNewUser(session);
    unawaited(pushNotificationService.registerCurrentToken());
    displayName = session.displayName;
    avatarUrl = session.avatarUrl;
    username = session.username;
    status = session.needsUsername
        ? AuthStatus.needsUsername
        : _isNewUser
        ? AuthStatus.needsOnboarding
        : AuthStatus.authenticated;
  }

  Future<void> _trackNewUser(AuthSession session) async {
    userId = session.userId;
    if (session.isNewUser && session.userId.isNotEmpty) {
      try {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          _pendingOnboardingUserKey,
          session.userId,
        );
      } catch (_) {
        // Keep the new-user flow working if the local marker cannot be saved.
      }
    }
    _isNewUser = session.isNewUser || await _hasPendingOnboarding(userId);
  }

  Future<bool> _hasPendingOnboarding(String? id) async {
    if (id == null || id.isEmpty) return false;
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(_pendingOnboardingUserKey) == id;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearPendingOnboarding(String? id) async {
    if (id == null || id.isEmpty) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getString(_pendingOnboardingUserKey) == id) {
        await preferences.remove(_pendingOnboardingUserKey);
      }
    } catch (_) {
      // Continue even if the local marker cannot be cleared.
    }
  }

  Future<void> completeOnboarding() async {
    await _clearPendingOnboarding(userId);
    _isNewUser = false;
    status = AuthStatus.authenticated;
    notifyListeners();
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
    status = AuthStatus.needsPasswordSetup;
    notifyListeners();
  }

  Future<void> setupPassword(String password) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await authService.setupPassword(password);
        status = _isNewUser
          ? AuthStatus.needsOnboarding
          : AuthStatus.authenticated;
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await authService.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void skipPasswordSetup() {
    status = _isNewUser ? AuthStatus.needsOnboarding : AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> signInWithPassword({
    required String username,
    required String password,
  }) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final session = await authService.signInWithPassword(
        username: username,
        password: password,
      );
      await _trackNewUser(session);
      this.username = session.username ?? username;
      displayName = session.displayName;
      avatarUrl = session.avatarUrl;
      status = _isNewUser
          ? AuthStatus.needsOnboarding
          : AuthStatus.authenticated;
      unawaited(pushNotificationService.registerCurrentToken());
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await pushNotificationService.unregisterCurrentToken();
    await authService.logout();
    await AppCache.clear();
    await _googleSignIn.signOut();
    userId = null;
    username = null;
    displayName = null;
    avatarUrl = null;
    _isNewUser = false;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  /// Called by the API client when a refresh fails; forces sign-out state.
  void forceSignOut() {
    unawaited(tokenStorage.clear());
    unawaited(AppCache.clear());
    username = null;
    userId = null;
    _isNewUser = false;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final deletedUserId = userId;
    await authService.deleteAccount();
    await _clearPendingOnboarding(deletedUserId);
    await tokenStorage.clear();
    await AppCache.clear();
    try {
      await _googleSignIn.signOut();
    } catch (error) {
      debugPrint('Google sign-out after account deletion failed: $error');
    }
    username = null;
    userId = null;
    displayName = null;
    avatarUrl = null;
    _isNewUser = false;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
