import '../features/attendance/data/models/attendance_models.dart';
import '../features/attendance/data/models/pointage_mobile_models.dart';
import '../features/auth/data/models/auth_api_models.dart';
import '../features/auth/data/models/user_model.dart';
import '../features/notifications/data/models/notification_model.dart';

abstract final class TestFixtures {
  static const testAccessToken = 'test-access-token';
  static const testRefreshToken = 'test-refresh-token';

  static Future<void> simulateNetworkDelay() =>
      Future<void>.delayed(const Duration(milliseconds: 250));

  static UserModel userFor(String identifier) {
    final email = identifier.contains('@') ? identifier : null;
    return UserModel(
      id: 'test-user-1',
      fullName: 'Modou Diop',
      email: email ?? 'modou.diop@cofinacorp.com',
      matricule: email == null ? identifier : 'CFN-2024-0156',
      jobTitle: 'Développeur',
      phone: '+221 77 000 00 00',
      department: 'Informatique',
      linkedDevice: 'Chrome · Linux',
    );
  }

  static LoginResponse loginResponse(LoginRequest request) {
    return LoginResponse(
      accessToken: testAccessToken,
      refreshToken: testRefreshToken,
      user: userFor(request.identifier),
    );
  }

  static VerifyOtpResponse verifyOtpResponse(VerifyOtpRequest request) {
    return VerifyOtpResponse(
      accessToken: testAccessToken,
      refreshToken: testRefreshToken,
      user: userFor(request.identifier),
    );
  }

  static UserModel profileUser() {
    return const UserModel(
      id: 'test-user-1',
      fullName: 'Modou Diop',
      email: 'modou.diop@cofinacorp.com',
      matricule: 'CFN-2024-0156',
      jobTitle: 'Développeur',
      phone: '+221 77 000 00 00',
      department: 'Informatique',
      linkedDevice: 'Samsung Galaxy S24',
    );
  }

  static List<AttendanceRecord> attendanceHistory() {
    final now = DateTime.now();
    return List.generate(5, (index) {
      final day = DateTime(now.year, now.month, now.day).subtract(
        Duration(days: index),
      );
      final checkIn = day.add(const Duration(hours: 8, minutes: 45));
      final checkOut = day.add(const Duration(hours: 17, minutes: 30));
      return AttendanceRecord(
        id: 'test-attendance-$index',
        date: day,
        checkIn: checkIn,
        checkOut: index == 0 ? null : checkOut,
        status: index == 0 ? 'present' : 'complete',
      );
    });
  }

  static AttendanceSubmitResponse attendanceSubmit(AttendanceSubmitRequest body) {
    return AttendanceSubmitResponse(
      id: 'test-attendance-${DateTime.now().millisecondsSinceEpoch}',
      recordedAt: DateTime.now(),
      type: body.type,
      message: 'Pointage enregistré (mode test).',
    );
  }

  static List<NotificationItem> notifications() {
    final now = DateTime.now();
    return [
      NotificationItem(
        id: 'test-notification-1',
        title: 'Arrivée enregistrée',
        body: 'Heure réelle · 08:05',
        createdAt: now.subtract(const Duration(minutes: 15)),
        punchKind: NotificationPunchKind.arrival,
        adjusted: false,
        clockTime: '08:05',
      ),
      NotificationItem(
        id: 'test-notification-2',
        title: 'Départ enregistré',
        body: 'Heure ajustée · 17:00',
        createdAt: now.subtract(const Duration(hours: 2)),
        read: true,
        punchKind: NotificationPunchKind.departure,
        adjusted: true,
        clockTime: '17:00',
      ),
    ];
  }

  static PointageTodaySummary pointageTodaySummary() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return PointageTodaySummary(
      checkIn: start.add(const Duration(hours: 8, minutes: 5)),
      checkOut: start.add(const Duration(hours: 12, minutes: 30)),
      rows: const [],
    );
  }

  static List<PointageSiteSummary> pointageSites() {
    return const [
      PointageSiteSummary(
        id: 1,
        nom: 'Siège (démo)',
        codePublic: 'DEMO-PUBLIC-01',
      ),
    ];
  }
}
