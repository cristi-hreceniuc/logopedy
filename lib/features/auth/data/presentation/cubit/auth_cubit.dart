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
    } on DioException catch (e) {
      final errorMsg = _niceError(e);
      emit(AuthState.error(errorMsg));
    } on Exception catch (e) {
      final errorMsg = _niceError(e);
      emit(AuthState.error(errorMsg));
    } catch (e) {
      // Catch any other errors (including Errors that aren't Exceptions)
      final errorMsg = _niceError(e);
      emit(AuthState.error(errorMsg));
    }
  }

  Future<void> signup(SignupRequest req) async {
    emit(const AuthState.loading());
    try {
      await _repo.signup(req);
      emit(const AuthState.signupSuccess());
    } on DioException catch (e) {
      emit(AuthState.error(_niceError(e)));
    } on Exception catch (e) {
      emit(AuthState.error(_niceError(e)));
    } catch (e) {
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
    } on DioException catch (e) {
      emit(AuthState.error(_niceError(e)));
    } on Exception catch (e) {
      emit(AuthState.error(_niceError(e)));
    } catch (e) {
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
    } on DioException catch (e) {
      emit(AuthState.error(_niceError(e)));
    } on Exception catch (e) {
      emit(AuthState.error(_niceError(e)));
    } catch (e) {
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
    } on DioException catch (e) {
      emit(AuthState.error(_niceError(e)));
    } on Exception catch (e) {
      emit(AuthState.error(_niceError(e)));
    } catch (e) {
      emit(AuthState.error(_niceError(e)));
    }
  }

  String _niceError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      final statusCode = e.response?.statusCode;
      
      // Try multiple possible error message formats from backend
      String? errorMessage;
      
      // Prioritize JSON/Map data for error messages
      if (data is Map<String, dynamic>) {
        // Try common error message fields (including detail and title for RFC 7807 format)
        errorMessage = data['detail'] as String? ??
                      data['title'] as String? ??
                      data['message'] as String? ??
                      data['error'] as String? ??
                      data['errorMessage'] as String? ??
                      data['msg'] as String?;
        
        // If still no message, try errors array/object
        if (errorMessage == null && data['errors'] != null) {
          if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
            errorMessage = (data['errors'] as List).first.toString();
          } else if (data['errors'] is Map) {
            final errorsMap = data['errors'] as Map;
            // Get first error value
            if (errorsMap.isNotEmpty) {
              final firstError = errorsMap.values.first;
              if (firstError is List && firstError.isNotEmpty) {
                errorMessage = firstError.first.toString();
              } else {
                errorMessage = firstError.toString();
              }
            }
          }
        }
      } else if (data is String) {
        // Handle string response data, but avoid raw HTML pages
        final trimmedData = data.trim();
        final lowerCaseData = trimmedData.toLowerCase();
        
        // Check if it's HTML (server error pages)
        if (lowerCaseData.startsWith('<html') || 
            lowerCaseData.startsWith('<!doctype html>') ||
            lowerCaseData.contains('<head>') ||
            lowerCaseData.contains('<body>')) {
          // This is an HTML error page, don't use it as error message
          errorMessage = null;
        } else if (trimmedData.isNotEmpty) {
          // Only use non-HTML string responses
          errorMessage = trimmedData;
        }
      }
      
      // Translate common English error messages to Romanian
      if (errorMessage != null && errorMessage.isNotEmpty) {
        return _translateErrorMessage(errorMessage);
      }
      
      // Handle specific HTTP status codes with user-friendly messages
      if (statusCode != null) {
        switch (statusCode) {
          case 400:
            // 400 Bad Request - often used for wrong credentials
            return errorMessage != null 
                ? _translateErrorMessage(errorMessage!)
                : 'Email sau parolă incorectă. Te rog verifică credențialele și încearcă din nou.';
          case 401:
            // 401 Unauthorized - wrong credentials
            return errorMessage != null 
                ? _translateErrorMessage(errorMessage!)
                : 'Email sau parolă incorectă. Te rog verifică credențialele și încearcă din nou.';
          case 403:
            return errorMessage != null 
                ? _translateErrorMessage(errorMessage!)
                : 'Acces interzis. Te rog verifică permisiunile tale.';
          case 404:
            return errorMessage != null 
                ? _translateErrorMessage(errorMessage!)
                : 'Resursa nu a fost găsită.';
          case 422:
            return errorMessage != null 
                ? _translateErrorMessage(errorMessage!)
                : 'Date invalide. Te rog verifică informațiile introduse.';
          case 429:
            return errorMessage != null 
                ? _translateErrorMessage(errorMessage!)
                : 'Prea multe încercări. Te rog așteaptă un moment înainte de a încerca din nou.';
          case 500:
            return 'Ceva nu a mers bine. Te rog încearcă din nou mai târziu.';
          case 502:
          case 503:
          case 504:
            return 'Serverul nu răspunde momentan. Te rog încearcă din nou mai târziu.';
          default:
            // For unknown status codes, use default error message
            return 'Ceva nu a mers bine. Te rog încearcă din nou.';
        }
      }
      
      // Check for network/connection errors (no response from server)
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'Timpul de așteptare a expirat. Te rog verifică conexiunea la internet și încearcă din nou.';
      }
      
      if (e.type == DioExceptionType.connectionError ||
          e.response == null) {
        return 'Nu s-a putut conecta la server. Te rog verifică conexiunea la internet și încearcă din nou.';
      }
      
      // If we have an error message but no status code, translate and return it
      if (errorMessage != null && errorMessage.isNotEmpty) {
        return _translateErrorMessage(errorMessage);
      }
      
      // Default fallback for any other error
      return 'Ceva nu a mers bine. Te rog încearcă din nou.';
    }
    
    // For non-DioException errors, return string representation
    if (e is Exception || e is Error) {
      return _translateErrorMessage(e.toString());
    }
    return 'Eroare necunoscută. Te rog încearcă din nou.';
  }

  /// Translates common English error messages to Romanian
  String _translateErrorMessage(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Common authentication errors
    if (lowerMessage.contains('bad credentials') || 
        lowerMessage.contains('wrong credentials') ||
        lowerMessage.contains('invalid credentials') ||
        lowerMessage.contains('incorrect credentials')) {
      return 'Email sau parolă incorectă. Te rog verifică credențialele și încearcă din nou.';
    }
    
    if (lowerMessage.contains('user not found') || 
        lowerMessage.contains('email not found') ||
        lowerMessage.contains('account not found')) {
      return 'Email-ul nu a fost găsit. Te rog verifică adresa de email.';
    }
    
    if (lowerMessage.contains('email already registered') ||
        lowerMessage.contains('email already exists') ||
        lowerMessage.contains('user already exists') ||
        lowerMessage.contains('email is already registered') ||
        lowerMessage.contains('email is already in use') ||
        (lowerMessage.contains('email') && lowerMessage.contains('already'))) {
      return 'Acest email este deja înregistrat. Te rog folosește alt email sau conectează-te.';
    }
    
    if (lowerMessage.contains('password') && lowerMessage.contains('incorrect')) {
      return 'Parolă incorectă. Te rog verifică parola și încearcă din nou.';
    }
    
    if (lowerMessage.contains('email') && lowerMessage.contains('incorrect')) {
      return 'Email incorect. Te rog verifică adresa de email.';
    }
    
    if (lowerMessage.contains('unauthorized') || lowerMessage.contains('not authorized')) {
      return 'Nu ai permisiunea de a accesa această resursă.';
    }
    
    if (lowerMessage.contains('forbidden') || lowerMessage.contains('access denied')) {
      return 'Acces interzis. Te rog verifică permisiunile tale.';
    }
    
    if (lowerMessage.contains('not found') || lowerMessage.contains('404')) {
      return 'Resursa nu a fost găsită.';
    }
    
    if (lowerMessage.contains('validation') || lowerMessage.contains('invalid data')) {
      return 'Date invalide. Te rog verifică informațiile introduse.';
    }
    
    if (lowerMessage.contains('too many requests') || lowerMessage.contains('rate limit')) {
      return 'Prea multe încercări. Te rog așteaptă un moment înainte de a încerca din nou.';
    }
    
    if (lowerMessage.contains('server error') || 
        lowerMessage.contains('internal server error') ||
        lowerMessage.contains('500')) {
      return 'Eroare de server. Te rog încearcă mai târziu.';
    }
    
    if (lowerMessage.contains('network') || 
        lowerMessage.contains('connection') ||
        lowerMessage.contains('timeout')) {
      return 'Eroare de conexiune. Te rog verifică conexiunea la internet și încearcă din nou.';
    }
    
    // If the message is already in Romanian or doesn't match common patterns, return as is
    // but make sure it's user-friendly
    return message;
  }
}

