import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';

/// Breakpoints simples — Material 3 compact / medium / expanded.
enum LayoutBreakpoint { compact, medium, expanded }

LayoutBreakpoint breakpointOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 600) return LayoutBreakpoint.compact;
  if (w < 840) return LayoutBreakpoint.medium;
  return LayoutBreakpoint.expanded;
}

double horizontalPadding(BuildContext context) {
  switch (breakpointOf(context)) {
    case LayoutBreakpoint.compact:
      return AppSpacing.md;
    case LayoutBreakpoint.medium:
      return AppSpacing.lg;
    case LayoutBreakpoint.expanded:
      return AppSpacing.xl;
  }
}

double readableMaxWidth(BuildContext context) {
  switch (breakpointOf(context)) {
    case LayoutBreakpoint.compact:
      return double.infinity;
    case LayoutBreakpoint.medium:
      return 720;
    case LayoutBreakpoint.expanded:
      return 960;
  }
}
