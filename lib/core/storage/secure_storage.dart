// lib/core/storage/secure_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _tokenKey = 'auth_token';
  static const _expiresAtKey = 'auth_expires_at';
  static const _refreshKey = 'refresh_token';
  static const _refreshExpKey = 'refresh_expires_at';
  static const _activeProfileKey = 'active_profile_id';
  static const _rememberedEmailKey = 'remembered_email';

  final _s = const FlutterSecureStorage();

  Future<void> saveSession({
    required String accessToken,
    required DateTime accessExpiresAt,
    required String refreshToken,
    required DateTime refreshExpiresAt,
  }) async {
    await _s.write(key: _tokenKey, value: accessToken);
    await _s.write(key: _expiresAtKey, value: accessExpiresAt.toIso8601String());
    await _s.write(key: _refreshKey, value: refreshToken);
    await _s.write(key: _refreshExpKey, value: refreshExpiresAt.toIso8601String());
  }

  Future<String?> readToken() => _s.read(key: _tokenKey);
  Future<String?> readRefreshToken() => _s.read(key: _refreshKey);

  Future<DateTime?> readAccessExp() async {
    final v = await _s.read(key: _expiresAtKey);
    return v == null ? null : DateTime.tryParse(v);
  }

  Future<DateTime?> readRefreshExp() async {
    final v = await _s.read(key: _refreshExpKey);
    return v == null ? null : DateTime.tryParse(v);
  }

  Future<void> clear() async {
    await _s.delete(key: _tokenKey);
    await _s.delete(key: _expiresAtKey);
    await _s.delete(key: _refreshKey);
    await _s.delete(key: _refreshExpKey);
  }

  Future<void> saveActiveProfileId(int? id) async {
    if (id == null) {
      await _s.delete(key: _activeProfileKey);
    } else {
      await _s.write(key: _activeProfileKey, value: id.toString());
    }
  }

  Future<int?> readActiveProfileId() async {
    final v = await _s.read(key: _activeProfileKey);
    if (v == null) return null;
    final n = int.tryParse(v);
    return n;
  }

  Future<void> clearActiveProfile() async =>
      _s.delete(key: _activeProfileKey);

  Future<String?> readKey(String key) => _s.read(key: key);
  Future<void> writeKey(String key, String value) => _s.write(key: key, value: value);
  Future<void> deleteKey(String key) => _s.delete(key: key);

  // Remember email functionality
  Future<void> saveRememberedEmail(String email) async {
    await _s.write(key: _rememberedEmailKey, value: email);
  }

  Future<String?> readRememberedEmail() => _s.read(key: _rememberedEmailKey);

  Future<void> clearRememberedEmail() async {
    await _s.delete(key: _rememberedEmailKey);
  }
}
