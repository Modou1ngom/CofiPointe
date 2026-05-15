import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/models/user_model.dart';
import 'secure_storage_service.dart';

/// État de session minimal pour l’UI et les gardes de navigation.
class SessionState {
  const SessionState({
    this.user,
    this.accessToken,
    this.deviceRegistered = false,
    this.biometricEnabled = false,
    this.biometricOnboardingDone = false,
    this.otpPending = false,
  });

  final UserModel? user;
  final String? accessToken;
  final bool deviceRegistered;
  /// Utilisateur a activé biométrie pour connexion rapide.
  final bool biometricEnabled;
  /// Écran biométrie complété (activation ou « Plus tard »).
  final bool biometricOnboardingDone;
  final bool otpPending;

  bool get isAuthenticated =>
      accessToken != null && accessToken!.isNotEmpty && user != null;

  SessionState copyWith({
    UserModel? user,
    String? accessToken,
    bool? deviceRegistered,
    bool? biometricEnabled,
    bool? biometricOnboardingDone,
    bool? otpPending,
  }) {
    return SessionState(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      deviceRegistered: deviceRegistered ?? this.deviceRegistered,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricOnboardingDone:
          biometricOnboardingDone ?? this.biometricOnboardingDone,
      otpPending: otpPending ?? this.otpPending,
    );
  }
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(ref.watch(secureStorageServiceProvider));
});

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._storage) : super(const SessionState());

  final SecureStorageService _storage;

  Future<void> hydrate() async {
    final token = await _storage.readAccessToken();
    final raw = await _storage.readSessionJson();
    UserModel? user;
    if (raw != null && raw.isNotEmpty) {
      try {
        user = UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    final bio = await _storage.readBiometricEnabled();
    final deviceOk = await _storage.readDeviceRegistered();
    final bioDone = await _storage.readBiometricOnboardingDone();

    state = SessionState(
      user: user,
      accessToken: token,
      biometricEnabled: bio,
      deviceRegistered: deviceOk,
      biometricOnboardingDone: bioDone,
    );
  }

  Future<void> setAuthenticated({
    required UserModel user,
    required String accessToken,
    required String? refreshToken,
    bool deviceRegistered = false,
    bool biometricEnabled = false,
    bool biometricOnboardingDone = false,
  }) async {
    await _storage.writeAccessToken(accessToken);
    if (refreshToken != null) {
      await _storage.writeRefreshToken(refreshToken);
    }
    await _storage.writeSessionJson(jsonEncode(user.toJson()));
    await _storage.writeDeviceRegistered(deviceRegistered);
    await _storage.writeBiometricEnabled(biometricEnabled);
    await _storage.writeBiometricOnboardingDone(biometricOnboardingDone);
    state = SessionState(
      user: user,
      accessToken: accessToken,
      deviceRegistered: deviceRegistered,
      biometricEnabled: biometricEnabled,
      biometricOnboardingDone: biometricOnboardingDone,
    );
  }

  Future<void> setDeviceRegistered(bool value) async {
    await _storage.writeDeviceRegistered(value);
    state = state.copyWith(deviceRegistered: value);
  }

  Future<void> setBiometricEnabled(bool value) async {
    await _storage.writeBiometricEnabled(value);
    state = state.copyWith(biometricEnabled: value);
  }

  Future<void> setBiometricOnboardingDone(bool value) async {
    await _storage.writeBiometricOnboardingDone(value);
    state = state.copyWith(biometricOnboardingDone: value);
  }

  Future<void> setOtpPending(bool value) async {
    state = state.copyWith(otpPending: value);
  }

  Future<void> logout() async {
    await _storage.clearSession();
    state = const SessionState();
  }
}
