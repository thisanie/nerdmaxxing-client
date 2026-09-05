import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists access/refresh tokens securely on-device.
///
/// Web uses SharedPreferences (localStorage): flutter_secure_storage's web
/// backend relies on IndexedDB + WebCrypto, which can hang indefinitely on
/// read/write after a hot-restart or reload, silently blocking every
/// authenticated request.
class TokenStorage {
  static const _accessKey = 'nm_access_token';
  static const _refreshKey = 'nm_refresh_token';
  static const _userIdKey = 'nm_user_id';
  static const _usernameKey = 'nm_username';

  final _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _webPrefs async => _prefs ??= await SharedPreferences.getInstance();

  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      await (await _webPrefs).setString(key, value);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  Future<String?> _read(String key) async {
    if (kIsWeb) {
      return (await _webPrefs).getString(key);
    }
    return _secureStorage.read(key: key);
  }

  Future<void> _delete(String key) async {
    if (kIsWeb) {
      await (await _webPrefs).remove(key);
    } else {
      await _secureStorage.delete(key: key);
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
    String? username,
  }) async {
    await Future.wait([
      _write(_accessKey, accessToken),
      _write(_refreshKey, refreshToken),
      _write(_userIdKey, userId),
      if (username != null) _write(_usernameKey, username),
    ]);
  }

  Future<void> saveUsername(String username) => _write(_usernameKey, username);

  Future<String?> get accessToken => _read(_accessKey);
  Future<String?> get refreshToken => _read(_refreshKey);
  Future<String?> get userId => _read(_userIdKey);
  Future<String?> get username => _read(_usernameKey);

  Future<void> clear() async {
    await Future.wait([
      _delete(_accessKey),
      _delete(_refreshKey),
      _delete(_userIdKey),
      _delete(_usernameKey),
    ]);
  }
}
