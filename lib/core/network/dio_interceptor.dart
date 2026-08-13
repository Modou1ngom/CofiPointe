import 'package:dio/dio.dart';

import '../../services/secure_storage_service.dart';

/// Intercepteur auth : token en mémoire pour éviter un read secure storage à chaque requête.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final SecureStorageService _storage;

  /// Cache partagé (évite dépendances circulaires providers).
  static String? sharedCachedToken;

  /// Appelé une fois sur 401 pour forcer une reconnexion (session locale périmée).
  static Future<void> Function()? onUnauthorized;

  static bool _handlingUnauthorized = false;

  static void setSharedToken(String? token) => sharedCachedToken = token;

  static void clearSharedToken() => sharedCachedToken = null;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    var token = sharedCachedToken;
    if (token == null || token.isEmpty) {
      token = await _storage.readAccessToken();
      sharedCachedToken = token;
    }
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await _notifyUnauthorized();
    }
    handler.next(err);
  }

  static Future<void> _notifyUnauthorized() async {
    if (_handlingUnauthorized) return;
    final cb = onUnauthorized;
    if (cb == null) return;
    _handlingUnauthorized = true;
    try {
      await cb();
    } finally {
      _handlingUnauthorized = false;
    }
  }
}
