import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/attendance/data/datasources/attendance_remote_datasource.dart';
import '../features/attendance/data/models/attendance_models.dart';
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

  bool get isEmpty =>
      presentsCount == 0 &&
      lateCount == 0 &&
      absentCount == 0 &&
      onLeaveCount == 0;

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

  /// Agrège l’historique mensuel (API /attendance/history).
  factory DashboardSummary.fromHistory(
    List<AttendanceRecord> rows, {
    required DateTime month,
  }) {
    var presents = 0;
    var late = 0;
    var absents = 0;
    var conges = 0;

    for (final r in rows) {
      final status = r.status.toLowerCase();
      final hasPunch = r.checkIn != null || r.checkOut != null;

      if (hasPunch || status == 'present' || status == 'partial' || status == 'complete') {
        presents++;
        if (status.contains('late') || status.contains('retard')) {
          late++;
        }
        continue;
      }

      if (status == 'justifie' ||
          status.contains('conge') ||
          status.contains('permission') ||
          status.contains('mission') ||
          status.contains('formation')) {
        conges++;
        continue;
      }

      if (status == 'absent') {
        absents++;
      }
    }

    final m =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    return DashboardSummary(
      presentsCount: presents,
      lateCount: late,
      absentCount: absents,
      onLeaveCount: conges,
      month: m,
    );
  }
}

final dashboardSummaryProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (!session.isAuthenticated) {
    return DashboardSummary.empty;
  }

  final AttendanceRemoteDataSource ds =
      ref.watch(attendanceRemoteDataSourceProvider);

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // 1) API dédiée
  try {
    final apiSummary = await ds.fetchDashboardSummary();
    if (!apiSummary.isEmpty) {
      return apiSummary;
    }
  } catch (_) {
    // Fallback historique ci-dessous.
  }

  // 2) Fallback : historique du mois (même source que l’écran Historique)
  try {
    final history = await ds.fetchHistory(from: monthStart, to: monthEnd);
    final fromHistory = DashboardSummary.fromHistory(history, month: now);
    if (!fromHistory.isEmpty) {
      return fromHistory;
    }
  } catch (_) {
    // Dernier recours vide.
  }

  return DashboardSummary.empty;
});
