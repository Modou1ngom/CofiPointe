import 'package:dio/dio.dart';

import '../../services/secure_storage_service.dart';

/// Intercepteur auth : token en mémoire pour éviter un read secure storage à chaque requête.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final SecureStorageService _storage;

  /// Cache partagé (évite dépendances circulaires providers).
  static String? sharedCachedToken;

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
}
