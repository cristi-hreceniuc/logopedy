import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import 'models/login_request.dart';
import 'models/login_response.dart';
import 'models/signup_request.dart';
import 'models/user_dto.dart';

class AuthApi {
  final Dio _dio;
  AuthApi(this._dio);

  // dacă vrei să accesezi dio din repo:
  Dio get dio => _dio;

  Future<UserDto> signup(SignupRequest req) async {
    final res = await _dio.post(AppConfig.signupPath, data: req.toJson());
    return UserDto.fromJson(res.data as Map<String, dynamic>);
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
    }, options: Options(headers: {'Authorization': null}));
    return r.data as Map<String, dynamic>;
  }
}
