import 'package:dio/dio.dart';

import '../../../../config/test_fixtures.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../models/auth_api_models.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio, {required this.useTestData});

  final Dio _dio;
  final bool useTestData;

  Future<LoginResponse> login(LoginRequest request) async {
    if (useTestData) {
      await TestFixtures.simulateNetworkDelay();
      return TestFixtures.loginResponse(request);
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: {
          'email': request.identifier,
          'password': request.password,
          'device_name': 'CofiPointe',
        },
      );
      final data = res.data;
      if (data == null) {
        throw Exception('Réponse vide');
      }
      return LoginResponse.fromJson(data);
    } catch (e) {
      throw mapDioException(e);
    }
  }

  Future<VerifyOtpResponse> verifyOtp(VerifyOtpRequest request) async {
    if (useTestData) {
      await TestFixtures.simulateNetworkDelay();
      return TestFixtures.verifyOtpResponse(request);
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.verifyOtp,
        data: {
          ...request.toJson(),
          'device_name': 'CofiPointe',
        },
      );
      final data = res.data;
      if (data == null) {
        throw Exception('Réponse vide');
      }
      return VerifyOtpResponse.fromJson(data);
    } catch (e) {
      throw mapDioException(e);
    }
  }

  Future<void> registerDevice(RegisterDeviceRequest request) async {
    if (useTestData) {
      await TestFixtures.simulateNetworkDelay();
      return;
    }
    try {
      await _dio.post<void>(
        ApiEndpoints.registerDevice,
        data: request.toJson(),
      );
    } catch (e) {
      throw mapDioException(e);
    }
  }

  /// Révoque le jeton Sanctum côté serveur (ignore les erreurs réseau / 401).
  Future<void> logout() async {
    if (useTestData) return;
    try {
      await _dio.post<void>(ApiEndpoints.logout);
    } catch (_) {}
  }
}
