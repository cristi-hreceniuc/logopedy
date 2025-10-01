import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';

/// Gestionează accesul la token și refresh-ul.
/// - pre-refresh dacă mai sunt <60s până la expirarea access token-ului
/// - lock (un singur refresh în paralel)
/// - curăță sesiunea dacă refresh-ul e invalid
class TokenManager {
  TokenManager(this._dio, this._store);

  final Dio _dio;
  final SecureStore _store;

  Completer<void>? _refreshing; // lock

  /// Returnează un access token valid (poate declanșa refresh).
  Future<String?> get validAccessToken async {
    final token = await _store.readToken();
    final exp = await _store.readAccessExp();
    if (token == null || exp == null) return null;

    final now = DateTime.now().toUtc();
    if (exp.isBefore(now.add(const Duration(seconds: 60)))) {
      final ok = await refresh();
      if (!ok) return null;
      return await _store.readToken();
    }
    return token;
  }

  /// Rulează /refresh și salvează noua sesiune.
  /// Dacă există deja un refresh în curs, așteaptă același future.
  Future<bool> refresh() async {
    // dacă deja se face refresh, așteaptă
    if (_refreshing != null) {
      try {
        await _refreshing!.future;
        return true;
      } catch (_) {
        return false;
      }
    }

    final c = Completer<void>();
    _refreshing = c;

    try {
      final rt = await _store.readRefreshToken();
      final rtExp = await _store.readRefreshExp();

      if (rt == null || rtExp == null || rtExp.isBefore(DateTime.now().toUtc())) {
        throw DioException(
          requestOptions: RequestOptions(path: AppConfig.refreshPath),
          message: 'refresh_expired',
        );
      }

      final resp = await _dio.post(
        AppConfig.refreshPath,
        data: {'refreshToken': rt},
        options: Options(headers: {'Authorization': null}), // fără Bearer la refresh
      );

      // răspuns: { token, expiresIn (ms), refreshToken, refreshExpiresIn (ms) }
      final data = resp.data as Map<String, dynamic>;
      final access = data['token'] as String;
      final accessMs = (data['expiresIn'] as num).toInt();
      final refreshToken = data['refreshToken'] as String;
      final refreshMs = (data['refreshExpiresIn'] as num).toInt();

      final now = DateTime.now().toUtc();
      await _store.saveSession(
        accessToken: access,
        accessExpiresAt: now.add(Duration(milliseconds: accessMs)),
        refreshToken: refreshToken,
        refreshExpiresAt: now.add(Duration(milliseconds: refreshMs)),
      );

      c.complete();
      return true;
    } catch (e) {
      c.completeError(e);
      await _store.clear(); // sesiune invalidă -> forțează login
      return false;
    } finally {
      _refreshing = null;
    }
  }

  /// Utilitar: decodează payload-ul JWT (opțional, pentru UI).
  static Map<String, dynamic>? decodeJwtPayload(String token) {
    try {
      final p = token.split('.');
      if (p.length != 3) return null;
      final norm = base64Url.normalize(p[1]);
      final jsonStr = utf8.decode(base64Url.decode(norm));
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
