import 'package:flutter/foundation.dart';

/// Configuration environnement — remplacer par `--dart-define` en CI/CD.
class EnvConfig {
  const EnvConfig({
    required this.apiBaseUrl,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.allowedRadiusMeters,
    required this.useTestData,
  });

  /// URL de base API admin (HTTPS obligatoire en prod).
  final String apiBaseUrl;
  final bool useTestData;

  /// Zone GPS autorisée — centre (ex: siège).
  final double officeLatitude;
  final double officeLongitude;
  final double allowedRadiusMeters;

  static EnvConfig fromEnvironment() {
    const envBase = String.fromEnvironment('API_BASE_URL');
    final base = envBase.isNotEmpty
        ? envBase
        : (kDebugMode
            ? (kIsWeb
                // Web : le navigateur impose le CORS ; l’API doit autoriser
                // l’origine du serveur de dev Flutter (ex. http://localhost:xxxxx).
                ? 'http://localhost:8000/api/mobile'
                : 'http://127.0.0.1:8000/api/mobile')
            : 'https://api.example.com');
    const lat = String.fromEnvironment('OFFICE_LAT', defaultValue: '14.7167');
    const lng = String.fromEnvironment('OFFICE_LNG', defaultValue: '-17.4677');
    const radius = String.fromEnvironment(
      'ALLOWED_RADIUS_M',
      defaultValue: '150',
    );
    const useTestDataEnv = String.fromEnvironment('USE_TEST_DATA');
    // Par défaut : vraies API. Données fictives uniquement avec
    // `--dart-define=USE_TEST_DATA=true`.
    final useTestData =
        useTestDataEnv.isNotEmpty && useTestDataEnv.toLowerCase() == 'true';
    return EnvConfig(
      apiBaseUrl: base.endsWith('/') ? base.substring(0, base.length - 1) : base,
      officeLatitude: double.tryParse(lat) ?? 14.7167,
      officeLongitude: double.tryParse(lng) ?? -17.4677,
      allowedRadiusMeters: double.tryParse(radius) ?? 150,
      useTestData: useTestData,
    );
  }
}
