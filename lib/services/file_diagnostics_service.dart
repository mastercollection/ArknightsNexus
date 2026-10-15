import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;

import '../core/logging/file_app_logger.dart';
import '../core/platform/app_platform.dart';
import '../core/storage/app_directories.dart';
import 'diagnostics_service.dart';

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

/// [DiagnosticsService] for native builds, over the log file that
/// [FileAppLogger] writes.
class DartDiagnosticsService implements DiagnosticsService {
  DartDiagnosticsService({
    required AppDirectories directories,
    required FileAppLogger logger,
    AppPlatform? platform,
    AppVersionReader versionReader = packageInfoVersion,
    ExportDirectoryResolver exportDirectory = _downloadsDirectory,
  })  : _directories = directories,
        _exportDirectory = exportDirectory,
        _logger = logger,
        _platform = platform ?? AppPlatform.current(),
        _versionReader = versionReader;

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
      version = unknownAppVersion;
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
  Future<String> exportLog() async {
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
    return (await source.copy(target)).path;
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
