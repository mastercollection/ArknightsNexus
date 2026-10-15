import 'dart:io';

import 'app_platform.dart';

AppPlatform detectAppPlatform() {
  if (Platform.isWindows) {
    return AppPlatform.windows;
  }
  if (Platform.isAndroid) {
    return AppPlatform.android;
  }
  return AppPlatform.other;
}
