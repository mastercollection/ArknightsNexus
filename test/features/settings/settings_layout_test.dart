import 'package:arknight_nexus/core/platform/app_platform.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/services/diagnostics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_diagnostics_service.dart';
import '../home/home_test_support.dart';

void main() {
  group('settings layout', () {
    for (final (name, size) in [
      ('phone', phoneSize),
      ('desktop', desktopSize),
    ]) {
      testWidgets('$name: every card and control is present', (tester) async {
        await pumpHomeArea(tester, size: size, initialLocation: '/settings');
        expectNoErrors(tester);

        expect(find.text('홈 설정'), findsOneWidget);
        expect(find.byKey(const Key('settings-back')), findsOneWidget);
        final refresh = find.byKey(const Key('settings-topbar-sync'));
        expect(refresh, findsOneWidget);
        expect(tester.getSize(refresh).height, greaterThanOrEqualTo(44));
        expect(find.text('지역 및 언어'), findsOneWidget);
        expect(find.byKey(const Key('region-select')), findsOneWidget);
        expect(find.text('KR · 한국어'), findsOneWidget);
        expect(find.text('현재 동기화 상태'), findsOneWidget);
        expect(find.text('· KR'), findsOneWidget);
        for (final key in [
          'sync-region-button',
          'export-user-data-button',
          'import-user-data-button',
          'diagnostics-logs-button',
        ]) {
          final button = find.byKey(Key(key));
          expect(button, findsOneWidget);
          expect(
            tester.getSize(button).height,
            greaterThanOrEqualTo(size == phoneSize ? 48 : 44),
          );
        }
        // No shell sidebar on settings; phones keep the bottom tabs.
        expect(
          find.byKey(const Key('tab-settings')),
          size == phoneSize ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('back returns home', (tester) async {
      await pumpHomeArea(tester, size: phoneSize, initialLocation: '/settings');
      await tester.tap(find.byKey(const Key('settings-back')));
      await tester.pumpAndSettle();
      expect(find.text('Arknights Nexus'), findsOneWidget);
    });

    testWidgets('region select reloads the sync status in the new language',
        (tester) async {
      final sync = HomeFakeRegionSyncService();
      await pumpHomeArea(
        tester,
        size: desktopSize,
        regionSync: sync,
        initialLocation: '/settings',
      );

      await tester.tap(find.byKey(const Key('region-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JP · 日本語').last);
      await tester.pumpAndSettle();

      expect(sync.statusRegions.last, RegionCode.jp);
      expect(find.text('· JP'), findsOneWidget);
      expect(find.text('JP · 日本語'), findsOneWidget);
    });

    testWidgets('failed log folder open shows the path in an alert',
        (tester) async {
      final diagnostics = _FailingDiagnostics();
      await pumpHomeArea(
        tester,
        size: desktopSize,
        diagnostics: diagnostics,
        initialLocation: '/settings',
      );

      await tester.tap(find.byKey(const Key('diagnostics-logs-button')));
      await tester.pumpAndSettle();

      expect(find.text('로그 폴더를 열지 못했습니다. 아래 경로를 확인해 주세요.'), findsOneWidget);
      // Once in the card, once in the alert.
      expect(find.text(r'C:\logs'), findsNWidgets(2));
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('로그 폴더를 열지 못했습니다. 아래 경로를 확인해 주세요.'), findsNothing);
    });
  });
}

class _FailingDiagnostics extends FakeDiagnosticsService {
  _FailingDiagnostics()
      : super(
          summary: const DiagnosticsSummary(
            appVersion: '1.2.3+4',
            platform: AppPlatform.windows,
            logFilePath: r'C:\logs\app.log',
          ),
        );

  @override
  Future<void> openLogFolder() async {
    await super.openLogFolder();
    throw StateError('no shell');
  }
}
