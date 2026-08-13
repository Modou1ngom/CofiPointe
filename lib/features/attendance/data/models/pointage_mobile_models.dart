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
    this.checkInLabel,
    this.checkOutLabel,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.rows = const [],
    this.officeZone,
    this.dayComplete = false,
    this.autoFerie = false,
    this.statusLabel,
    this.apiDate,
  });

  static const PointageTodaySummary empty = PointageTodaySummary();

  final DateTime? checkIn;
  final DateTime? checkOut;
  /// Libellé d’affichage (heure réelle si fournie, sinon formatée).
  final String? checkInLabel;
  final String? checkOutLabel;
  /// Horaires prévus RH (section « Mes horaires »).
  final String? scheduledArrival;
  final String? scheduledDeparture;
  final List<PointageTodayRow> rows;
  final OfficeZone? officeZone;
  final bool dayComplete;
  final bool autoFerie;
  final String? statusLabel;
  final String? apiDate;

  bool get hasCheckIn => checkIn != null;
  bool get hasCheckOut => checkOut != null;
  bool get isDayComplete => dayComplete || (hasCheckIn && hasCheckOut);

  /// Réponse agrégée `GET /pointage/today` (`check_in` / `check_out`).
  factory PointageTodaySummary.fromTodayApiMap(Map<String, dynamic> json) {
    final zoneRaw = json['office_zone'] ?? json['officeZone'];
    final checkIn = _onlyToday(AppDateFormat.parseApi(json['check_in'] ?? json['checkIn']));
    final checkOut = _onlyToday(AppDateFormat.parseApi(json['check_out'] ?? json['checkOut']));
    final labelIn = _firstNonEmpty([
      json['entry_reelle'],
      json['entryReelle'],
      json['entree_reelle'],
    ]);
    final labelOut = _firstNonEmpty([
      json['exit_reelle'],
      json['exitReelle'],
      json['sortie_reelle'],
    ]);
    final scheduledIn = _normalizeHhmm(_firstNonEmpty([
      json['scheduled_arrival'],
      json['scheduledArrival'],
      json['heure_arrivee_prevue'],
      json['heureArriveePrevue'],
    ]));
    final scheduledOut = _normalizeHhmm(_firstNonEmpty([
      json['scheduled_departure'],
      json['scheduledDeparture'],
      json['heure_depart_prevue'],
      json['heureDepartPrevue'],
    ]));
    final dayComplete = json['journee_complete'] == true ||
        json['journeeComplete'] == true ||
        (checkIn != null && checkOut != null);
    final autoFerie =
        json['auto_ferie'] == true || json['autoFerie'] == true;
    final statusLabel = _firstNonEmpty([json['statut'], json['status_label']]);

    return PointageTodaySummary(
      checkIn: checkIn,
      checkOut: checkOut,
      checkInLabel: labelIn ??
          (checkIn != null ? AppDateFormat.formatTime12h(checkIn) : null),
      checkOutLabel: labelOut ??
          (checkOut != null ? AppDateFormat.formatTime12h(checkOut) : null),
      scheduledArrival: scheduledIn,
      scheduledDeparture: scheduledOut,
      officeZone: zoneRaw is Map
          ? OfficeZone.fromJson(Map<String, dynamic>.from(zoneRaw))
          : null,
      dayComplete: dayComplete,
      autoFerie: autoFerie,
      statusLabel: statusLabel,
      apiDate: json['date']?.toString(),
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
      final at = _onlyToday(r.enregistreAt);
      if (at == null) continue;
      if (s == 'entree') {
        firstEntree ??= at;
      } else if (s == 'sortie') {
        lastSortie = at;
      }
    }
    return PointageTodaySummary(
      checkIn: firstEntree,
      checkOut: lastSortie,
      checkInLabel:
          firstEntree != null ? AppDateFormat.formatTime12h(firstEntree) : null,
      checkOutLabel:
          lastSortie != null ? AppDateFormat.formatTime12h(lastSortie) : null,
      rows: rows,
      dayComplete: firstEntree != null && lastSortie != null,
    );
  }

  static DateTime? _onlyToday(DateTime? dt) {
    if (dt == null) return null;
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year != now.year ||
        local.month != now.month ||
        local.day != now.day) {
      return null;
    }
    return local;
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final s = v?.toString().trim();
      if (s != null && s.isNotEmpty && s != '—' && s != '-') return s;
    }
    return null;
  }

  /// Normalise `08:00` / `8:00` / `08h00` → `08h00`.
  static String? _normalizeHhmm(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final m = RegExp(r'^(\d{1,2})[:hH]?(\d{0,2})').firstMatch(s);
    if (m == null) return s;
    final h = int.tryParse(m.group(1) ?? '') ?? 0;
    final min = int.tryParse((m.group(2) == null || m.group(2)!.isEmpty) ? '0' : m.group(2)!) ?? 0;
    return '${h.toString().padLeft(2, '0')}h${min.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
        checkIn,
        checkOut,
        checkInLabel,
        checkOutLabel,
        scheduledArrival,
        scheduledDeparture,
        rows,
        officeZone,
        dayComplete,
        autoFerie,
        statusLabel,
        apiDate,
      ];
}
