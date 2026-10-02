import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_isolates/model/device.dart';

extension DeviceTypeExt on DeviceType {
  IconData get icon {
    return switch (this) {
      DeviceType.mobile => Icons.smartphone,
      DeviceType.desktop => Icons.computer,
      DeviceType.web => Icons.language,
      DeviceType.headless => Icons.terminal,
      DeviceType.server => Icons.dns,
    };
  }

  String get displayName {
    return switch (this) {
      DeviceType.mobile => t.sendTab.platforms.mobile,
      DeviceType.desktop => t.sendTab.platforms.desktop,
      DeviceType.web => t.sendTab.platforms.web,
      DeviceType.headless => t.sendTab.platforms.headless,
      DeviceType.server => t.sendTab.platforms.server,
    };
  }
}
