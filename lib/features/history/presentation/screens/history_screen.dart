import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_date_format.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../features/attendance/data/models/attendance_models.dart';
import '../../../../features/declarations/presentation/screens/declarations_screen.dart';
import '../../../../providers/async_data_providers.dart';
import '../../../../widgets/feedback/app_skeleton.dart';
import '../../../../widgets/layout/shell_insets.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  static const routePath = '/history';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(attendanceHistoryProvider);
    final monthFmt = DateFormat('MMMM yyyy', 'fr_FR');
    final dayFmt = DateFormat('EEEE d MMMM', 'fr_FR');

    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: async.when(
        loading: () => const DashboardSkeleton(),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (records) {
          final now = DateTime.now();
          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Text(
                  monthFmt.format(now),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  scrollDirection: Axis.horizontal,
                  itemCount: daysInMonth,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final day = i + 1;
                    final selected = day == now.day;
                    return _DayChip(
                      label: '$day',
                      selected: selected,
                      onTap: () {},
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: records.isEmpty
                    ? _EmptyHistory(onRetry: () {
                        ref.invalidate(attendanceHistoryProvider);
                      })
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          shellBottomPadding(context, extra: 24),
                        ),
                        itemCount: records.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, i) {
                          final r = records[i];
                          final missingEntry = r.checkIn == null;
                          final missingExit = r.checkOut == null;
                          final canRegulate = missingEntry || missingExit;

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          dayFmt.format(r.date),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (canRegulate)
                                        _RegulateButton(
                                          onPressed: () => _openRegulation(
                                            context,
                                            r,
                                            missingEntry: missingEntry,
                                            missingExit: missingExit,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    children: [
                                      _pill(
                                        context,
                                        'Entrée',
                                        r.checkIn != null
                                            ? AppDateFormat.formatTime12h(r.checkIn!)
                                            : '--:--',
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      _pill(
                                        context,
                                        'Sortie',
                                        r.checkOut != null
                                            ? AppDateFormat.formatTime12h(r.checkOut!)
                                            : '--:--',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openRegulation(
    BuildContext context,
    AttendanceRecord r, {
    required bool missingEntry,
    required bool missingExit,
  }) {
    String? manquant;
    if (missingEntry && !missingExit) {
      manquant = 'entree';
    } else if (missingExit && !missingEntry) {
      manquant = 'sortie';
    }

    final date =
        '${r.date.year.toString().padLeft(4, '0')}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}';

    final params = <String, String>{
      'type': 'regularisation',
      'date': date,
      'mode': 'non_pointage',
    };
    if (manquant != null) {
      params['manquant'] = manquant;
    }

    context.push(
      Uri(path: DeclarationsScreen.routePath, queryParameters: params).toString(),
    );
  }

  Widget _pill(BuildContext context, String label, String time) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegulateButton extends StatelessWidget {
  const _RegulateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Text(
              'R',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? AppColors.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Aucun historique pour le moment',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Vos pointages apparaîtront ici après synchronisation.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
