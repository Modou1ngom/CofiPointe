import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

class DeviceRegistrationInfo {
  const DeviceRegistrationInfo({
    required this.model,
    required this.deviceId,
    required this.osVersion,
    required this.appVersion,
    this.serialNumber,
  });

  final String model;
  final String deviceId;
  final String osVersion;
  final String appVersion;
  /// Empreinte stable envoyée au serveur (prioritaire pour le garde « 1 appareil / jour »).
  final String? serialNumber;
}

class DeviceInfoService {
  static const _androidIdPlugin = AndroidId();

  /// Toujours rafraîchir l’ID (écrase l’ancien Build.ID mis en cache).
  Future<({String deviceId, String? serialNumber})> resolveAndPersist(
    Future<void> Function(String deviceId) writeDeviceId,
  ) async {
    final info = await collect();
    await writeDeviceId(info.deviceId);
    return (deviceId: info.deviceId, serialNumber: info.serialNumber);
  }

  /// `device_info_plus` expose `AndroidDeviceInfo.id` = Build.ID (firmware),
  /// partagé entre téléphones du même modèle → faux positifs « appareil déjà utilisé ».
  /// On utilise ANDROID_ID (unique appareil + clé de signature).
  Future<DeviceRegistrationInfo> collect() async {
    final plugin = DeviceInfoPlugin();
    final pkg = await PackageInfo.fromPlatform();
    String model = 'Appareil';
    String deviceId = 'unknown';
    String os = '';
    String? serialNumber;

    if (kIsWeb) {
      final web = await plugin.webBrowserInfo;
      model = web.browserName.name;
      deviceId = web.userAgent ?? 'web';
      os = 'Web';
    } else if (Platform.isAndroid) {
      final a = await plugin.androidInfo;
      model = '${a.manufacturer} ${a.model}';
      os = 'Android ${a.version.release}';

      final androidId = await _resolveAndroidId();
      deviceId = androidId;
      // Priorité serveur : serial_number — doit être unique, pas le Build.SERIAL.
      serialNumber = androidId;
    } else if (Platform.isIOS) {
      final i = await plugin.iosInfo;
      model = i.utsname.machine.isNotEmpty
          ? i.utsname.machine
          : (i.model.isNotEmpty ? i.model : 'iPhone');
      deviceId = i.identifierForVendor ?? 'ios';
      os = '${i.systemName} ${i.systemVersion}';
      if (deviceId != 'ios') {
        serialNumber = deviceId;
      }
    }

    return DeviceRegistrationInfo(
      model: model,
      deviceId: deviceId,
      osVersion: os,
      appVersion: '${pkg.version}+${pkg.buildNumber}',
      serialNumber: serialNumber,
    );
  }

  Future<String> _resolveAndroidId() async {
    try {
      final id = (await _androidIdPlugin.getId())?.trim();
      if (id != null &&
          id.isNotEmpty &&
          id.toLowerCase() != 'unknown' &&
          id.toLowerCase() != 'null') {
        return id;
      }
    } catch (_) {
      // Plugin indisponible (tests / plateforme) → UUID local.
    }
    return 'aid_${const Uuid().v4()}';
  }
}
