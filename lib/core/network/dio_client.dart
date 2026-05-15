import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/env.dart';
import '../../services/secure_storage_service.dart';
import 'api_exception.dart';
import 'dio_interceptor.dart';

/// Client HTTP unique — TLS géré par la plateforme ; pinning possible en prod.
class DioClient {
  DioClient({
    required EnvConfig env,
    required SecureStorageService secureStorage,
  })  : _env = env,
        _secureStorage = secureStorage;

  final EnvConfig _env;
  final SecureStorageService _secureStorage;

  Dio build() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(_secureStorage),
      LogInterceptor(
        requestBody: kDebugMode,
        responseBody: kDebugMode,
        error: kDebugMode,
      ),
    ]);

    return dio;
  }
}
