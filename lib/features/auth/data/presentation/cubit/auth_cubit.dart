import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:get_it/get_it.dart';

import '../../../../../core/network/dio_client.dart';
import '../../../../../core/storage/secure_storage.dart';
import '../../domain/auth_repository.dart';
import '../../../data/models/login_request.dart';
import '../../../data/models/signup_request.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo) : super(const AuthState.unauthenticated());
  final AuthRepository _repo;

  Future<void> checkSession() async {
    emit(const AuthState.loading());
    final ok = await _repo.isSessionValid();
    emit(ok ? const AuthState.authenticated() : const AuthState.unauthenticated());
    final pid = await GetIt.I<SecureStore>().readActiveProfileId();
    GetIt.I<DioClient>().setActiveProfile(pid);
  }

  Future<void> login(String email, String password) async {
    emit(const AuthState.loading());
    try {
      await _repo.login(LoginRequest(email: email, password: password));
      emit(const AuthState.authenticated());
    } on Exception catch (e) {
      emit(AuthState.error(_niceError(e)));
    }
  }

  Future<void> signup(SignupRequest req) async {
    emit(const AuthState.loading());
    try {
      await _repo.signup(req);
      emit(const AuthState.signupSuccess());
    } on Exception catch (e) {
      emit(AuthState.error(_niceError(e)));
    }
  }

  // === RESET PAROLĂ – noul flow în 2 pași ===

  /// Pasul 1: trimite cod pe email (POST /api/v1/auth/forgot1)
  /// Necesită Bearer token – repo trebuie să pună Authorization.
  Future<void> sendResetCode(String email) async {
    emit(const AuthState.loading());
    try {
      await _repo.forgot1(email); // implementezi în AuthRepository
      emit(const AuthState.resetSent());
    } on Exception catch (e) {
      emit(AuthState.error(_niceError(e)));
    }
  }

  /// Pasul 2: resetează parola cu token (POST /api/v1/auth/reset-password)
  /// Body: { email, token, password, confirmNewPassword } + Bearer.
  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
    required String confirmNewPassword,
  }) async {
    emit(const AuthState.loading());
    try {
      await _repo.resetPassword(
        email: email,
        token: token,
        password: password,
        confirmNewPassword: confirmNewPassword,
      );
      emit(const AuthState.resetOk());
    } on Exception catch (e) {
      emit(AuthState.error(_niceError(e)));
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    emit(const AuthState.unauthenticated());
  }

  Future<void> deleteAccount() async {
    emit(const AuthState.loading());
    try {
      await _repo.deleteAccount();
      emit(const AuthState.unauthenticated());
    } on Exception catch (e) {
      emit(AuthState.error(_niceError(e)));
    }
  }

  String _niceError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final msg = (data is Map && data['message'] is String) ? data['message'] : null;
      return msg ?? e.message ?? 'Eroare de rețea';
    }
    return e.toString();
  }
}
