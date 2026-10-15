import 'app_platform_detect_web.dart'
    if (dart.library.io) 'app_platform_detect_io.dart';

enum AppPlatform {
  windows,
  android,
  web,
  other;

  bool get supportsDesktopLogFolder => this == windows;

  /// Whether the app keeps a log file (the web build logs to the console).
  bool get hasLogFiles => this != web;

  /// Detects the current platform (`dart:io` on native builds).
  static AppPlatform current() => detectAppPlatform();

  String get label => switch (this) {
        AppPlatform.windows => 'Windows',
        AppPlatform.android => 'Android',
        AppPlatform.web => 'Web',
        AppPlatform.other => 'Other',
      };
}
