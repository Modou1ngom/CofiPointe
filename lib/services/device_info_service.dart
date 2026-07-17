import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  /// N° de série matériel quand disponible (Android) ; sinon null.
  final String? serialNumber;
}

class DeviceInfoService {
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
      deviceId = a.id;
      os = 'Android ${a.version.release}';
      final sn = a.serialNumber.trim();
      if (sn.isNotEmpty &&
          sn.toLowerCase() != 'unknown' &&
          sn.toLowerCase() != 'unauthorized') {
        serialNumber = sn;
      }
    } else if (Platform.isIOS) {
      final i = await plugin.iosInfo;
      model = i.utsname.machine ?? i.model ?? 'iPhone';
      deviceId = i.identifierForVendor ?? 'ios';
      os = '${i.systemName} ${i.systemVersion}';
      // Sur iOS, l’identifiant vendor sert aussi d’empreinte stable.
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
}
