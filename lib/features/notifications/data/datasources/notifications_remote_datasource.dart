import 'package:dio/dio.dart';

import '../../../../config/test_fixtures.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../models/notification_model.dart';

class NotificationsRemoteDataSource {
  NotificationsRemoteDataSource(this._dio, {required this.useTestData});

  final Dio _dio;
  final bool useTestData;

  Future<List<NotificationItem>> fetchNotifications() async {
    if (useTestData) {
      await TestFixtures.simulateNetworkDelay();
      return TestFixtures.notifications();
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.notifications);
      final data = res.data;
      if (data == null) return [];
      final list = data['data'] ?? data['notifications'] ?? data['items'];
      if (list is List) {
        return list
            .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw mapDioException(e);
    }
  }
}
