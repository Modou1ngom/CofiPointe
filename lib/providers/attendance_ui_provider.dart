import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final String qrPayload;
  final String type;
}

final pendingAttendanceProvider =
    StateProvider<PendingAttendancePayload?>((ref) => null);
