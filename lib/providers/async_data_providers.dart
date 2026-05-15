import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/attendance/data/models/attendance_models.dart';
import '../features/auth/data/models/user_model.dart';
import '../features/notifications/data/models/notification_model.dart';
import 'app_providers.dart';

final attendanceHistoryProvider =
    FutureProvider.autoDispose<List<AttendanceRecord>>((ref) async {
  final ds = ref.watch(attendanceRemoteDataSourceProvider);
  return ds.fetchHistory();
});

final notificationsListProvider =
    FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  final ds = ref.watch(notificationsRemoteDataSourceProvider);
  return ds.fetchNotifications();
});

final profileUserProvider =
    FutureProvider.autoDispose<UserModel>((ref) async {
  final ds = ref.watch(profileRemoteDataSourceProvider);
  return ds.fetchProfile();
});
