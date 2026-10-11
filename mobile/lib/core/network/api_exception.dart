import 'package:dio/dio.dart';

/// One readable error for the UI, built from our backend's JSON error shape.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.isOffline = false});

  final String message;
  final int? statusCode;

  /// True when the request never reached the server (no internet, timeout...).
  final bool isOffline;

  factory ApiException.from(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        return ApiException(data['message'] as String,
            statusCode: error.response?.statusCode);
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return ApiException('Cannot reach the server. Check your connection.',
              isOffline: true);
        default:
          return ApiException('Request failed', statusCode: error.response?.statusCode);
      }
    }
    return ApiException('Something went wrong');
  }

  @override
  String toString() => message;
}