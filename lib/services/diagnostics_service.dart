import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;

import '../core/logging/file_app_logger.dart';
import '../core/platform/app_platform.dart';
import '../core/storage/app_directories.dart';

/// A snapshot of diagnostic environment details shown in settings.
class DiagnosticsSummary {
  const DiagnosticsSummary({
    required this.appVersion,
    required this.platform,
    required this.logFilePath,
  });

  final String appVersion;
  final AppPlatform platform;
  final String logFilePath;
}

abstract interface class DiagnosticsService {
  /// Collects app version, platform, and log file location.
  Future<DiagnosticsSummary> getSummary();

  /// Reads the tail of the current log file, up to [maxLines] lines.
  Future<String> readRecentLog({int maxLines});

  /// Copies the current log file to a user-retrievable export file and returns
  /// it. Throws [StateError] when there is no log to export.
  Future<File> exportLog();

  /// Opens the log folder in the desktop file manager. Throws
  /// [UnsupportedError] on platforms without a desktop log folder.
  Future<void> openLogFolder();
}

typedef AppVersionReader = Future<String> Function();

/// Resolves the user-visible folder log exports are copied to (the Tauri app
/// copies into the platform Downloads folder). Returns null when unavailable.
typedef ExportDirectoryResolver = Future<Directory?> Function();

Future<Directory?> _downloadsDirectory() async {
  try {
    return await path_provider.getDownloadsDirectory();
  } catch (_) {
    return null;
  }
}

Future<String> _packageInfoVersion() async {
  // Tauri's `getVersion()` reports the semver only, without a build number.
  return (await PackageInfo.fromPlatform()).version;
}

class DartDiagnosticsService implements DiagnosticsService {
  DartDiagnosticsService({
    required AppDirectories directories,
    required FileAppLogger logger,
    AppPlatform? platform,
    AppVersionReader versionReader = _packageInfoVersion,
    ExportDirectoryResolver exportDirectory = _downloadsDirectory,
  })  : _directories = directories,
        _exportDirectory = exportDirectory,
        _logger = logger,
        _platform = platform ?? AppPlatform.current(),
        _versionReader = versionReader;

  static const String _unknownVersion = 'unknown';

  final AppDirectories _directories;
  final FileAppLogger _logger;
  final AppPlatform _platform;
  final AppVersionReader _versionReader;
  final ExportDirectoryResolver _exportDirectory;

  @override
  Future<DiagnosticsSummary> getSummary() async {
    String version;
    try {
      version = await _versionReader();
    } catch (_) {
      version = _unknownVersion;
    }
    return DiagnosticsSummary(
      appVersion: version,
      platform: _platform,
      logFilePath: await _logger.logFilePath(),
    );
  }

  @override
  Future<String> readRecentLog({int maxLines = 200}) async {
    final file = File(await _logger.logFilePath());
    if (!await file.exists()) {
      return '';
    }
    final lines = await file.readAsLines();
    if (lines.length <= maxLines) {
      return lines.join('\n');
    }
    return lines.sublist(lines.length - maxLines).join('\n');
  }

  @override
  Future<File> exportLog() async {
    final source = File(await _logger.logFilePath());
    if (!await source.exists()) {
      throw StateError('내보낼 로그 파일이 없습니다.');
    }
    // `diagnostics-${Date.now()}.log` in the Tauri app.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final downloads = await _exportDirectory();
    final exportRoot = downloads ?? await _directories.userDataRoot();
    await exportRoot.create(recursive: true);
    final target = p.join(exportRoot.path, 'diagnostics-$stamp.log');
    return source.copy(target);
  }

  @override
  Future<void> openLogFolder() async {
    if (!_platform.supportsDesktopLogFolder) {
      throw UnsupportedError('이 플랫폼에서는 로그 폴더 열기를 지원하지 않습니다.');
    }
    final root = await _directories.logRoot();
    await Process.run('explorer.exe', [root.path]);
  }
}
