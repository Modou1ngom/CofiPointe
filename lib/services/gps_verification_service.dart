import 'package:geolocator/geolocator.dart';

import '../config/env.dart';
import '../core/errors/failures.dart';

/// Vérification anti-fraude : position dans le périmètre autorisé.
class GpsVerificationService {
  GpsVerificationService(this._env);

  final EnvConfig _env;

  Future<void> ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw const LocationFailure(
        'Permission localisation requise pour valider le pointage.',
      );
    }
  }

  Future<Position> getCurrentPosition() async {
    await ensureLocationPermission();
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationFailure('Activez le GPS pour continuer.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  /// Retourne la position si la zone est valide.
  Future<Position> verifyWithinOfficeZone() async {
    final pos = await getCurrentPosition();
    final distance = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      _env.officeLatitude,
      _env.officeLongitude,
    );
    if (distance > _env.allowedRadiusMeters) {
      throw LocationFailure(
        'Vous êtes hors zone autorisée (${distance.toStringAsFixed(0)} m du site).',
      );
    }
    return pos;
  }
}
