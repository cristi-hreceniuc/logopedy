// lib/features/auth/data/domain/auth_repository.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logopedy/features/auth/data/models/user_dto.dart';
import 'package:logopedy/features/auth/data/models/user_response_dto.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../main.dart';
import '../auth_api.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/signup_request.dart';

class AuthRepository {
  AuthRepository(this._api, this._store);

  final AuthApi _api;
  final SecureStore _store;

  Future<bool> isSessionValid() async {
    final token = await _store.readToken();
    final exp = await _store.readAccessExp();
    if (token == null || exp == null) return false;
    final isValid = exp.isAfter(DateTime.now().toUtc().add(const Duration(seconds: 5)));
    
    // If session is valid, set up FCM token refresh callback
    if (isValid) {
      _setupFcmTokenRefreshCallback();
    }
    
    return isValid;
  }

  /// Set up FCM token refresh callback for existing sessions
  void _setupFcmTokenRefreshCallback() {
    try {
      final pushService = sl<PushNotificationService>();
      final deviceInfo = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      
      pushService.setOnTokenRefresh((newToken) async {
        await _api.registerFcmToken(newToken, deviceInfo: deviceInfo);
      });
    } catch (e) {
      debugPrint('Failed to set up FCM token refresh callback: $e');
    }
  }

  Future<LoginResponse> login(LoginRequest req) async {
    final data = await _api.login(req.email, req.password);
    // răspuns BE:
    // { token, expiresIn(ms), refreshToken, refreshExpiresIn(ms), user: {fullName, email, userRole} }
    final access = data['token'] as String;
    final accessMs = (data['expiresIn'] as num).toInt();
    final refresh = data['refreshToken'] as String;
    final refreshMs = (data['refreshExpiresIn'] as num).toInt();
    
    final loginResponse = LoginResponse.fromJson(data);

    final now = DateTime.now().toUtc();
    await _store.saveSession(
      accessToken: access,
      accessExpiresAt: now.add(Duration(milliseconds: accessMs)),
      refreshToken: refresh,
      refreshExpiresAt: now.add(Duration(milliseconds: refreshMs)),
    );
    
    // Store user role if available
    if (loginResponse.userRole != null) {
      await _store.writeKey('user_role', loginResponse.userRole!);
    }
    
    // Register FCM token for push notifications
    await _registerFcmToken();
    
    return loginResponse;
  }
  
  /// Register FCM token with backend after successful login
  Future<void> _registerFcmToken() async {
    try {
      final pushService = sl<PushNotificationService>();
      final token = pushService.fcmToken;
      final deviceInfo = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      
      if (token != null) {
        await _api.registerFcmToken(token, deviceInfo: deviceInfo);
        debugPrint('FCM token registered with backend');
      }
      
      // Set up callback for token refresh (so new tokens get re-registered)
      pushService.setOnTokenRefresh((newToken) async {
        await _api.registerFcmToken(newToken, deviceInfo: deviceInfo);
      });
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
      // Don't fail login if token registration fails
    }
  }
  
  Future<String?> getUserRole() async {
    return _store.readKey('user_role');
  }

  Future<void> logout() async {
    // Unregister FCM token before logout
    await _unregisterFcmToken();
    await _store.deleteKey('user_role');
    await _store.clear();
  }
  
  /// Unregister FCM token from backend on logout
  Future<void> _unregisterFcmToken() async {
    try {
      final pushService = sl<PushNotificationService>();
      
      // Clear the refresh callback first
      pushService.clearOnTokenRefresh();
      
      final token = pushService.fcmToken;
      if (token != null) {
        await _api.unregisterFcmToken(token);
        debugPrint('FCM token unregistered from backend');
      }
    } catch (e) {
      debugPrint('Failed to unregister FCM token: $e');
      // Don't fail logout if token unregistration fails
    }
  }

  // compatibile cu flow-ul tău existent:
  Future<UserDto> signup(SignupRequest req) => _api.signup(req);

  // === REGISTRATION WITH OTP VERIFICATION ===

  /// Step 1: Request OTP for registration
  Future<void> requestRegistrationOtp(SignupRequest req) => _api.requestRegistrationOtp(req);

  /// Step 2: Verify OTP and complete registration
  Future<UserDto> verifyRegistrationOtp({
    required String email,
    required String otp,
  }) => _api.verifyRegistrationOtp(email: email, otp: otp);

  /// Resend OTP for pending registration
  Future<void> resendRegistrationOtp(String email) => _api.resendRegistrationOtp(email);

  Future<void> forgot1(String email) async {
    await _api.forgot1(email: email);
  }

  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
    required String confirmNewPassword,
  }) async {
    _api.resetPassword(
      email: email,
      token: token,
      password: password,
      confirmNewPassword: confirmNewPassword,
    );
  }

  Future<void> deleteAccount() async {
    // Get current user ID and delete using the new endpoint
    final currentUser = await _api.getCurrentUser();
    await _api.deleteUser(currentUser.id);
    await _store.clear(); // Clear session after deletion
  }

  Future<void> deleteUser(String userId) async {
    await _api.deleteUser(userId);
  }

  Future<UserResponseDto> getCurrentUser() async {
    return _api.getCurrentUser();
  }
}
