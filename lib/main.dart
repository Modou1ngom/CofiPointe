import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/network/dio_interceptor.dart';
import 'providers/app_providers.dart';
import 'services/push_notification_service.dart';
import 'services/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('fr_FR');

  final prefs = await SharedPreferences.getInstance();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    final push = PushNotificationService();
    await push.init();
  } catch (_) {
    // Firebase non configuré — ajoutez `flutterfire configure` pour activer FCM.
  }

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  await container.read(sessionControllerProvider.notifier).hydrate();

  // Jeton expiré / révoqué → déconnexion locale (sinon UI « connectée » + sync KO).
  AuthInterceptor.onUnauthorized = () async {
    await container.read(sessionControllerProvider.notifier).logout();
  };

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CofiPointeApp(),
    ),
  );
}
