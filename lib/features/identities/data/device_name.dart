import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Pixel-9" style name of this device, for default key comments (`nux@Pixel-9`).
final deviceNameProvider = FutureProvider<String>((ref) async {
  var name = 'device';
  try {
    if (Platform.isAndroid) {
      name = (await DeviceInfoPlugin().androidInfo).model;
    } else {
      name = Platform.localHostname;
    }
  } catch (_) {}
  return name.trim().replaceAll(RegExp(r'\s+'), '-');
});
