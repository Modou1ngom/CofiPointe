import 'package:equatable/equatable.dart';

import '../../../../core/utils/app_date_format.dart';
import '../../../../models/office_zone.dart';

/// Site actif renvoyé par `GET /pointage/sites`.
class PointageSiteSummary extends Equatable {
  const PointageSiteSummary({
    required this.id,
    required this.nom,
    required this.codePublic,
  });

  final int id;
  final String nom;
  final String codePublic;

  factory PointageSiteSummary.fromJson(Map<String, dynamic> json) {
    return PointageSiteSummary(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      nom: json['nom']?.toString() ?? '',
      codePublic: json['code_public']?.toString() ??
          json['codePublic']?.toString() ??
          '',
    );
  }

  @override
  List<Object?> get props => [id, nom, codePublic];
}

/// Ligne `GET /pointage/today` (chronologie du jour).
class PointageTodayRow extends Equatable {
  const PointageTodayRow({
    required this.id,
    required this.sens,
    required this.enregistreAt,
  });

  final int id;
  /// `entree` ou `sortie` (backend Laravel).
  final String sens;
  final DateTime enregistreAt;

  factory PointageTodayRow.fromJson(Map<String, dynamic> json) {
    return PointageTodayRow(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      sens: json['sens']?.toString() ?? '',
      enregistreAt: AppDateFormat.parseApi(
            json['enregistre_at'] ?? json['enregistreAt'],
          ) ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, sens, enregistreAt];
}

/// Première entrée / dernière sortie du jour (aligné sur l’agrégation historique Laravel).
class PointageTodaySummary extends Equatable {
  const PointageTodaySummary({
    this.checkIn,
    this.checkOut,
    this.rows = const [],
    this.officeZone,
  });

  static const PointageTodaySummary empty = PointageTodaySummary();

  final DateTime? checkIn;
  final DateTime? checkOut;
  final List<PointageTodayRow> rows;
  final OfficeZone? officeZone;

  /// Réponse agrégée `GET /pointage/today` (`check_in` / `check_out`).
  factory PointageTodaySummary.fromTodayApiMap(Map<String, dynamic> json) {
    final zoneRaw = json['office_zone'] ?? json['officeZone'];
    return PointageTodaySummary(
      checkIn: AppDateFormat.parseApi(json['check_in'] ?? json['checkIn']),
      checkOut: AppDateFormat.parseApi(json['check_out'] ?? json['checkOut']),
      officeZone: zoneRaw is Map
          ? OfficeZone.fromJson(Map<String, dynamic>.from(zoneRaw))
          : null,
    );
  }

  /// `sens` attendus : `entree`, `sortie`.
  factory PointageTodaySummary.fromTodayApiList(List<dynamic> list) {
    final rows = list
        .whereType<Map>()
        .map((e) => PointageTodayRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    rows.sort((a, b) => a.enregistreAt.compareTo(b.enregistreAt));

    DateTime? firstEntree;
    DateTime? lastSortie;
    for (final r in rows) {
      final s = r.sens.toLowerCase();
      if (s == 'entree') {
        firstEntree ??= r.enregistreAt;
      } else if (s == 'sortie') {
        lastSortie = r.enregistreAt;
      }
    }
    return PointageTodaySummary(
      checkIn: firstEntree,
      checkOut: lastSortie,
      rows: rows,
    );
  }

  @override
  List<Object?> get props => [checkIn, checkOut, rows, officeZone];
}
