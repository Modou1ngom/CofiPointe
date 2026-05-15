import 'package:dio/dio.dart';

import '../../../../config/test_fixtures.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/data/models/user_model.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._dio, {required this.useTestData});

  final Dio _dio;
  final bool useTestData;

  Future<UserModel> fetchProfile() async {
    if (useTestData) {
      await TestFixtures.simulateNetworkDelay();
      return TestFixtures.profileUser();
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.profile);
      final data = res.data;
      if (data == null) {
        throw Exception('Réponse vide');
      }
      final userRaw = data['user'] ?? data['data'] ?? data;
      if (userRaw is Map<String, dynamic>) {
        return UserModel.fromJson(userRaw);
      }
      throw Exception('Format profil invalide');
    } catch (e) {
      throw mapDioException(e);
    }
  }
}
