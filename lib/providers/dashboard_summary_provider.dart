import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/attendance/data/datasources/attendance_remote_datasource.dart';
import '../services/session_controller.dart';
import 'app_providers.dart';

/// Compteurs mensuels (présences / retards / absences / congés).
/// S’incrémentent chaque jour ouvrable et repartent à 0 au 1er du mois.
class DashboardSummary {
  const DashboardSummary({
    required this.presentsCount,
    required this.lateCount,
    required this.absentCount,
    required this.onLeaveCount,
    this.month,
  });

  final int presentsCount;
  final int lateCount;
  final int absentCount;
  final int onLeaveCount;
  final String? month;

  static const DashboardSummary mockCofina = DashboardSummary(
    presentsCount: 198,
    lateCount: 18,
    absentCount: 7,
    onLeaveCount: 3,
    month: '2026-08',
  );

  static const DashboardSummary empty = DashboardSummary(
    presentsCount: 0,
    lateCount: 0,
    absentCount: 0,
    onLeaveCount: 0,
  );
}

final dashboardSummaryProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (!session.isAuthenticated) {
    return DashboardSummary.empty;
  }
  final AttendanceRemoteDataSource ds =
      ref.watch(attendanceRemoteDataSourceProvider);
  return ds.fetchDashboardSummary();
});
