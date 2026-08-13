import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/app_date_format.dart';
import '../../../../providers/attendance_ui_provider.dart';
import '../../../../providers/dashboard_summary_provider.dart';
import '../../../../providers/pointage_mobile_providers.dart';
import '../../../../services/session_controller.dart';
import '../../../../widgets/cards/glass_card.dart';
import '../../../../widgets/layout/shell_insets.dart';
import '../../../attendance/data/models/pointage_mobile_models.dart';
import '../../../attendance/presentation/screens/qr_scanner_screen.dart';
import '../../../declarations/presentation/screens/declarations_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const routePath = '/home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final todayAsync = ref.watch(pointageTodayProvider);
    final local = ref.watch(todayAttendanceUiProvider);
    final api = todayAsync.valueOrNull;
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    // Aligne le cache local sur le serveur dès qu’il répond.
    ref.listen<AsyncValue<PointageTodaySummary>>(pointageTodayProvider, (
      previous,
      next,
    ) {
      next.whenData((summary) {
        ref.read(todayAttendanceUiProvider.notifier).syncToday(
              checkIn: summary.autoFerie ? null : summary.checkIn,
              checkOut: summary.autoFerie ? null : summary.checkOut,
            );
      });
    });

    // Dès que le serveur a répondu, ses valeurs priment (même si null).
    // Les pointages synthétiques (férié auto) ne sont plus renvoyés comme checkIn/Out.
    final checkIn = todayAsync.hasValue ? api?.checkIn : local.checkIn;
    final checkOut = todayAsync.hasValue ? api?.checkOut : local.checkOut;
    final autoFerie = api?.autoFerie == true;
    final name = session.user?.fullName ?? 'Collaborateur';
    final scheme = Theme.of(context).colorScheme;

    final hasEntry = checkIn != null;
    final hasExit = checkOut != null;
    final present = !autoFerie && (hasEntry || hasExit);

    final summary = _resolveMonthlySummary(summaryAsync, presentToday: present);

    String statusTitle;
    if (autoFerie) {
      statusTitle = api?.statusLabel?.trim().isNotEmpty == true
          ? api!.statusLabel!
          : 'Jour férié (auto)';
    } else if (hasEntry && hasExit) {
      statusTitle = 'Présent';
    } else if (hasExit && !hasEntry) {
      statusTitle = 'Sortie enregistrée';
    } else if (hasEntry) {
      statusTitle = 'Présent';
    } else {
      statusTitle = 'En attente de pointage';
    }

    String? statusDetail;
    if (autoFerie) {
      statusDetail = 'Aucun scan requis — couverture automatique';
    } else if (hasEntry && hasExit) {
      statusDetail =
          'Entrée : ${AppDateFormat.formatTime12h(checkIn)} · Sortie : ${AppDateFormat.formatTime12h(checkOut)}';
    } else if (hasExit && !hasEntry) {
      statusDetail = 'Sortie : ${AppDateFormat.formatTime12h(checkOut)}';
    } else if (hasEntry) {
      statusDetail = 'Entrée : ${AppDateFormat.formatTime12h(checkIn)}';
    }

    final scheduledIn = api?.scheduledArrival ?? '08h00';
    final scheduledOut = api?.scheduledDeparture ?? '17h00';
    final entryDisplay = checkIn == null
        ? '--:--'
        : (api?.checkInLabel ?? AppDateFormat.formatTime12h(checkIn));
    final exitDisplay = checkOut == null
        ? '--:--'
        : (api?.checkOutLabel ?? AppDateFormat.formatTime12h(checkOut));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              foregroundColor: AppColors.primary,
              child: Text(
                name.trim().isEmpty ? '?' : _dashboardInitial(name),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  Text(
                    'Tableau de bord',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () {
              ref.invalidate(pointageTodayProvider);
              ref.invalidate(dashboardSummaryProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: () => context.go(NotificationsScreen.routePath),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 380;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              shellBottomPadding(context, extra: 24),
            ),
            children: [
          GlassCard(
            child: Row(
              children: [
                Icon(
                  present ? Icons.verified_rounded : Icons.schedule_rounded,
                  color: present ? AppColors.success : AppColors.primary,
                  size: 36,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATUT AUJOURD’HUI',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              letterSpacing: 0.9,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      if (statusDetail != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          statusDetail,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),
          const SizedBox(height: AppSpacing.md),
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shadowColor: AppColors.primary.withValues(alpha: 0.45),
            child: InkWell(
              onTap: () => context.push(QrScannerScreen.routePath),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg + 4,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scanner QR Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pointez votre entrée ou votre sortie en toute sécurité.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.04),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => context.push(DeclarationsScreen.routePath),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Mes déclarations'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Résumé du mois',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (narrow)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryStat(
                        label: 'Présences',
                        value: summaryAsync.isLoading
                            ? '…'
                            : '${summary.presentsCount}',
                        accent: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _SummaryStat(
                        label: 'Retards',
                        value: summaryAsync.isLoading
                            ? '…'
                            : '${summary.lateCount}',
                        accent: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryStat(
                        label: 'Absences',
                        value: summaryAsync.isLoading
                            ? '…'
                            : '${summary.absentCount}',
                        accent: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _SummaryStat(
                        label: 'Congés',
                        value: summaryAsync.isLoading
                            ? '…'
                            : '${summary.onLeaveCount}',
                        accent: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ).animate().fadeIn(delay: 120.ms)
          else
            Row(
              children: [
                Expanded(
                  child: _SummaryStat(
                    label: 'Présences',
                    value: summaryAsync.isLoading
                        ? '…'
                        : '${summary.presentsCount}',
                    accent: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryStat(
                    label: 'Retards',
                    value:
                        summaryAsync.isLoading ? '…' : '${summary.lateCount}',
                    accent: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryStat(
                    label: 'Absences',
                    value:
                        summaryAsync.isLoading ? '…' : '${summary.absentCount}',
                    accent: AppColors.charcoal,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryStat(
                    label: 'Congés',
                    value: summaryAsync.isLoading
                        ? '…'
                        : '${summary.onLeaveCount}',
                    accent: scheme.primary,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 120.ms),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Mes horaires',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Horaires prévus',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _timeColumn(
                        context,
                        label: 'Entrée prévue',
                        value: scheduledIn,
                        accent: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      _timeColumn(
                        context,
                        label: 'Sortie prévue',
                        value: scheduledOut,
                        accent: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Pointage réel',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _timeColumn(
                        context,
                        label: 'Entrée',
                        value: entryDisplay,
                        accent: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      _timeColumn(
                        context,
                        label: 'Sortie',
                        value: exitDisplay,
                        accent: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (todayAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Pointage du jour : impossible de synchroniser (réessayez).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
              ),
            ),
            ],
          );
        },
      ),
    );
  }
  Widget _timeColumn(
    BuildContext context, {
    required String label,
    required String value,
    required Color accent,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

DashboardSummary _resolveMonthlySummary(
  AsyncValue<DashboardSummary> async, {
  required bool presentToday,
}) {
  final data = async.valueOrNull;
  if (data != null) {
    return data;
  }
  // Pas de plancher artificiel : afficher 0 tant que l’API n’a pas répondu.
  if (async.isLoading) {
    return DashboardSummary.empty;
  }
  if (presentToday) {
    return const DashboardSummary(
      presentsCount: 1,
      lateCount: 0,
      absentCount: 0,
      onLeaveCount: 0,
    );
  }
  return DashboardSummary.empty;
}

String _dashboardInitial(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  return String.fromCharCode(t.runes.first).toUpperCase();
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: accent,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.1,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
