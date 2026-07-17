import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../core/errors/failures.dart';

enum BiometricKind { fingerprint, face }

/// Encapsule `local_auth` pour Face ID / empreinte.
/// Sur le web (Safari iPhone / PWA), la biométrie native n'existe pas :
/// on valide le choix utilisateur sans appeler le capteur matériel.
class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> get canCheckBiometrics async {
    if (kIsWeb) return true;
    return _auth.canCheckBiometrics;
  }

  Future<List<BiometricType>> get availableBiometrics async {
    if (kIsWeb) return const [];
    return _auth.getAvailableBiometrics();
  }

  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return true;
    return _auth.isDeviceSupported();
  }

  Future<bool> authenticate({
    String localizedReason = 'Valider votre identité',
    BiometricKind preferred = BiometricKind.fingerprint,
  }) async {
    // Web / PWA (iPhone Safari) : pas d'accès Touch ID / Face ID.
    // On accepte le choix (empreinte ou visage) pour débloquer le parcours.
    if (kIsWeb) {
      return true;
    }

    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        throw const BiometricFailure(
          'Biométrie non disponible sur cet appareil',
        );
      }
      final ok = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!ok) {
        throw const BiometricFailure('Authentification annulée');
      }
      return true;
    } on BiometricFailure {
      rethrow;
    } on PlatformException catch (e) {
      throw BiometricFailure(e.message ?? 'Erreur biométrique');
    } catch (e) {
      throw BiometricFailure('Erreur biométrique : $e');
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
