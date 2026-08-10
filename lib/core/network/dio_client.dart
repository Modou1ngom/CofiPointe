import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/env.dart';
import '../../services/secure_storage_service.dart';
import 'dio_interceptor.dart';

/// Client HTTP unique — timeouts serrés + auth token en cache mémoire.
class DioClient {
  DioClient({
    required EnvConfig env,
    required SecureStorageService secureStorage,
  })  : _env = env,
        _secureStorage = secureStorage;

  final EnvConfig _env;
  final SecureStorageService _secureStorage;
  AuthInterceptor? _authInterceptor;

  AuthInterceptor? get authInterceptor => _authInterceptor;

  Dio build() {
    _authInterceptor = AuthInterceptor(_secureStorage);
    final dio = Dio(
      BaseOptions(
        baseUrl: _env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 20),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );

    dio.interceptors.addAll([
      _authInterceptor!,
      if (kDebugMode)
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
        ),
    ]);

    return dio;
  }
}
