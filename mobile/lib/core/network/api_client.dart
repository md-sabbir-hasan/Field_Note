import 'package:dio/dio.dart';
import 'package:field_notes/core/config/api_config.dart';
import 'token_storage.dart';

/// Called when the server says the token is no longer valid (401 on a protected call).
typedef UnauthorizedCallback = void Function();

class ApiClient {
  ApiClient(this._tokenStorage) {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Auth endpoints are public, everything else needs the Bearer token.
        if (!options.path.startsWith('/api/auth')) {
          final token = await _tokenStorage.token;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final isAuthCall = error.requestOptions.path.startsWith('/api/auth');
        if (error.response?.statusCode == 401 && !isAuthCall) {
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  final TokenStorage _tokenStorage;
  late final Dio dio;

  /// Set by the app so an expired token can send the user back to the login screen.
  UnauthorizedCallback? onUnauthorized;
}