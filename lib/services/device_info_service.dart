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
  });

  final String model;
  final String deviceId;
  final String osVersion;
  final String appVersion;
}

class DeviceInfoService {
  Future<DeviceRegistrationInfo> collect() async {
    final plugin = DeviceInfoPlugin();
    final pkg = await PackageInfo.fromPlatform();
    String model = 'Appareil';
    String deviceId = 'unknown';
    String os = '';

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
    } else if (Platform.isIOS) {
      final i = await plugin.iosInfo;
      model = i.utsname.machine ?? i.model ?? 'iPhone';
      deviceId = i.identifierForVendor ?? 'ios';
      os = '${i.systemName} ${i.systemVersion}';
    }

    return DeviceRegistrationInfo(
      model: model,
      deviceId: deviceId,
      osVersion: os,
      appVersion: '${pkg.version}+${pkg.buildNumber}',
    );
  }
}
