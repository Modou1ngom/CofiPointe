import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/attendance/presentation/screens/biometric_validate_screen.dart';
import '../features/attendance/presentation/screens/matricule_validate_screen.dart';
import '../features/attendance/presentation/screens/qr_scanner_screen.dart';
import '../features/attendance/presentation/screens/success_screen.dart';
import '../features/declarations/presentation/screens/declarations_screen.dart';
import '../features/auth/presentation/screens/biometric_activation_screen.dart';
import '../features/auth/presentation/screens/device_registration_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/history/presentation/screens/history_screen.dart';
import '../services/session_controller.dart';
import '../widgets/layout/main_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(sessionControllerProvider, (_, __) {
    refresh.value++;
  });

  return GoRouter(
    navigatorKey: _rootKey,
    refreshListenable: refresh,
    initialLocation: SplashScreen.routePath,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final path = state.uri.path;
      final loggedIn = session.isAuthenticated;

      bool isPublic(String p) =>
          p == SplashScreen.routePath ||
          p == LoginScreen.routePath ||
          p == OtpScreen.routePath;

      if (!loggedIn && !isPublic(path)) {
        return LoginScreen.routePath;
      }

      if (loggedIn) {
        final onboardingComplete = session.deviceRegistered &&
            session.biometricOnboardingDone;

        if (!session.deviceRegistered &&
            path != DeviceRegistrationScreen.routePath) {
          return DeviceRegistrationScreen.routePath;
        }

        if (session.deviceRegistered &&
            !session.biometricOnboardingDone &&
            path != BiometricActivationScreen.routePath) {
          return BiometricActivationScreen.routePath;
        }

        if (onboardingComplete &&
            (path == LoginScreen.routePath ||
                path == SplashScreen.routePath ||
                path == OtpScreen.routePath)) {
          return DashboardScreen.routePath;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: SplashScreen.routePath,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: LoginScreen.routePath,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: OtpScreen.routePath,
        builder: (_, __) => const OtpScreen(),
      ),
      GoRoute(
        path: DeviceRegistrationScreen.routePath,
        builder: (_, __) => const DeviceRegistrationScreen(),
      ),
      GoRoute(
        path: BiometricActivationScreen.routePath,
        builder: (_, __) => const BiometricActivationScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: DashboardScreen.routePath,
                builder: (_, __) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: HistoryScreen.routePath,
                builder: (_, __) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: NotificationsScreen.routePath,
                builder: (_, __) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ProfileScreen.routePath,
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: QrScannerScreen.routePath,
        builder: (_, __) => const QrScannerScreen(),
      ),
      GoRoute(
        path: BiometricValidateScreen.routePath,
        builder: (_, __) => const BiometricValidateScreen(),
      ),
      GoRoute(
        path: MatriculeValidateScreen.routePath,
        builder: (_, __) => const MatriculeValidateScreen(),
      ),
      GoRoute(
        path: DeclarationsScreen.routePath,
        builder: (_, __) => const DeclarationsScreen(),
      ),
      GoRoute(
        path: SuccessScreen.routePath,
        builder: (context, state) {
          final extra = state.extra as AttendanceSuccessArgs?;
          return SuccessScreen(args: extra);
        },
      ),
    ],
  );
});
