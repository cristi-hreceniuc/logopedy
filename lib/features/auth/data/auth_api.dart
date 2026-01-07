import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import 'models/signup_request.dart';
import 'models/user_dto.dart';
import 'models/user_response_dto.dart';

class AuthApi {
  final Dio _dio;
  AuthApi(this._dio);

  // dacă vrei să accesezi dio din repo:
  Dio get dio => _dio;

  Future<UserDto> signup(SignupRequest req) async {
    final res = await _dio.post(AppConfig.signupPath, data: req.toJson());
    return UserDto.fromJson(res.data as Map<String, dynamic>);
  }

  /// Step 1: Request OTP for registration
  Future<void> requestRegistrationOtp(SignupRequest req) async {
    await _dio.post(AppConfig.registerRequestOtpPath, data: req.toJson());
  }

  /// Step 2: Verify OTP and complete registration
  Future<UserDto> verifyRegistrationOtp({
    required String email,
    required String otp,
  }) async {
    final res = await _dio.post(AppConfig.registerVerifyOtpPath, data: {
      'email': email,
      'otp': otp,
    });
    return UserDto.fromJson(res.data as Map<String, dynamic>);
  }

  /// Resend OTP for pending registration
  Future<void> resendRegistrationOtp(String email) async {
    await _dio.post(AppConfig.registerResendOtpPath, data: {
      'email': email,
    });
  }

  Future<void> forgot1({
    required String email,
  }) async {
    await _dio.post(
      AppConfig.forgotPasswordPath,
      data: {'email': email},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
    required String confirmNewPassword,
  }) async {
    await _dio.post(
      AppConfig.resetPasswordPath,
      data: {
        'email': email,
        'password': password,
        'confirmPassword': confirmNewPassword,
        'otp': token
      },
    );
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await _dio.post(AppConfig.loginPath, data: {
      'email': email,
      'password': password,
      'platform': 'MOBILE',
    }, options: Options(headers: {'Authorization': null}));
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteUser(String userId) async {
    await _dio.delete(AppConfig.deleteUserPath(userId));
  }

  /// Step 1: Request OTP for account deletion
  Future<void> requestDeleteAccountOtp(String email) async {
    await _dio.post(AppConfig.deleteAccountRequestOtpPath, data: {
      'email': email,
    });
  }

  /// Step 2: Verify OTP and delete account
  Future<void> confirmDeleteAccount({
    required String email,
    required String otp,
  }) async {
    await _dio.post(AppConfig.deleteAccountConfirmPath, data: {
      'email': email,
      'otp': otp,
    });
  }

  Future<UserResponseDto> getCurrentUser() async {
    final res = await _dio.get('/api/v1/users/me');
    return UserResponseDto.fromJson(res.data as Map<String, dynamic>);
  }

  /// Register FCM token with backend for push notifications
  Future<void> registerFcmToken(String token, {String? deviceInfo}) async {
    await _dio.post(AppConfig.registerFcmTokenPath, data: {
      'fcmToken': token,
      'deviceInfo': deviceInfo,
    });
  }

  /// Unregister FCM token (call on logout)
  Future<void> unregisterFcmToken(String token) async {
    await _dio.delete(AppConfig.unregisterFcmTokenPath, data: {
      'fcmToken': token,
    });
  }
}
