import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../data/models/notification_model.dart';

/// Palette écran notifications (alignée sur la maquette sombre).
abstract final class _NotifColors {
  static const background = Color(0xFF1C1C1E);
  static const surface = Color(0xFF1C1C1E);
  static const title = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF8E8E93);
  static const divider = Color(0xFF2C2C2E);

  static const arrivalBg = Color(0xFF1E3A2A);
  static const arrivalFg = Color(0xFF30D158);

  static const departureBg = Color(0xFF1A2F4A);
  static const departureFg = Color(0xFF64D2FF);

  static const adjustedBg = Color(0xFF3A2A12);
  static const adjustedFg = Color(0xFFFF9F0A);

  static const otherBg = Color(0xFF2C2C2E);
  static const otherFg = Color(0xFFAEAEB2);
}

/// Ligne de notification — maquette : icône ronde + titre/heure + sous-titre.
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

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: visual.background,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
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
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        p.shortTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              item.read ? FontWeight.w500 : FontWeight.w600,
                          color: _NotifColors.title,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      p.timeLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _NotifColors.secondary,
                        height: 1.25,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: _NotifColors.secondary,
                    height: 1.25,
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
            background: _NotifColors.adjustedBg,
            foreground: _NotifColors.adjustedFg,
          );
        }
        return const _NotificationVisual(
          icon: Icons.login_rounded,
          background: _NotifColors.arrivalBg,
          foreground: _NotifColors.arrivalFg,
        );
      case NotificationPunchKind.departure:
        if (p.adjusted) {
          return const _NotificationVisual(
            icon: Icons.logout_rounded,
            background: _NotifColors.adjustedBg,
            foreground: _NotifColors.adjustedFg,
          );
        }
        return const _NotificationVisual(
          icon: Icons.logout_rounded,
          background: _NotifColors.departureBg,
          foreground: _NotifColors.departureFg,
        );
      case NotificationPunchKind.other:
        return const _NotificationVisual(
          icon: Icons.notifications_none_rounded,
          background: _NotifColors.otherBg,
          foreground: _NotifColors.otherFg,
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

/// Couleurs exposées pour l’écran parent.
abstract final class NotificationScreenStyle {
  static const background = _NotifColors.background;
  static const surface = _NotifColors.surface;
  static const divider = _NotifColors.divider;
  static const secondary = _NotifColors.secondary;
  static const title = _NotifColors.title;

  static const systemOverlay = SystemUiOverlayStyle.light;
}
