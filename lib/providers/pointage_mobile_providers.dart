import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/attendance/data/models/pointage_mobile_models.dart';
import '../services/session_controller.dart';
import 'app_providers.dart';

/// Pointages du jour (`GET /pointage/today`), fuseau serveur.
final pointageTodayProvider =
    FutureProvider.autoDispose<PointageTodaySummary>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (!session.isAuthenticated) {
    return PointageTodaySummary.empty;
  }
  final ds = ref.watch(attendanceRemoteDataSourceProvider);
  return ds.fetchPointageToday();
});

/// Sites actifs pour pointage manuel (`GET /pointage/sites`).
final pointageSitesProvider =
    FutureProvider.autoDispose<List<PointageSiteSummary>>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (!session.isAuthenticated) {
    return const [];
  }
  final ds = ref.watch(attendanceRemoteDataSourceProvider);
  return ds.fetchPointageSites();
});
