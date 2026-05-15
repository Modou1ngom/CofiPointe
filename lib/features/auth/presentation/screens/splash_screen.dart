import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../services/session_controller.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import 'login_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const routePath = '/splash';

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await ref.read(sessionControllerProvider.notifier).hydrate();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final session = ref.read(sessionControllerProvider);
    if (!session.isAuthenticated) {
      context.go(LoginScreen.routePath);
    } else {
      context.go(DashboardScreen.routePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Image.asset(
                AppAssets.cofinaLogo,
                height: 64,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.fingerprint,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.92, 0.92)),
            const SizedBox(height: 28),
            Text(
              'Pointage sécurisé',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                  ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 6),
            Text(
              'CofiPointe',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 0.6,
                  ),
            ).animate().fadeIn(delay: 260.ms),
            const SizedBox(height: 56),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }
}
