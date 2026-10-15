import 'package:package_info_plus/package_info_plus.dart';

import '../core/platform/app_platform.dart';

/// A snapshot of diagnostic environment details shown in settings.
class DiagnosticsSummary {
  const DiagnosticsSummary({
    required this.appVersion,
    required this.platform,
    required this.logFilePath,
  });

  final String appVersion;
  final AppPlatform platform;

  /// Empty where the app keeps no log file (the web build).
  final String logFilePath;
}

abstract interface class DiagnosticsService {
  /// Collects app version, platform, and log file location.
  Future<DiagnosticsSummary> getSummary();

  /// Reads the tail of the current log file, up to [maxLines] lines.
  Future<String> readRecentLog({int maxLines});

  /// Copies the current log file to a user-retrievable export file and returns
  /// its path. Throws [StateError] when there is no log to export.
  Future<String> exportLog();

  /// Opens the log folder in the desktop file manager. Throws
  /// [UnsupportedError] on platforms without a desktop log folder.
  Future<void> openLogFolder();
}

typedef AppVersionReader = Future<String> Function();

/// The app version without a build number (Tauri's `getVersion()`).
Future<String> packageInfoVersion() async {
  return (await PackageInfo.fromPlatform()).version;
}

const unknownAppVersion = 'unknown';

/// [DiagnosticsService] of the web build: the log goes to the browser
/// console, so there is no file to show, export or open.
class BrowserDiagnosticsService implements DiagnosticsService {
  const BrowserDiagnosticsService({
    AppVersionReader versionReader = packageInfoVersion,
  }) : _versionReader = versionReader;

  final AppVersionReader _versionReader;

  @override
  Future<DiagnosticsSummary> getSummary() async {
    String version;
    try {
      version = await _versionReader();
    } catch (_) {
      version = unknownAppVersion;
    }
    return DiagnosticsSummary(
      appVersion: version,
      platform: AppPlatform.web,
      logFilePath: '',
    );
  }

  @override
  Future<String> readRecentLog({int maxLines = 200}) async => '';

  @override
  Future<String> exportLog() {
    throw UnsupportedError('The web version keeps no log file.');
  }

  @override
  Future<void> openLogFolder() {
    throw UnsupportedError('The web version keeps no log folder.');
  }
}
