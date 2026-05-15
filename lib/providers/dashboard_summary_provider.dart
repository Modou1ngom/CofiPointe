import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

/// Résumé chiffré type maquette COFINA (équipe / entreprise).
/// À brancher plus tard sur un endpoint Laravel dédié.
class DashboardSummary {
  const DashboardSummary({
    required this.presentsCount,
    required this.lateCount,
    required this.absentCount,
    required this.onLeaveCount,
  });

  final int presentsCount;
  final int lateCount;
  final int absentCount;
  final int onLeaveCount;

  static const DashboardSummary mockCofina = DashboardSummary(
    presentsCount: 198,
    lateCount: 18,
    absentCount: 7,
    onLeaveCount: 3,
  );
}

final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  final env = ref.watch(envProvider);
  if (env.useTestData) {
    return DashboardSummary.mockCofina;
  }
  // Hors mode test : pas d’endpoint encore — compteurs à 0 jusqu’à branchement API.
  return const DashboardSummary(
    presentsCount: 0,
    lateCount: 0,
    absentCount: 0,
    onLeaveCount: 0,
  );
});
