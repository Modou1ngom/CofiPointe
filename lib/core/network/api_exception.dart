import 'package:dio/dio.dart';

import '../errors/failures.dart';

Failure mapDioException(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String msg = error.message ?? 'Erreur réseau';
    if (data is Map && data['message'] != null) {
      msg = data['message'].toString();
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkFailure('Connexion impossible. Vérifiez votre réseau.', '$status');
      case DioExceptionType.badResponse:
        if (status == 401 || status == 403) {
          return AuthFailure(msg, '$status');
        }
        return ServerFailure(msg, '$status');
      default:
        return ServerFailure(msg, '$status');
    }
  }
  return ServerFailure(error.toString());
}
