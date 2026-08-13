import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../providers/async_data_providers.dart';
import '../../../../widgets/feedback/app_skeleton.dart';
import '../../../../widgets/layout/shell_insets.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const routePath = '/notifications';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsListProvider);

    return AnnotatedRegion(
      value: NotificationScreenStyle.systemOverlay,
      child: Scaffold(
        backgroundColor: NotificationScreenStyle.background,
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: NotificationScreenStyle.background,
          foregroundColor: NotificationScreenStyle.title,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: async.when(
          loading: () => ListView.builder(
            itemCount: 6,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              child: AppSkeleton(height: 52, radius: 8),
            ),
          ),
          error: (e, _) => Center(
            child: Text(
              'Erreur : $e',
              style: const TextStyle(color: NotificationScreenStyle.secondary),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 56,
                        color: NotificationScreenStyle.secondary,
                      ),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'Aucune notification',
                        style: TextStyle(
                          color: NotificationScreenStyle.title,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'Les alertes RH et sécurité apparaîtront ici.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: NotificationScreenStyle.secondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: NotificationScreenStyle.surface,
              onRefresh: () async {
                ref.invalidate(notificationsListProvider);
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: shellBottomPadding(context, extra: 24),
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: AppSpacing.md + 38 + 12,
                  endIndent: AppSpacing.md,
                  color: NotificationScreenStyle.divider,
                ),
                itemBuilder: (_, i) => NotificationTile(item: items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}
