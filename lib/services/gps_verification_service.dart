import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../config/env.dart';
import '../core/errors/failures.dart';
import '../models/office_zone.dart';

/// Vérification : position GPS actuelle de l’appareil vs site (équipement / agence).
class GpsVerificationService {
  GpsVerificationService(this._env);

  final EnvConfig _env;

  static const _freshMaxAge = Duration(minutes: 3);
  static const _fallbackMaxAge = Duration(minutes: 30);

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

  /// `getLastKnownPosition` n'existe pas sur le web (Safari iPhone / PWA).
  Future<Position?> _lastKnownOrNull() async {
    if (kIsWeb) return null;
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  /// Prépare le GPS dès l’ouverture du scanner (dernière position + fix en arrière-plan).
  Future<void> warmUpLocation() async {
    try {
      await ensureLocationPermission();
      if (!await Geolocator.isLocationServiceEnabled()) {
        return;
      }
      await _lastKnownOrNull();
      unawaited(
        Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 20),
          ),
        ).then((_) {}, onError: (_) {}),
      );
    } catch (_) {}
  }

  /// Position GPS lue sur le téléphone au moment du scan / pointage.
  Future<Position> getCurrentPosition() async {
    await ensureLocationPermission();
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationFailure('Activez le GPS pour continuer.');
    }

    final last = await _lastKnownOrNull();
    if (last != null && _positionAge(last) <= _freshMaxAge) {
      return last;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } on TimeoutException {
        if (last != null && _positionAge(last) <= _fallbackMaxAge) {
          return last;
        }
        throw const LocationFailure(
          'Position GPS introuvable. Activez la localisation précise, '
          'placez-vous près d’une fenêtre ou attendez quelques secondes avant de rescanner.',
        );
      }
    }
  }

  /// Compare la position appareil au site [zone] (QR / profil), pas aux coords .env.
  Future<Position> verifyWithinOfficeZone({OfficeZone? zone}) async {
    final pos = await getCurrentPosition();
    final effective = zone ?? OfficeZone.fromEnv(_env);

    if (!effective.hasCoordinates) {
      throw LocationFailure(
        effective.agenceNom != null
            ? 'Le site « ${effective.agenceNom} » n’a pas de GPS configuré. Contactez le RH.'
            : 'Aucune zone GPS configurée pour ce site.',
      );
    }

    final distance = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      effective.latitude!,
      effective.longitude!,
    );
    if (distance > effective.radiusMetres) {
      final site = effective.agenceNom ?? 'du site';
      throw LocationFailure(
        'Vous êtes hors zone autorisée (${distance.toStringAsFixed(0)} m de $site, max ${effective.radiusMetres.toStringAsFixed(0)} m).',
      );
    }
    return pos;
  }

  Duration _positionAge(Position position) {
    return DateTime.now().difference(position.timestamp);
  }
}
