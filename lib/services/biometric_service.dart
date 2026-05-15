import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../core/errors/failures.dart';

enum BiometricKind { fingerprint, face }

/// Encapsule `local_auth` pour Face ID / empreinte.
class BiometricService {
  BiometricService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> get canCheckBiometrics => _auth.canCheckBiometrics;

  Future<List<BiometricType>> get availableBiometrics =>
      _auth.getAvailableBiometrics();

  Future<bool> isDeviceSupported() => _auth.isDeviceSupported();

  Future<bool> authenticate({
    String localizedReason = 'Valider votre identité',
    BiometricKind preferred = BiometricKind.fingerprint,
  }) async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        throw const BiometricFailure('Biométrie non disponible sur cet appareil');
      }
      return _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      throw BiometricFailure(e.message ?? 'Erreur biométrique');
    }
  }

  Future<String> createNonce() async {
    final ok = await authenticate(
      localizedReason: 'Confirmer le pointage',
    );
    if (!ok) {
      throw const BiometricFailure('Authentification annulée');
    }
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
