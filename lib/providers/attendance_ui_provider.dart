import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/office_zone.dart';

class TodayAttendanceUiState {
  const TodayAttendanceUiState({
    this.checkIn,
    this.checkOut,
    this.lastUpdated,
  });

  final DateTime? checkIn;
  final DateTime? checkOut;
  final DateTime? lastUpdated;

  bool get hasCheckedIn => checkIn != null;
  bool get hasCheckedOut => checkOut != null;
}

class TodayAttendanceNotifier extends StateNotifier<TodayAttendanceUiState> {
  TodayAttendanceNotifier() : super(const TodayAttendanceUiState());

  void setCheckIn(DateTime t) {
    state = TodayAttendanceUiState(
      checkIn: t,
      checkOut: state.checkOut,
      lastUpdated: DateTime.now(),
    );
  }

  void setCheckOut(DateTime t) {
    state = TodayAttendanceUiState(
      checkIn: state.checkIn,
      checkOut: t,
      lastUpdated: DateTime.now(),
    );
  }

  /// Remplace l’état du jour par les valeurs serveur (null = pas de pointage).
  void syncToday({DateTime? checkIn, DateTime? checkOut}) {
    state = TodayAttendanceUiState(
      checkIn: checkIn,
      checkOut: checkOut,
      lastUpdated: DateTime.now(),
    );
  }

  void reset() {
    state = const TodayAttendanceUiState();
  }
}

final todayAttendanceUiProvider =
    StateNotifierProvider<TodayAttendanceNotifier, TodayAttendanceUiState>((ref) {
  return TodayAttendanceNotifier();
});

class PendingAttendancePayload {
  PendingAttendancePayload({
    required this.qrPayload,
    required this.type,
    this.officeZone,
    this.scanValidated = false,
    this.scanLatitude,
    this.scanLongitude,
  });

  final String qrPayload;
  final String type;
  /// Zone du site issu du QR (POST /attendance/scan).
  final OfficeZone? officeZone;
  /// GPS déjà validé côté serveur au scan — ne pas re-comparer aux coords .env.
  final bool scanValidated;
  /// Position utilisée lors de la validation scan (évite un 2e fix GPS).
  final double? scanLatitude;
  final double? scanLongitude;
}

final pendingAttendanceProvider =
    StateProvider<PendingAttendancePayload?>((ref) => null);

/// Entrée déjà faite aujourd’hui → prochain pointage = sortie.
String resolveNextAttendanceType({
  DateTime? checkIn,
  DateTime? checkOut,
}) {
  if (checkIn != null && checkOut == null) return 'checkout';
  if (checkIn == null) return 'checkin';
  return 'checkout';
}
