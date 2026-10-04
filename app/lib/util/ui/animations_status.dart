import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart';
import 'package:localsend_app/util/native/ios_channel.dart';
import 'package:localsend_app/util/native/macos_channel.dart';
import 'package:logging/logging.dart';

Future<bool> getSystemAnimationsStatus() async {
  try {
    if (Platform.isAndroid) {
      return await getSystemAnimationsStatusAndroid();
    } else if (Platform.isIOS) {
      return !await isReduceMotionEnabledIOS();
    } else if (Platform.isMacOS) {
      return !await isReduceMotionEnabledMacOs();
    }
  } catch (error, stack) {
    Logger('MotionPreferences').warning('Could not query native motion settings; using Flutter accessibility.', error, stack);
  }
  return !WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
}
