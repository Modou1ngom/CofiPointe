import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/models/notification_model.dart';

/// Ligne de notification compacte (icône contextuelle + titre/heure + sous-titre).
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.item,
  });

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final p = item.presentation;
    final visual = _visualFor(p);
    final titleWeight = item.read ? FontWeight.w500 : FontWeight.w700;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: visual.background,
            child: Icon(
              visual.icon,
              size: 20,
              color: visual.foreground,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.shortTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: titleWeight,
                          color: AppColors.textPrimaryLight,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      p.timeLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryLight,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  p.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondaryLight,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _NotificationVisual _visualFor(NotificationPresentation p) {
    switch (p.kind) {
      case NotificationPunchKind.arrival:
        if (p.adjusted) {
          return const _NotificationVisual(
            icon: Icons.login_rounded,
            background: Color(0xFFFFF3E0),
            foreground: AppColors.warning,
          );
        }
        return const _NotificationVisual(
          icon: Icons.login_rounded,
          background: Color(0xFFE8F5E9),
          foreground: AppColors.success,
        );
      case NotificationPunchKind.departure:
        if (p.adjusted) {
          return const _NotificationVisual(
            icon: Icons.logout_rounded,
            background: Color(0xFFFFF3E0),
            foreground: AppColors.warning,
          );
        }
        return const _NotificationVisual(
          icon: Icons.logout_rounded,
          background: Color(0xFFE3F2FD),
          foreground: Color(0xFF1565C0),
        );
      case NotificationPunchKind.other:
        return const _NotificationVisual(
          icon: Icons.notifications_none_rounded,
          background: Color(0xFFF0F0F2),
          foreground: AppColors.charcoal,
        );
    }
  }
}

class _NotificationVisual {
  const _NotificationVisual({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
}
