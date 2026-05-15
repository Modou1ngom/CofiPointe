import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = AppSpacing.radiusSm,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.surfaceDark : AppColors.outlineLight;
    final highlight =
        isDark ? AppColors.outlineDark : AppColors.surfaceLight;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          AppSkeleton(height: 28, width: 180),
          SizedBox(height: AppSpacing.lg),
          AppSkeleton(height: 120),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 180),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 96),
        ],
      ),
    );
  }
}
