import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../features/attendance/data/models/attendance_models.dart';
import 'secure_storage_service.dart';

/// File d’attente chiffrée des pointages hors ligne + synchronisation.
class OfflineSyncService {
  OfflineSyncService({
    required SecureStorageService secureStorage,
    required SharedPreferences prefs,
  })  : _secureStorage = secureStorage,
        _prefs = prefs;

  static const _queueKey = 'offline_attendance_queue_v1';

  final SecureStorageService _secureStorage;
  final SharedPreferences _prefs;

  Future<String> _deriveKeyMaterial() async {
    final deviceId = await _secureStorage.readDeviceId() ?? 'anonymous-device';
    final bytes = utf8.encode('cofipointe-offline-$deviceId');
    return sha256.convert(bytes).toString();
  }

  Future<enc.Key> _aesKey() async {
    final material = await _deriveKeyMaterial();
    final sub = material.padRight(32).substring(0, 32);
    return enc.Key.fromUtf8(sub);
  }

  Future<String> encryptPayload(Map<String, dynamic> payload) async {
    final key = await _aesKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(jsonEncode(payload), iv: iv);
    return jsonEncode({
      'iv': iv.base64,
      'data': encrypted.base64,
    });
  }

  Future<Map<String, dynamic>> decryptPayload(String blob) async {
    final map = jsonDecode(blob) as Map<String, dynamic>;
    final key = await _aesKey();
    final iv = enc.IV.fromBase64(map['iv'] as String);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decrypt64(map['data'] as String, iv: iv);
    return jsonDecode(decrypted) as Map<String, dynamic>;
  }

  Future<void> enqueuePending(Map<String, dynamic> attendancePayload) async {
    final id = const Uuid().v4();
    final encrypted = await encryptPayload(attendancePayload);
    final pending = PendingAttendance(
      id: id,
      encryptedPayload: encrypted,
      createdAt: DateTime.now(),
    );
    final list = await _readQueue();
    list.add(pending);
    await _writeQueue(list);
  }

  Future<List<PendingAttendance>> pendingItems() => _readQueue();

  Future<List<PendingAttendance>> _readQueue() async {
    final raw = _prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => PendingAttendance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeQueue(List<PendingAttendance> items) async {
    await _prefs.setString(
      _queueKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<bool> get isOnline async {
    final r = await Connectivity().checkConnectivity();
    if (r.isEmpty) return true;
    return !r.contains(ConnectivityResult.none);
  }

  /// Appelé avec une fonction qui envoie le payload déchiffré au serveur.
  Future<void> flush({
    required Future<void> Function(Map<String, dynamic> payload) upload,
  }) async {
    if (!await isOnline) return;
    final items = await _readQueue();
    final remaining = <PendingAttendance>[];
    for (final item in items) {
      try {
        final payload = await decryptPayload(item.encryptedPayload);
        await upload(payload);
      } catch (e, st) {
        debugPrint('Sync item failed: $e\n$st');
        remaining.add(item);
      }
    }
    await _writeQueue(remaining);
  }
}
