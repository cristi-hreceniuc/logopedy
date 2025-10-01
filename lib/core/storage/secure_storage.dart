// lib/core/storage/secure_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _tokenKey = 'auth_token';
  static const _expiresAtKey = 'auth_expires_at';
  static const _refreshKey = 'refresh_token';
  static const _refreshExpKey = 'refresh_expires_at';

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
}
