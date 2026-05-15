import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../widgets/buttons/primary_button.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';

class AttendanceSuccessArgs {
  AttendanceSuccessArgs({
    required this.recordedAt,
    required this.kind,
  });

  final DateTime recordedAt;
  final String kind;
}

class SuccessScreen extends ConsumerWidget {
  const SuccessScreen({super.key, this.args});

  static const routePath = '/success';

  final AttendanceSuccessArgs? args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeFmt = DateFormat('hh:mm a');
    final dateFmt = DateFormat('EEEE d MMMM yyyy');
    final at = args?.recordedAt ?? DateTime.now();
    final kind = args?.kind ?? 'Pointage';

    return Scaffold(
      backgroundColor: AppColors.success.withValues(alpha: 0.08),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
              ).animate().scale(curve: Curves.elasticOut),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Pointage validé !',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                timeFmt.format(at),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
              ),
              Text(
                dateFmt.format(at),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: AppColors.success),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kind,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              timeFmt.format(at),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Terminer',
                onPressed: () => context.go(DashboardScreen.routePath),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
