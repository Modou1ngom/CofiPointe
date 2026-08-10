import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';
import '../core/network/dio_client.dart';
import '../features/attendance/data/datasources/attendance_remote_datasource.dart';
import '../features/auth/data/datasources/auth_remote_datasource.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../features/notifications/data/datasources/notifications_remote_datasource.dart';
import '../features/profile/data/datasources/profile_remote_datasource.dart';
import '../services/biometric_service.dart';
import '../services/face_recognition_service.dart';
import '../services/gps_verification_service.dart';
import '../services/offline_sync_service.dart';
import '../services/session_controller.dart';

/// Réglé dans [main] avec `override`.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider doit être surchargé dans main()');
});

final envProvider = Provider<EnvConfig>((ref) => EnvConfig.fromEnvironment());

final dioClientProvider = Provider<DioClient>((ref) {
  final env = ref.watch(envProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  return DioClient(env: env, secureStorage: storage);
});

final dioProvider = Provider<Dio>((ref) {
  return ref.watch(dioClientProvider).build();
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final env = ref.watch(envProvider);
  return AuthRemoteDataSource(
    ref.watch(dioProvider),
    useTestData: env.useTestData,
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(authRemoteDataSourceProvider));
});

final attendanceRemoteDataSourceProvider =
    Provider<AttendanceRemoteDataSource>((ref) {
  final env = ref.watch(envProvider);
  return AttendanceRemoteDataSource(
    ref.watch(dioProvider),
    useTestData: env.useTestData,
  );
});

final profileRemoteDataSourceProvider =
    Provider<ProfileRemoteDataSource>((ref) {
  final env = ref.watch(envProvider);
  return ProfileRemoteDataSource(
    ref.watch(dioProvider),
    useTestData: env.useTestData,
  );
});

final notificationsRemoteDataSourceProvider =
    Provider<NotificationsRemoteDataSource>((ref) {
  final env = ref.watch(envProvider);
  return NotificationsRemoteDataSource(
    ref.watch(dioProvider),
    useTestData: env.useTestData,
  );
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final faceRecognitionServiceProvider = Provider<FaceRecognitionService>((ref) {
  return FaceRecognitionService(ref.watch(secureStorageServiceProvider));
});

final gpsVerificationServiceProvider =
    Provider<GpsVerificationService>((ref) {
  return GpsVerificationService(ref.watch(envProvider));
});

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  return OfflineSyncService(
    secureStorage: ref.watch(secureStorageServiceProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});
