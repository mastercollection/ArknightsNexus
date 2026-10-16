import 'dart:async';

import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/features/home/home_sidebar_panel.dart';
import 'package:arknight_nexus/features/settings/settings_screen.dart';
import 'package:arknight_nexus/features/shared/region_data_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_test_support.dart';

OperatorSummary _summary(String id, {String? source, int rarity = 5}) =>
    OperatorSummary(
      id: id,
      name: 'Op $id',
      rarity: rarity,
      profession: 'GUARD',
      branch: 'lord',
      thumbnailHue: 0,
      unreleasedSource: source,
    );

void main() {
  final syncTime = formatSyncTime(homeFetchedAt)!;

  group('home layout', () {
    testWidgets('phone: header, status, search, plan, notice', (tester) async {
      await pumpHomeArea(tester, size: phoneSize);
      expectNoErrors(tester);

      expect(find.text('Arknights Nexus'), findsOneWidget);
      // Region + sync stay reachable in the phone header.
      final sync = find.byKey(const Key('home-sync-button'));
      expect(sync, findsOneWidget);
      expect(tester.getSize(sync).height, greaterThanOrEqualTo(44));
      expect(find.byKey(const Key('region-select')), findsOneWidget);
      expect(find.text('KR'), findsOneWidget);
      expect(find.text('KR 52.0.0 · 415명'), findsOneWidget);
      expect(find.text(syncTime), findsOneWidget);

      // Enter submits; phones have no separate search button.
      expect(find.byKey(const Key('home-search-field')), findsOneWidget);
      expect(find.byKey(const Key('home-search-button')), findsNothing);
      expect(find.text('육성 계획 요약'), findsOneWidget);
      expect(find.text('아직 육성 계획에 오퍼레이터가 없습니다.'), findsOneWidget);
      // No shortcut tiles: the tabs are the navigation.
      expect(find.byKey(const Key('home-menu-operators')), findsNothing);
      expect(find.byKey(const Key('tab-home')), findsOneWidget);
      expect(find.byType(HomeSidebarPanel), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('home-rights-notice')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('비공식 팬 앱'), findsOneWidget);
      expectNoErrors(tester);
    });

    testWidgets('desktop: sidebar panel and data card', (tester) async {
      await pumpHomeArea(tester, size: desktopSize);
      expectNoErrors(tester);

      expect(find.byType(HomeSidebarPanel), findsOneWidget);
      expect(find.text('데이터 지역 · 언어'), findsOneWidget);
      expect(find.text('KR · 한국어'), findsOneWidget);
      expect(find.text('KR 52.0.0 · 415명'), findsOneWidget);
      expect(find.byKey(const Key('home-sidebar-settings')), findsOneWidget);

      // Data card: state, version, counts, last sync, refresh.
      expect(find.text('데이터'), findsOneWidget);
      expect(find.text('준비됨'), findsOneWidget);
      expect(find.text('KR 52.0.0'), findsOneWidget);
      expect(find.text('415명'), findsOneWidget);
      expect(find.text(syncTime), findsOneWidget);
      expect(find.text('새로고침'), findsOneWidget);
      expect(find.byKey(const Key('home-sync-button')), findsOneWidget);

      expect(find.byKey(const Key('home-search-button')), findsOneWidget);
      expect(find.text('Enter'), findsNothing);
      expect(find.text('바로가기'), findsNothing);
      expect(find.byKey(const Key('home-menu-operators')), findsNothing);
      expect(find.byKey(const Key('home-rights-notice')), findsOneWidget);
    });

    testWidgets('counts native and unreleased operators', (tester) async {
      await pumpHomeArea(
        tester,
        size: desktopSize,
        operators: HomeFakeOperatorService(
          summaries: [
            _summary('char_c', source: 'cn'),
            _summary('char_a'),
            _summary('char_b'),
          ],
        ),
      );
      expectNoErrors(tester);

      expect(find.text('KR 52.0.0 · 2명 · 미실장 1명'), findsOneWidget);
      expect(find.text('2명 · 미실장 1명'), findsOneWidget);
    });

    testWidgets('medium: region and sync in the data card, no tiles',
        (tester) async {
      await pumpHomeArea(tester, size: const Size(800, 600));
      expectNoErrors(tester);

      expect(find.byKey(const Key('region-select')), findsOneWidget);
      expect(find.byKey(const Key('home-sync-button')), findsOneWidget);
      expect(find.byType(HomeSidebarPanel), findsNothing);
      expect(find.byKey(const Key('home-menu-operators')), findsNothing);
      // The cards stack in the narrow column: data above the plan.
      expect(
        tester.getTopLeft(find.text('데이터')).dy,
        lessThan(tester.getTopLeft(find.text('육성 계획 요약')).dy),
      );
    });
  });

  group('home operator sections', () {
    final summaries = [
      _summary('char_u1', source: 'cn'),
      for (var i = 0; i < 10; i++) _summary('char_$i', rarity: 6),
      _summary('char_u2', source: 'en'),
    ];

    testWidgets('desktop: newest eight natives and the unreleased preview',
        (tester) async {
      await pumpHomeArea(
        tester,
        size: desktopSize,
        operators: HomeFakeOperatorService(summaries: summaries),
      );
      expectNoErrors(tester);

      expect(find.text('새로 실장'), findsOneWidget);
      // List order (newest first), natives only, eight on a wide window.
      for (var i = 0; i < 8; i++) {
        expect(find.byKey(Key('home-new-char_$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('home-new-char_8')), findsNothing);
      expect(find.byKey(const Key('home-new-char_u1')), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const Key('home-new-char_0'))).dx,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('home-new-char_1'))).dx,
        ),
      );

      expect(find.text('미실장 미리보기'), findsOneWidget);
      expect(find.text('2명 모두 보기'), findsOneWidget);
      expect(find.byKey(const Key('home-unreleased-char_u1')), findsOneWidget);
      expect(find.byKey(const Key('home-unreleased-char_u2')), findsOneWidget);
      expect(find.text('미실장 · CN'), findsOneWidget);
      expect(find.text('미실장 · EN'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-new-char_3')));
      await tester.pumpAndSettle();
      expect(find.text('stub operator:char_3'), findsOneWidget);
    });

    testWidgets('phone: scrollers open the operator detail', (tester) async {
      final router = await pumpHomeArea(
        tester,
        size: phoneSize,
        operators: HomeFakeOperatorService(summaries: summaries),
      );
      expectNoErrors(tester);

      final unreleased = find.byKey(const Key('home-unreleased-char_u2'));
      await tester.scrollUntilVisible(
        unreleased,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('모두 보기'), findsOneWidget);
      await tester.tap(unreleased);
      await tester.pumpAndSettle();
      expect(find.text('stub operator:char_u2'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-new-releases-all')));
      await tester.pumpAndSettle();
      expect(find.text('stub operators:'), findsOneWidget);
    });

    testWidgets('no unreleased preview when the region has none',
        (tester) async {
      await pumpHomeArea(
        tester,
        size: desktopSize,
        operators: HomeFakeOperatorService(
          summaries: [_summary('char_a'), _summary('char_b')],
        ),
      );
      expectNoErrors(tester);

      expect(find.byKey(const Key('home-new-char_a')), findsOneWidget);
      expect(find.byKey(const Key('home-unreleased-preview')), findsNothing);
      expect(find.text('미실장 미리보기'), findsNothing);
    });

    testWidgets('no operator sections before the region has data',
        (tester) async {
      await pumpHomeArea(
        tester,
        size: desktopSize,
        regionSync: HomeFakeRegionSyncService()..ready = false,
        operators: HomeFakeOperatorService(summaries: summaries),
      );
      expectNoErrors(tester);

      expect(find.byKey(const Key('home-new-releases')), findsNothing);
      expect(find.byKey(const Key('home-unreleased-preview')), findsNothing);
    });
  });

  group('home behaviour', () {
    testWidgets('Enter in the search opens operators with ?q=', (tester) async {
      await pumpHomeArea(tester, size: phoneSize);

      await tester.enterText(find.byType(TextField), '  amiya ');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('stub operators:amiya'), findsOneWidget);
    });

    testWidgets('search button with no keyword opens the full list',
        (tester) async {
      final router = await pumpHomeArea(tester, size: desktopSize);

      await tester.tap(find.byKey(const Key('home-search-button')));
      await tester.pumpAndSettle();
      expect(find.text('stub operators:'), findsOneWidget);
      // Pushed, so back returns home.
      expect(router.canPop(), isTrue);
    });

    testWidgets('region select switches language and reloads data',
        (tester) async {
      final sync = HomeFakeRegionSyncService();
      await pumpHomeArea(tester, size: desktopSize, regionSync: sync);
      expect(sync.statusRegions, [RegionCode.kr]);

      await tester.tap(find.byKey(const Key('region-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EN · English').last);
      await tester.pumpAndSettle();

      expect(find.text('Operators'), findsWidgets);
      expect(find.text('EN · English'), findsOneWidget);
      expect(find.text('EN 52.0.0 · 415 operators'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(sync.statusRegions.last, RegionCode.en);
    });

    testWidgets('downloads the region on start and shows it as syncing',
        (tester) async {
      final sync = HomeFakeRegionSyncService()
        ..ready = false
        ..ensureGate = Completer<void>();
      await pumpHomeArea(
        tester,
        size: desktopSize,
        regionSync: sync,
        settle: false,
      );
      await tester.pump();

      expect(sync.ensureCalls, 1);
      expect(find.text('동기화 중…'), findsOneWidget);

      sync.ensureGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('준비됨'), findsOneWidget);
      expect(find.text('KR 52.0.0 · 415명'), findsOneWidget);
      expect(sync.ensureCalls, 1);
    });

    testWidgets('force sync runs and shows its error', (tester) async {
      final sync = HomeFakeRegionSyncService()
        ..ready = false
        ..failSync = true;
      await pumpHomeArea(tester, size: phoneSize, regionSync: sync);
      expect(find.text('KR · 동기화 필요'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-sync-button')));
      await tester.pumpAndSettle();
      expect(sync.syncCalls, 1);
      expect(find.textContaining('sync exploded'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      sync.failSync = false;
      await tester.tap(find.byKey(const Key('home-sync-button')));
      await tester.pumpAndSettle();
      expect(sync.syncCalls, 2);
      expect(find.text('KR 52.0.0 · 415명'), findsOneWidget);
    });

    testWidgets('data card refresh and sidebar settings link (desktop)',
        (tester) async {
      final sync = HomeFakeRegionSyncService()..ready = false;
      await pumpHomeArea(tester, size: desktopSize, regionSync: sync);
      expect(find.text('동기화 필요'), findsOneWidget);
      expect(find.text('KR · 동기화 필요'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-sync-button')));
      await tester.pumpAndSettle();
      expect(sync.syncCalls, 1);
      expect(find.text('준비됨'), findsOneWidget);
      expect(find.text('KR 52.0.0 · 415명'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-sidebar-settings')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('plan summary is computed from the real plan', (tester) async {
      await pumpHomeArea(
        tester,
        size: desktopSize,
        operators: HomeFakeOperatorService(
          details: [homeOperatorDetail('char_x', 'Mon3tr')],
        ),
        items: HomeFakeItemService(items: [homeLmdItem(owned: 60)]),
        userData: HomeMemoryUserDataRepository(
          UserData(
            selectedOperatorIds: const ['char_x', 'char_missing'],
            operatorPlans: [homePlan('char_x')],
          ),
        ),
      );
      expectNoErrors(tester);

      // E0 Lv.1 → E1: EXP 100+200+300, LMD 10+20+30 + 1000 promotion.
      expect(find.text('600'), findsOneWidget);
      expect(find.text('1,060'), findsOneWidget);
      expect(
        find.text('용문폐 부족 1,000 · CE-6 1회 · LS-6 1회 · 이성 72'),
        findsOneWidget,
      );
      final planned = find.byKey(const Key('home-planned-char_x'));
      expect(
        find.descendant(of: planned, matching: find.text('Mon3tr')),
        findsOneWidget,
      );
      expect(find.text('E0 Lv.1 → E1 Lv.1'), findsOneWidget);

      await tester.tap(planned);
      await tester.pumpAndSettle();
      expect(find.text('stub plan:char_x'), findsOneWidget);
    });

    testWidgets('plan summary on the phone keeps the planned operator',
        (tester) async {
      await pumpHomeArea(
        tester,
        size: phoneSize,
        operators: HomeFakeOperatorService(
          details: [homeOperatorDetail('char_x', 'Mon3tr')],
        ),
        items: HomeFakeItemService(items: [homeLmdItem()]),
        userData: HomeMemoryUserDataRepository(
          UserData(
            selectedOperatorIds: const ['char_x'],
            operatorPlans: [homePlan('char_x')],
          ),
        ),
      );
      expectNoErrors(tester);
      expect(find.text('필요 EXP'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('home-planned-char_x')),
          matching: find.text('Mon3tr'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('home-open-plan')));
      await tester.pumpAndSettle();
      expect(find.text('stub plan'), findsOneWidget);
    });
  });
}
