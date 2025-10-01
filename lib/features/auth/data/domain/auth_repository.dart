// lib/features/auth/data/domain/auth_repository.dart
import 'package:dio/dio.dart';
import '../../../../core/storage/secure_storage.dart';
import '../auth_api.dart';
import '../models/login_request.dart';
import '../models/signup_request.dart';

class AuthRepository {
  AuthRepository(this._api, this._store);
  final AuthApi _api;
  final SecureStore _store;

  Future<bool> isSessionValid() async {
    final token = await _store.readToken();
    final exp = await _store.readAccessExp();
    if (token == null || exp == null) return false;
    return exp.isAfter(DateTime.now().toUtc().add(const Duration(seconds: 5)));
  }

  Future<void> login(LoginRequest req) async {
    final data = await _api.login(req.email, req.password);
    // răspuns BE:
    // { token, expiresIn(ms), refreshToken, refreshExpiresIn(ms), user: {...} (opțional) }
    final access = data['token'] as String;
    final accessMs = (data['expiresIn'] as num).toInt();
    final refresh = data['refreshToken'] as String;
    final refreshMs = (data['refreshExpiresIn'] as num).toInt();

    final now = DateTime.now().toUtc();
    await _store.saveSession(
      accessToken: access,
      accessExpiresAt: now.add(Duration(milliseconds: accessMs)),
      refreshToken: refresh,
      refreshExpiresAt: now.add(Duration(milliseconds: refreshMs)),
    );
  }

  Future<void> logout() async => _store.clear();

  // compatibile cu flow-ul tău existent:
  Future<void> signup(SignupRequest req) => Future.error(UnsupportedError('Implement signup on server'));
  Future<void> forgot1(String email) => Future.error(UnsupportedError('Implement forgot1 on server'));
  Future<void> resetPassword({required String email, required String token, required String password, required String confirmNewPassword}) =>
      Future.error(UnsupportedError('Implement reset on server'));
}
