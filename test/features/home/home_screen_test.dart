import 'dart:async';

import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/features/home/home_sidebar_panel.dart';
import 'package:arknight_nexus/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_test_support.dart';

void main() {
  group('home layout', () {
    testWidgets('phone: header, search, plan, tiles, notice', (tester) async {
      await pumpHomeArea(tester, size: phoneSize);
      expectNoErrors(tester);

      expect(find.text('Arknights Nexus'), findsOneWidget);
      // Region + sync stay reachable in the phone header.
      final sync = find.byKey(const Key('home-sync-button'));
      expect(sync, findsOneWidget);
      expect(tester.getSize(sync).height, greaterThanOrEqualTo(44));
      expect(find.byKey(const Key('region-select')), findsOneWidget);
      expect(find.text('KR'), findsOneWidget);
      expect(find.text('KR 데이터 · 준비됨 · 415명'), findsOneWidget);

      expect(find.byKey(const Key('home-search-field')), findsOneWidget);
      expect(find.byKey(const Key('home-search-button')), findsOneWidget);
      expect(find.text('육성 계획 요약'), findsOneWidget);
      expect(find.text('아직 육성 계획에 오퍼레이터가 없습니다.'), findsOneWidget);
      for (final id in ['operators', 'plan', 'items', 'enemies']) {
        expect(find.byKey(Key('home-menu-$id')), findsOneWidget);
      }
      expect(find.text('준비중'), findsOneWidget);
      // The shell's bottom tabs, not a sidebar.
      expect(find.byKey(const Key('tab-home')), findsOneWidget);
      expect(find.byType(HomeSidebarPanel), findsNothing);

      await tester.scrollUntilVisible(
        find.text('비공식 팬 프로젝트'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('비공식 팬 프로젝트'), findsOneWidget);
      expectNoErrors(tester);
    });

    testWidgets('desktop: sidebar panel and main column', (tester) async {
      await pumpHomeArea(tester, size: desktopSize);
      expectNoErrors(tester);

      expect(find.byType(HomeSidebarPanel), findsOneWidget);
      expect(find.text('데이터 지역 · 언어'), findsOneWidget);
      expect(find.text('KR · 한국어'), findsOneWidget);
      expect(find.text('준비됨 · 415명'), findsOneWidget);
      expect(find.text('새로고침'), findsOneWidget);
      expect(find.byKey(const Key('home-sidebar-settings')), findsOneWidget);

      expect(find.text('Enter'), findsOneWidget);
      expect(find.text('바로가기'), findsOneWidget);
      expect(find.text('비공식 팬 프로젝트'), findsOneWidget);
    });

    testWidgets('medium: region and sync in the page, tiles in view',
        (tester) async {
      final router = await pumpHomeArea(tester, size: const Size(800, 600));
      expectNoErrors(tester);

      expect(find.byKey(const Key('region-select')), findsOneWidget);
      expect(find.byKey(const Key('home-sync-button')), findsOneWidget);
      expect(find.byType(HomeSidebarPanel), findsNothing);

      // Other areas' tests open their page from these tiles at 800x600.
      for (final id in ['operators', 'plan', 'items', 'enemies']) {
        expect(
          tester.getCenter(find.byKey(Key('home-menu-$id'))).dy,
          lessThan(600),
        );
      }
      await tester.tap(find.byKey(const Key('home-menu-items')));
      await tester.pumpAndSettle();
      expect(find.text('stub items'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-menu-operators')));
      await tester.pumpAndSettle();
      expect(find.text('stub operators:'), findsOneWidget);
    });
  });

  group('home behaviour', () {
    testWidgets('Enter in the search opens operators with ?q=', (tester) async {
      await pumpHomeArea(tester, size: phoneSize);

      await tester.enterText(find.byType(TextField), '  amiya ');
      await tester.pump();
      expect(find.text('“amiya” 오퍼레이터 검색'), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('stub operators:amiya'), findsOneWidget);
    });

    testWidgets('search button with no keyword opens the full list',
        (tester) async {
      await pumpHomeArea(tester, size: desktopSize);

      await tester.tap(find.byKey(const Key('home-search-button')));
      await tester.pumpAndSettle();
      expect(find.text('stub operators:'), findsOneWidget);
    });

    testWidgets('menu tiles push their page; the pending tile is inert',
        (tester) async {
      final router = await pumpHomeArea(tester, size: desktopSize);

      await tester.tap(find.byKey(const Key('home-menu-enemies')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-menu-enemies')), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-menu-items')));
      await tester.pumpAndSettle();
      expect(find.text('stub items'), findsOneWidget);
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
      expect(find.text('Ready · 415 operators'), findsOneWidget);
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

      expect(find.text('준비됨 · 415명'), findsOneWidget);
      expect(sync.ensureCalls, 1);
    });

    testWidgets('force sync runs and shows its error', (tester) async {
      final sync = HomeFakeRegionSyncService()
        ..ready = false
        ..failSync = true;
      await pumpHomeArea(tester, size: phoneSize, regionSync: sync);
      expect(find.text('KR 데이터 · 동기화 필요'), findsOneWidget);

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
      expect(find.text('KR 데이터 · 준비됨 · 415명'), findsOneWidget);
    });

    testWidgets('sidebar sync and settings link (desktop)', (tester) async {
      final sync = HomeFakeRegionSyncService()..ready = false;
      await pumpHomeArea(tester, size: desktopSize, regionSync: sync);
      expect(find.text('동기화 필요'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-sync-button')));
      await tester.pumpAndSettle();
      expect(sync.syncCalls, 1);
      expect(find.text('준비됨 · 415명'), findsOneWidget);

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
      expect(find.text('계획 중인 오퍼레이터'), findsOneWidget);
      expect(find.text('Mon3tr'), findsOneWidget);
      expect(find.text('E0 Lv.1 → E1 Lv.1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-planned-char_x')));
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
      expect(find.text('Mon3tr'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-open-plan')));
      await tester.pumpAndSettle();
      expect(find.text('stub plan'), findsOneWidget);
    });
  });
}
