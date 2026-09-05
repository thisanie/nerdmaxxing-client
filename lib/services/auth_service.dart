import '../models/auth_session.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AuthService {
  final ApiClient api;
  final TokenStorage tokenStorage;

  AuthService({required this.api, required this.tokenStorage});

  Future<AuthSession> signInWithGoogle(String idToken) async {
    final data = await api.post('/auth/google', data: {'id_token': idToken}, skipAuth: true);
    final session = AuthSession.fromJson(data);
    await tokenStorage.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      userId: session.userId,
      username: session.username,
    );
    return session;
  }

  Future<void> logout() async {
    final refreshToken = await tokenStorage.refreshToken;
    if (refreshToken != null) {
      try {
        await api.post('/auth/logout', data: {'refresh_token': refreshToken}, skipAuth: true);
      } catch (_) {
        // best-effort revoke; still clear local session
      }
    }
    await tokenStorage.clear();
  }

  Future<bool> checkUsernameAvailability(String username) async {
    final data = await api.get('/users/username-availability', query: {'username': username});
    return data['available'] == true;
  }

  Future<String> setUsername(String username) async {
    final data = await api.post('/users/me/username', data: {'username': username});
    await tokenStorage.saveUsername(data['username']);
    return data['username'];
  }

  Future<String> updateUsername(String username) async {
    final data = await api.patch('/users/me/username', data: {'username': username});
    await tokenStorage.saveUsername(data['username']);
    return data['username'];
  }
}
