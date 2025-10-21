// lib/core/network/dio_client.dart
import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import '../auth/token_manager.dart';

/// Dio configurat cu:
/// - Authorization: Bearer <token>
/// - X-Profile-Id: <id profil> (dacă există)
/// - refresh automat pe 401 + retry
class DioClient {
  DioClient(this._store)
      : dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      contentType: 'application/json',
    ),
  ) {
    _tm = TokenManager(dio, _store);

    // bootstrap profil salvat (dacă există)
    _bootstrapProfileHeader();

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // rute publice: fără bearer / profil
          if (_isPublic(options.path)) {
            return handler.next(options);
          }

          // Bearer
          final token = await _tm.validAccessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Profilul activ (dacă nu a fost setat manual, citim din storage)
          final pid = _activeProfileId ?? await _store.readActiveProfileId();
          if (pid != null) {
            options.headers['X-Profile-Id'] = pid.toString();
          } else {
            options.headers.remove('X-Profile-Id');
          }

          handler.next(options);
        },
        onError: (err, handler) async {
          final is401 = err.response?.statusCode == 401;
          final alreadyRetried = err.requestOptions.extra['retried'] == true;

          if (is401 &&
              !alreadyRetried &&
              !_isRefresh(err.requestOptions.path) &&
              !_isPublic(err.requestOptions.path)) {
            final ok = await _tm.refresh();
            if (ok) {
              err.requestOptions.extra['retried'] = true;

              // reatașează Bearer
              final token = await _store.readToken();
              if (token != null) {
                err.requestOptions.headers['Authorization'] = 'Bearer $token';
              } else {
                err.requestOptions.headers.remove('Authorization');
              }

              // reatașează profilul curent
              final pid = _activeProfileId ?? await _store.readActiveProfileId();
              if (pid != null) {
                err.requestOptions.headers['X-Profile-Id'] = pid.toString();
              } else {
                err.requestOptions.headers.remove('X-Profile-Id');
              }

              final req = await _retry(err.requestOptions);
              return handler.resolve(req);
            }
          }

          handler.next(err);
        },
      ),
    );
  }

  final Dio dio;
  final SecureStore _store;
  late final TokenManager _tm;

  int? _activeProfileId; // <-- id-ul profilului curent în memorie

  /// Apelează asta imediat după ce user-ul schimbă profilul.
  void setActiveProfile(int? id) {
    _activeProfileId = id;
    if (id == null) {
      dio.options.headers.remove('X-Profile-Id');
    } else {
      dio.options.headers['X-Profile-Id'] = id.toString();
    }
  }

  Future<void> _bootstrapProfileHeader() async {
    final pid = await _store.readActiveProfileId();
    _activeProfileId = pid;
    if (pid != null) {
      dio.options.headers['X-Profile-Id'] = pid.toString();
    }
  }

  bool _isPublic(String path) {
    return path.startsWith(AppConfig.loginPath) ||
        path.startsWith(AppConfig.signupPath) ||
        path.startsWith(AppConfig.forgotPasswordPath) ||
        path.startsWith(AppConfig.resetPasswordPath) ||
        _isRefresh(path);
  }

  bool _isRefresh(String path) => path.startsWith(AppConfig.refreshPath);

  Future<Response<dynamic>> _retry(RequestOptions o) async {
    final opts = Options(
      method: o.method,
      headers: o.headers,
      contentType: o.contentType,
      responseType: o.responseType,
      followRedirects: o.followRedirects,
      receiveTimeout: o.receiveTimeout,
      sendTimeout: o.sendTimeout,
      validateStatus: o.validateStatus,
    );
    return dio.request(
      o.path,
      data: o.data,
      queryParameters: o.queryParameters,
      options: opts,
      cancelToken: o.cancelToken,
      onSendProgress: o.onSendProgress,
      onReceiveProgress: o.onReceiveProgress,
    );
  }
}
