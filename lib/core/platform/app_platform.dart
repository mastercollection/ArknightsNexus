import 'dart:io';

enum AppPlatform {
  windows,
  android,
  other;

  bool get supportsDesktopLogFolder => this == windows;

  /// Detects the current platform from `dart:io`.
  static AppPlatform current() {
    if (Platform.isWindows) {
      return AppPlatform.windows;
    }
    if (Platform.isAndroid) {
      return AppPlatform.android;
    }
    return AppPlatform.other;
  }

  String get label => switch (this) {
        AppPlatform.windows => 'Windows',
        AppPlatform.android => 'Android',
        AppPlatform.other => 'Other',
      };
}
