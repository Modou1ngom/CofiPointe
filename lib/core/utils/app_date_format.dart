import 'package:intl/intl.dart';

/// Dates/heures API Laravel → affichage local format français 24 h (ex. `15h23`).
abstract final class AppDateFormat {
  /// Parse ISO 8601 renvoyé par l'API et convertit en heure locale appareil.
  static DateTime? parseApi(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    return dt?.toLocal();
  }

  static final DateFormat _time24 = DateFormat("HH'h'mm", 'fr_FR');

  /// Heure au format français 24 h (`15h23`). Conserve le nom historique
  /// `formatTime12h` pour ne pas casser les appels existants.
  static String formatTime12h(DateTime dateTime) =>
      _time24.format(dateTime.toLocal());

  static String formatTime24h(DateTime dateTime) =>
      _time24.format(dateTime.toLocal());

  static String formatDateLong(DateTime dateTime) => DateFormat(
        'EEEE d MMMM yyyy',
        'fr_FR',
      ).format(dateTime.toLocal());
}
