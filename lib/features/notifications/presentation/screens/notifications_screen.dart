import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../providers/async_data_providers.dart';
import '../../../../widgets/feedback/app_skeleton.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const routePath = '/notifications';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsListProvider);
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: async.when(
        loading: () => ListView.builder(
          itemCount: 6,
          padding: const EdgeInsets.all(AppSpacing.md),
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppSkeleton(height: 72),
          ),
        ),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Aucune notification',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Les alertes RH et sécurité apparaîtront ici.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsListProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final n = items[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      child: Icon(
                        Icons.campaign_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(n.body),
                    trailing: Text(
                      df.format(n.createdAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
