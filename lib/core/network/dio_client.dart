import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import '../auth/token_manager.dart';

/// Dio configurat cu:
/// - Authorization: Bearer <token>
/// - refresh automat pe 401 + retry (o singură dată)
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

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // nu atașa Bearer pentru rutele publice
          if (_isPublic(options.path)) {
            return handler.next(options);
          }

          final token = await _tm.validAccessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
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
            // încearcă refresh
            final ok = await _tm.refresh();
            if (ok) {
              // marchează pentru a evita bucle
              err.requestOptions.extra['retried'] = true;

              // reatașează Bearer (poate s-a schimbat)
              final token = await _store.readToken();
              if (token != null) {
                err.requestOptions.headers['Authorization'] = 'Bearer $token';
              } else {
                err.requestOptions.headers.remove('Authorization');
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
