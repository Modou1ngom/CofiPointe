import 'package:equatable/equatable.dart';

import '../config/env.dart';

/// Zone de pointage (coordonnées du site / équipement sur place).
class OfficeZone extends Equatable {
  const OfficeZone({
    this.latitude,
    this.longitude,
    required this.radiusMetres,
    this.agenceId,
    this.agenceNom,
    this.configured = true,
  });

  final double? latitude;
  final double? longitude;
  final double radiusMetres;
  final int? agenceId;
  final String? agenceNom;
  final bool configured;

  bool get hasCoordinates =>
      latitude != null && longitude != null && configured;

  factory OfficeZone.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const OfficeZone(radiusMetres: 50, configured: false);
    }
    final lat = _toDouble(json['latitude']);
    final lng = _toDouble(json['longitude']);
    final configuredRaw = json['configured'];
    final configured = configuredRaw == null
        ? (lat != null && lng != null)
        : configuredRaw == true || configuredRaw == 1 || configuredRaw == 'true';
    return OfficeZone(
      latitude: lat,
      longitude: lng,
      radiusMetres: _toDouble(json['radius_metres'] ?? json['radiusMetres']) ?? 50,
      agenceId: int.tryParse(json['agence_id']?.toString() ?? ''),
      agenceNom: json['agence_nom']?.toString() ?? json['agenceNom']?.toString(),
      configured: configured,
    );
  }

  factory OfficeZone.fromEnv(EnvConfig env) => OfficeZone(
        latitude: env.officeLatitude,
        longitude: env.officeLongitude,
        radiusMetres: env.allowedRadiusMeters,
        configured: true,
      );

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  @override
  List<Object?> get props =>
      [latitude, longitude, radiusMetres, agenceId, agenceNom, configured];
}
