import 'package:equatable/equatable.dart';

import '../../../../core/utils/app_date_format.dart';

enum NotificationPunchKind { arrival, departure, other }

/// Présentation dérivée des champs existants (`title`, `body`, `createdAt`).
class NotificationPresentation {
  const NotificationPresentation({
    required this.kind,
    required this.adjusted,
    required this.shortTitle,
    required this.timeLabel,
    required this.dateLabel,
    required this.subtitle,
  });

  final NotificationPunchKind kind;
  final bool adjusted;
  final String shortTitle;
  final String timeLabel;
  final String dateLabel;
  final String subtitle;
}

class NotificationItem extends Equatable {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.punchKind,
    this.adjusted,
    this.clockTime,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  /// Champs structurés optionnels (API enrichie) — sinon dérivés de title/body.
  final NotificationPunchKind? punchKind;
  final bool? adjusted;
  final String? clockTime;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final title = json['title']?.toString() ?? '';
    final body =
        json['body']?.toString() ?? json['message']?.toString() ?? '';
    final createdAt = AppDateFormat.parseApi(json['created_at']) ??
        DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now();

    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: title,
      body: body,
      createdAt: createdAt,
      read: json['read'] == true,
      punchKind: _parseKind(
        json['kind'] ??
            json['type'] ??
            json['pointage_type'] ??
            json['punch_kind'],
      ),
      adjusted: _parseBool(
        json['ajustement_applique'] ??
            json['ajustementApplique'] ??
            json['adjusted'],
      ),
      clockTime: (json['heure'] ??
              json['heure_effective'] ??
              json['heureEffective'] ??
              json['clock_time'] ??
              json['time'])
          ?.toString(),
    );
  }

  NotificationPresentation get presentation {
    final time = _resolveTimeLabel(clockTime, body, createdAt);
    final kind = _resolveKind(punchKind, title, body, time, createdAt);
    final isAdjusted = adjusted ?? _adjustedFromBody(body);
    final date = _relativeDateLabel(createdAt);
    final shortTitle = switch (kind) {
      NotificationPunchKind.arrival => 'Arrivée enregistrée',
      NotificationPunchKind.departure => 'Départ enregistré',
      NotificationPunchKind.other => _shortTitleFromRaw(title),
    };
    final mode = isAdjusted ? 'Heure ajustée' : 'Heure réelle';
    final subtitle = kind == NotificationPunchKind.other
        ? date
        : '$mode · $date';

    return NotificationPresentation(
      kind: kind,
      adjusted: isAdjusted,
      shortTitle: shortTitle,
      timeLabel: time,
      dateLabel: date,
      subtitle: subtitle,
    );
  }

  /// Résout arrivée/départ même pour les anciens titres « Pointage enregistré ».
  static NotificationPunchKind _resolveKind(
    NotificationPunchKind? explicit,
    String title,
    String body,
    String timeLabel,
    DateTime createdAt,
  ) {
    if (explicit == NotificationPunchKind.arrival ||
        explicit == NotificationPunchKind.departure) {
      return explicit!;
    }

    final fromText = _kindFromText('$title $body');
    if (fromText != NotificationPunchKind.other) return fromText;

    if (_looksLikePunch(title, body)) {
      return _kindFromClockHour(timeLabel, createdAt);
    }

    return NotificationPunchKind.other;
  }

  static NotificationPunchKind? _parseKind(dynamic raw) {
    if (raw == null) return null;
    final t = raw.toString().trim().toLowerCase();
    if (t.isEmpty || t == 'other' || t == 'unknown') return null;
    if (t.contains('arriv') || t == 'arrivee' || t == 'checkin' || t == 'entree') {
      return NotificationPunchKind.arrival;
    }
    if (t.contains('depart') ||
        t.contains('départ') ||
        t == 'checkout' ||
        t == 'sortie') {
      return NotificationPunchKind.departure;
    }
    // Ne pas figer « other » : laisser _resolveKind inférer.
    return null;
  }

  static bool? _parseBool(dynamic raw) {
    if (raw == null) return null;
    if (raw is bool) return raw;
    final s = raw.toString().trim().toLowerCase();
    if (s == '1' || s == 'true' || s == 'oui') return true;
    if (s == '0' || s == 'false' || s == 'non') return false;
    return null;
  }

  static NotificationPunchKind _kindFromText(String text) {
    final t = text.toLowerCase();
    if (t.contains('arriv')) return NotificationPunchKind.arrival;
    if (t.contains('départ') || t.contains('depart') || t.contains('sortie')) {
      return NotificationPunchKind.departure;
    }
    if (t.contains('entr') && !t.contains('enregistr')) {
      return NotificationPunchKind.arrival;
    }
    return NotificationPunchKind.other;
  }

  static bool _looksLikePunch(String title, String body) {
    final t = '${title.toLowerCase()} ${body.toLowerCase()}';
    return t.contains('pointage') ||
        t.contains('arriv') ||
        t.contains('départ') ||
        t.contains('depart') ||
        t.contains('heure réelle') ||
        t.contains('heure reelle') ||
        t.contains('heure ajust');
  }

  /// Heuristique pour titres génériques : matin → arrivée, après-midi → départ.
  static NotificationPunchKind _kindFromClockHour(
    String timeLabel,
    DateTime createdAt,
  ) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(timeLabel.trim());
    final hour = match != null
        ? int.tryParse(match.group(1)!) ?? createdAt.toLocal().hour
        : createdAt.toLocal().hour;
    return hour < 13
        ? NotificationPunchKind.arrival
        : NotificationPunchKind.departure;
  }

  static bool _adjustedFromBody(String body) {
    final b = body.toLowerCase();
    if (b.contains('ajust')) return true;
    if (b.contains('réelle') || b.contains('reelle')) return false;
    return false;
  }

  static String _resolveTimeLabel(
    String? clockTime,
    String body,
    DateTime createdAt,
  ) {
    final fromField = _normalizeTime(clockTime);
    if (fromField != null) return fromField;

    final match = RegExp(
      r'(\d{1,2})\s*[h:]\s*(\d{2})',
      caseSensitive: false,
    ).firstMatch(body);
    if (match != null) {
      final h = match.group(1)!.padLeft(2, '0');
      final m = match.group(2)!;
      return '$h:$m';
    }

    final local = createdAt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String? _normalizeTime(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final match = RegExp(
      r'(\d{1,2})\s*[h:]\s*(\d{2})',
      caseSensitive: false,
    ).firstMatch(s);
    if (match == null) return null;
    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)!}';
  }

  static String _relativeDateLabel(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'aujourd’hui';
    if (diff == 1) return 'hier';

    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return '${local.day} ${months[local.month - 1]}';
  }

  static String _shortTitleFromRaw(String title) {
    final t = title.trim();
    if (t.isEmpty) return 'Notification';
    // Évite les titres longs multi-lignes.
    final firstLine = t.split(RegExp(r'[\r\n]+')).first.trim();
    if (firstLine.length <= 42) return firstLine;
    return '${firstLine.substring(0, 39)}…';
  }

  @override
  List<Object?> get props =>
      [id, title, body, createdAt, read, punchKind, adjusted, clockTime];
}
