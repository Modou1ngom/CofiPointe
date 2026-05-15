import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Initialisation FCM — à compléter avec `firebase_options.dart` (FlutterFire).
class PushNotificationService {
  PushNotificationService();

  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  Future<void> init() async {
    await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Afficher toast / local notification en production
    });
  }

  Future<String?> getFcmToken() => _fm.getToken();
}

/// Handler background — doit être une fonction top-level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
