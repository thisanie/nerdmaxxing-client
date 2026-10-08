import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores the last successful API snapshots so screens can render immediately
/// while the next request refreshes them.
class AppCache {
  static const _prefix = 'nm_cache_';
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _preferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  static Future<void> write(String key, Object value) async {
    await (await _preferences).setString(
      '$_prefix$key',
      jsonEncode(value),
    );
  }

  static Future<dynamic> read(String key) async {
    final encoded = (await _preferences).getString('$_prefix$key');
    if (encoded == null) return null;
    try {
      return jsonDecode(encoded);
    } on FormatException {
      return null;
    }
  }

  static Future<void> clear() async {
    final preferences = await _preferences;
    for (final key in preferences.getKeys().where(
      (key) => key.startsWith(_prefix),
    )) {
      await preferences.remove(key);
    }
  }
}
