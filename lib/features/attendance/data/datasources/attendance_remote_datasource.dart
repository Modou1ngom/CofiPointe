import 'package:dio/dio.dart';

import '../../../../config/test_fixtures.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../models/attendance_models.dart';
import '../models/pointage_mobile_models.dart';

class AttendanceRemoteDataSource {
  AttendanceRemoteDataSource(this._dio, {required this.useTestData});

  final Dio _dio;
  final bool useTestData;

  Future<AttendanceSubmitResponse> checkIn(AttendanceSubmitRequest body) =>
      _submit(ApiEndpoints.checkIn, body);

  Future<AttendanceSubmitResponse> checkOut(AttendanceSubmitRequest body) =>
      _submit(ApiEndpoints.checkOut, body);

  Future<AttendanceSubmitResponse> _submit(
    String path,
    AttendanceSubmitRequest body,
  ) async {
    if (useTestData) {
      await TestFixtures.simulateNetworkDelay();
      return TestFixtures.attendanceSubmit(body);
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        path,
        data: body.toJson(),
      );
      final data = res.data;
      if (data == null) {
        throw Exception('Réponse vide');
      }
      return AttendanceSubmitResponse.fromJson(data);
    } catch (e) {
      throw mapDioException(e);
    }
  }

  Future<List<AttendanceRecord>> fetchHistory({
    DateTime? from,
    DateTime? to,
  }) async {
    if (useTestData) {
      await TestFixtures.simulateNetworkDelay();
      return TestFixtures.attendanceHistory();
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.attendanceHistory,
        queryParameters: {
          if (from != null) 'from': from.toIso8601String(),
          if (to != null) 'to': to.toIso8601String(),
        },
      );
      final data = res.data;
      if (data == null) return [];
      final list = data['data'] ?? data['records'] ?? data['items'];
      if (list is List) {
        return list
            .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw mapDioException(e);
    }
  }

  Future<PointageTodaySummary> fetchPointageToday() async {
    if (useTestData) {
      await TestFixtures.simulateNetworkDelay();
      return TestFixtures.pointageTodaySummary();
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.pointageToday);
      final data = res.data;
      if (data == null) return PointageTodaySummary.empty;
      final list = data['data'];
      if (list is! List) return PointageTodaySummary.empty;
      return PointageTodaySummary.fromTodayApiList(list);
    } catch (e) {
      throw mapDioException(e);
    }
  }

  Future<List<PointageSiteSummary>> fetchPointageSites() async {
    if (useTestData) {
      await TestFixtures.simulateNetworkDelay();
      return TestFixtures.pointageSites();
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.pointageSites);
      final data = res.data;
      if (data == null) return [];
      final list = data['data'];
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => PointageSiteSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw mapDioException(e);
    }
  }
}
