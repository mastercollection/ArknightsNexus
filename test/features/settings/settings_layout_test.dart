import 'package:arknight_nexus/core/platform/app_platform.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/features/shared/region_data_label.dart';
import 'package:arknight_nexus/services/diagnostics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

        // "설정" alone (the phone tab bar repeats it), no subtitle.
        expect(find.text('설정'), findsNWidgets(size == phoneSize ? 2 : 1));
        expect(find.text('홈 설정'), findsNothing);
        expect(find.text('앱 유지보수와 진단 정보를 한 곳에서 관리합니다.'), findsNothing);
        // A section root: no back button on any width.
        expect(find.byKey(const Key('settings-back')), findsNothing);
        expect(find.text('지역 및 언어'), findsOneWidget);
        expect(find.byKey(const Key('region-select')), findsOneWidget);
        expect(find.text('KR · 한국어'), findsOneWidget);
        expect(find.text('데이터 동기화'), findsOneWidget);
        expect(find.text('KR 52.0.0'), findsOneWidget);
        expect(find.text('· 415명'), findsOneWidget);
        expect(
          find.text('마지막 동기화 ${formatSyncTime(homeFetchedAt)}'),
          findsOneWidget,
        );
        expect(find.text('UserData'), findsOneWidget);
        expect(find.text('정보'), findsOneWidget);
        expect(find.text('진단'), findsOneWidget);
        // Diagnostics start collapsed.
        expect(find.byKey(const Key('diagnostics-logs-button')), findsNothing);
        await tester.ensureVisible(
          find.byKey(const Key('settings-diagnostics-toggle')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('settings-diagnostics-toggle')));
        await tester.pumpAndSettle();
        expectNoErrors(tester);
        for (final key in [
          'sync-region-button',
          'export-user-data-button',
          'import-user-data-button',
          'diagnostics-logs-button',
          'diagnostics-copy-path',
        ]) {
          final button = find.byKey(Key(key));
          expect(button, findsOneWidget);
          expect(
            tester.getSize(button).height,
            greaterThanOrEqualTo(size == phoneSize ? 48 : 44),
          );
        }
        // Two columns on a wide PC window: about sits beside the region.
        if (size == desktopSize) {
          expect(
            tester.getTopLeft(find.text('정보')).dy,
            tester.getTopLeft(find.text('지역 및 언어')).dy,
          );
        }
        // No shell sidebar on settings; phones keep the bottom tabs.
        expect(
          find.byKey(const Key('tab-settings')),
          size == phoneSize ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('system back returns home', (tester) async {
      await pumpHomeArea(tester, size: phoneSize, initialLocation: '/settings');
      await tester.binding.handlePopRoute();
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
      expect(find.text('JP 52.0.0'), findsOneWidget);
      expect(find.text('JP · 日本語'), findsOneWidget);
    });

    testWidgets('diagnostics expand on demand and copy the log path',
        (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await pumpHomeArea(
        tester,
        size: desktopSize,
        diagnostics: _FailingDiagnostics(),
        initialLocation: '/settings',
      );

      final toggle = find.byKey(const Key('settings-diagnostics-toggle'));
      expect(find.byKey(const Key('settings-diagnostics-body')), findsNothing);
      expect(
        tester.getSemantics(toggle),
        matchesSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: '진단',
        ),
      );
      // The path is behind the copy button, never printed.
      expect(find.textContaining(r'C:\logs'), findsNothing);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-diagnostics-body')),
        findsOneWidget,
      );
      expect(find.textContaining(r'C:\logs'), findsNothing);

      await tester.tap(find.byKey(const Key('diagnostics-copy-path')));
      await tester.pumpAndSettle();
      expect(copied, [r'C:\logs']);
      expect(find.text('로그 폴더 경로를 복사했습니다.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-diagnostics-body')), findsNothing);
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

      await tester.tap(find.byKey(const Key('settings-diagnostics-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('diagnostics-logs-button')));
      await tester.pumpAndSettle();

      expect(find.text('로그 폴더를 열지 못했습니다. 아래 경로를 확인해 주세요.'), findsOneWidget);
      // The card has no path line, so the alert shows it.
      expect(find.text(r'C:\logs'), findsOneWidget);
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
