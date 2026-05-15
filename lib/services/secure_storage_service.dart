import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage chiffré des jetons et liaison d’appareil.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  static const _accessToken = 'access_token';
  static const _refreshToken = 'refresh_token';
  static const _deviceId = 'device_id';
  static const _sessionJson = 'session_json';
  static const _deviceRegistered = 'device_registered';
  static const _biometricEnabled = 'biometric_enabled';
  static const _biometricOnboardingDone = 'biometric_onboarding_done';

  final FlutterSecureStorage _storage;

  Future<void> writeAccessToken(String? value) =>
      _write(_accessToken, value);
  Future<String?> readAccessToken() => _storage.read(key: _accessToken);

  Future<void> writeRefreshToken(String? value) =>
      _write(_refreshToken, value);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshToken);

  Future<void> writeDeviceId(String value) => _write(_deviceId, value);
  Future<String?> readDeviceId() => _storage.read(key: _deviceId);

  Future<void> writeSessionJson(String? json) => _write(_sessionJson, json);
  Future<String?> readSessionJson() => _storage.read(key: _sessionJson);

  Future<void> writeDeviceRegistered(bool value) =>
      _write(_deviceRegistered, value ? 'true' : null);
  Future<bool> readDeviceRegistered() async =>
      (await _storage.read(key: _deviceRegistered)) == 'true';

  Future<void> writeBiometricEnabled(bool value) =>
      _write(_biometricEnabled, value ? 'true' : null);
  Future<bool> readBiometricEnabled() async =>
      (await _storage.read(key: _biometricEnabled)) == 'true';

  Future<void> writeBiometricOnboardingDone(bool value) =>
      _write(_biometricOnboardingDone, value ? 'true' : null);

  Future<bool> readBiometricOnboardingDone() async =>
      (await _storage.read(key: _biometricOnboardingDone)) == 'true';

  Future<void> clearSession() async {
    await _storage.delete(key: _accessToken);
    await _storage.delete(key: _refreshToken);
    await _storage.delete(key: _sessionJson);
    await _storage.delete(key: _deviceId);
    await _storage.delete(key: _deviceRegistered);
    await _storage.delete(key: _biometricEnabled);
    await _storage.delete(key: _biometricOnboardingDone);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<void> _write(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }
}
