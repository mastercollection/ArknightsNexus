import 'package:arknight_nexus/app/app.dart';
import 'package:arknight_nexus/app/providers.dart';
import 'package:arknight_nexus/core/platform/app_platform.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/features/settings/settings_screen.dart';
import 'package:arknight_nexus/repositories/user_data_repository.dart';
import 'package:arknight_nexus/services/diagnostics_service.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:arknight_nexus/services/user_data_file_service.dart';
import 'package:arknight_nexus/services/user_data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_diagnostics_service.dart';
import '../../support/fake_image_cache_service.dart';

void main() {
  group('settings screen', () {
    late _FakeRegionSyncService regionSyncService;
    late _MemoryUserDataRepository userDataRepository;
    late FakeDiagnosticsService diagnosticsService;

    setUp(() {
      regionSyncService = _FakeRegionSyncService();
      userDataRepository = _MemoryUserDataRepository(
        const UserData(
          favorites: ['char_002_amiya'],
          selectedOperatorIds: ['char_002_amiya'],
        ),
      );
      diagnosticsService = FakeDiagnosticsService();
    });

    /// The default 800x600 test view is the medium layout: settings is the
    /// icon rail's last entry.
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('rail-settings')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    }

    /// Lets `ElMessage` toasts time out so no timers stay pending.
    Future<void> flushMessages(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    }

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('shows sync status and runs manual sync', (tester) async {
      await _pumpApp(tester, regionSyncService, userDataRepository);
      await openSettings(tester);

      expect(find.text('설정'), findsOneWidget);
      expect(find.text('지역 및 언어'), findsOneWidget);
      expect(find.text('데이터 동기화'), findsOneWidget);
      expect(find.text('KR test-version'), findsOneWidget);
      expect(find.text('· 2명'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('sync-region-button')));

      expect(regionSyncService.syncCalls, 1);
      expect(find.text('동기화를 완료했습니다.'), findsOneWidget);
      await flushMessages(tester);
      expect(find.text('동기화를 완료했습니다.'), findsNothing);
    });

    testWidgets('shows sync needed and surfaces sync errors', (tester) async {
      regionSyncService.ready = false;
      regionSyncService.failSync = true;
      await _pumpApp(tester, regionSyncService, userDataRepository);
      await openSettings(tester);

      expect(find.text('· 동기화 필요'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('sync-region-button')));

      // Error toast plus the inline error paragraph.
      expect(find.textContaining('sync exploded'), findsNWidgets(2));
      await flushMessages(tester);
      expect(find.textContaining('sync exploded'), findsOneWidget);
    });

    testWidgets('exports and imports user data through file dialogs',
        (tester) async {
      final files = _FakeUserDataFileService();
      await _pumpApp(
        tester,
        regionSyncService,
        userDataRepository,
        userDataFiles: files,
      );
      await openSettings(tester);

      // Cancelling the save dialog shows no message.
      files.saveResult = false;
      await tapVisible(
        tester,
        find.byKey(const Key('export-user-data-button')),
      );
      expect(find.text('UserData를 내보냈습니다.'), findsNothing);

      files.saveResult = true;
      await tapVisible(
        tester,
        find.byKey(const Key('export-user-data-button')),
      );
      expect(files.saved, contains('"favorites"'));
      expect(find.text('UserData를 내보냈습니다.'), findsOneWidget);
      await flushMessages(tester);

      await tapVisible(
        tester,
        find.byKey(const Key('import-user-data-button')),
      );
      // Confirmation first; cancelling never opens the file dialog.
      expect(
        find.text('현재 UserData를 백업한 뒤 가져온 파일로 덮어씁니다. 계속하시겠습니까?'),
        findsOneWidget,
      );
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(files.openCalls, 0);

      files.openResult = '{"schemaVersion":3,"favorites":["char_003_kalts"]}';
      await tapVisible(
        tester,
        find.byKey(const Key('import-user-data-button')),
      );
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(files.openCalls, 1);
      expect((await userDataRepository.read()).favorites, ['char_003_kalts']);
      expect(userDataRepository.backupData?.favorites, ['char_002_amiya']);
      expect(find.text('UserData를 가져왔습니다.'), findsOneWidget);
      await flushMessages(tester);
    });

    testWidgets('shows diagnostics and opens the desktop log folder',
        (tester) async {
      await _pumpApp(
        tester,
        regionSyncService,
        userDataRepository,
        diagnosticsService: diagnosticsService,
      );
      await openSettings(tester);

      // App version and platform sit in the about card.
      expect(
        find.textContaining('1.2.3+4', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('windows', findRichText: true),
        findsOneWidget,
      );

      expect(find.text('진단'), findsOneWidget);
      expect(find.byKey(const Key('diagnostics-logs-button')), findsNothing);
      await tapVisible(
        tester,
        find.byKey(const Key('settings-diagnostics-toggle')),
      );
      final button = find.byKey(const Key('diagnostics-logs-button'));
      await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
      await tester.pumpAndSettle();

      expect(
        find.text(
          '윈도우에서는 로그 파일이 주요 진단 자료입니다. 문제가 생기면 로그를 함께 전달해 주세요.',
        ),
        findsOneWidget,
      );
      expect(find.text('로그 폴더 열기'), findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(diagnosticsService.openFolderCalls, 1);
      expect(find.text('로그 폴더를 열었습니다.'), findsOneWidget);
      await flushMessages(tester);
    });

    testWidgets('exports the latest log on Android', (tester) async {
      final android = FakeDiagnosticsService(
        summary: const DiagnosticsSummary(
          appVersion: '1.2.3+4',
          platform: AppPlatform.android,
          logFilePath: '/data/logs/app.log',
        ),
      );
      await _pumpApp(
        tester,
        regionSyncService,
        userDataRepository,
        diagnosticsService: android,
      );
      await openSettings(tester);
      await tapVisible(
        tester,
        find.byKey(const Key('settings-diagnostics-toggle')),
      );

      expect(find.text('최신 로그 내보내기'), findsOneWidget);
      await tapVisible(
        tester,
        find.byKey(const Key('diagnostics-logs-button')),
      );

      expect(android.exportCalls, 1);
      expect(
        find.text('최신 로그를 Downloads/diagnostics-export.log 로 내보냈습니다.'),
        findsOneWidget,
      );
      await flushMessages(tester);
    });

    testWidgets('the web build has no log file controls', (tester) async {
      final web = FakeDiagnosticsService(
        summary: const DiagnosticsSummary(
          appVersion: '1.2.3',
          platform: AppPlatform.web,
          logFilePath: '',
        ),
      );
      await _pumpApp(
        tester,
        regionSyncService,
        userDataRepository,
        diagnosticsService: web,
      );
      await openSettings(tester);
      await tapVisible(
        tester,
        find.byKey(const Key('settings-diagnostics-toggle')),
      );

      expect(find.byKey(const Key('diagnostics-logs-button')), findsNothing);
      expect(find.byKey(const Key('diagnostics-copy-path')), findsNothing);
      expect(find.text('로그 폴더'), findsNothing);
      expect(
        find.text('웹 버전은 로그 파일 없이 브라우저 개발자 도구의 콘솔에 기록합니다.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('이 브라우저에 저장됩니다', findRichText: true),
        findsOneWidget,
      );
      // The data buttons stay: export downloads, import picks a file.
      expect(find.byKey(const Key('export-user-data-button')), findsOneWidget);
      expect(find.byKey(const Key('import-user-data-button')), findsOneWidget);
    });
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  RegionSyncService regionSyncService,
  UserDataRepository userDataRepository, {
  FakeImageCacheService? imageCacheService,
  FakeDiagnosticsService? diagnosticsService,
  UserDataFileService? userDataFiles,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        regionSyncServiceProvider.overrideWithValue(regionSyncService),
        userDataServiceProvider.overrideWithValue(
          UserDataService(userDataRepository),
        ),
        imageCacheServiceProvider.overrideWithValue(
          imageCacheService ?? FakeImageCacheService(),
        ),
        diagnosticsServiceProvider.overrideWithValue(
          diagnosticsService ?? FakeDiagnosticsService(),
        ),
        userDataFileServiceProvider.overrideWithValue(
          userDataFiles ?? _FakeUserDataFileService(),
        ),
      ],
      child: const ArknightNexusApp(),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeRegionSyncService implements RegionSyncService {
  int syncCalls = 0;
  bool ready = true;
  bool failSync = false;

  RegionSyncStatus get _status => RegionSyncStatus(
        region: RegionCode.kr,
        sourceRevision: 'main',
        sourceVersion: 'test-version',
        fetchedAt: '2026-05-17T00:00:00Z',
        operatorCount: 2,
        isReady: ready,
      );

  @override
  Future<SyncResult> ensureRegionFresh(RegionCode region) async {
    return SyncResult(
      region: region,
      sourceRevision: 'main',
      sourceVersion: 'test-version',
      updatedAt: '2026-05-17T00:00:00Z',
      operatorCount: 2,
      status: 'ready',
    );
  }

  @override
  Future<RegionSyncStatus?> getRegionSyncStatus(RegionCode region) async {
    return _status;
  }

  @override
  Future<Map<String, String>> getRegionStageCodes(RegionCode region) async {
    return const {};
  }

  @override
  Future<Map<String, String>> getRegionTerms(RegionCode region) async {
    return const {};
  }

  @override
  Stream<SyncStatus> syncRegion(RegionCode region) async* {
    syncCalls += 1;
    yield SyncStatus(region: region, phase: SyncPhase.checkingVersion);
    if (failSync) {
      throw StateError('sync exploded');
    }
    ready = true;
    yield SyncStatus(
      region: region,
      phase: SyncPhase.complete,
      remoteVersion: 'synced-version',
    );
  }
}

class _MemoryUserDataRepository implements UserDataRepository {
  _MemoryUserDataRepository(this.data);

  UserData data;
  UserData? backupData;

  @override
  Future<void> backup() async {
    backupData = data;
  }

  @override
  Future<UserData> read() async => data;

  @override
  Future<void> write(UserData data) async {
    this.data = data;
  }
}

class _FakeUserDataFileService implements UserDataFileService {
  bool saveResult = true;
  String? saved;
  String? openResult;
  int openCalls = 0;

  @override
  Future<bool> saveJson(
    String content, {
    String fileName = 'user_data.json',
  }) async {
    if (saveResult) {
      saved = content;
    }
    return saveResult;
  }

  @override
  Future<String?> openJson() async {
    openCalls++;
    return openResult;
  }
}
