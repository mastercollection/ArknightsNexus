import 'dart:io';

import 'package:arknight_nexus/core/platform/app_platform.dart';
import 'package:arknight_nexus/services/diagnostics_service.dart';

/// Deterministic [DiagnosticsService] for widget tests.
class FakeDiagnosticsService implements DiagnosticsService {
  FakeDiagnosticsService({
    this.summary = const DiagnosticsSummary(
      appVersion: '1.2.3+4',
      platform: AppPlatform.windows,
      logFilePath: r'C:\logs\app.log',
    ),
    this.recentLog = 'sample log line',
  });

  final DiagnosticsSummary summary;
  final String recentLog;

  int exportCalls = 0;
  int openFolderCalls = 0;

  @override
  Future<DiagnosticsSummary> getSummary() async => summary;

  @override
  Future<String> readRecentLog({int maxLines = 200}) async => recentLog;

  @override
  Future<String> exportLog() async {
    exportCalls += 1;
    return '${Directory.systemTemp.path}/diagnostics-export.log';
  }

  @override
  Future<void> openLogFolder() async {
    openFolderCalls += 1;
  }
}
