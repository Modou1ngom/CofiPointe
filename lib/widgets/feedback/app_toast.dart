import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

enum ToastType { info, success, error }

void showAppToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.info,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  Color bg = AppColors.primary;
  IconData icon = Icons.info_outline;
  switch (type) {
    case ToastType.success:
      bg = AppColors.success;
      icon = Icons.check_circle_outline;
      break;
    case ToastType.error:
      bg = AppColors.error;
      icon = Icons.error_outline;
      break;
    case ToastType.info:
      break;
  }

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg,
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}
