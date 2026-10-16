import 'package:arknight_nexus/app/app.dart';
import 'package:arknight_nexus/app/providers.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/features/operators/operator_detail_screen.dart';
import 'package:arknight_nexus/features/operators/operators_screen.dart';
import 'package:arknight_nexus/features/operators/operators_workspace.dart';
import 'package:arknight_nexus/i18n/nexus_i18n.dart';
import 'package:arknight_nexus/repositories/user_data_repository.dart';
import 'package:arknight_nexus/services/operator_service.dart';
import 'package:arknight_nexus/services/region_readiness.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:arknight_nexus/services/user_data_service.dart';
import 'package:arknight_nexus/ui/redesign/rd_widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_image_cache_service.dart';
import '../../support/noop_app_logger.dart';

final rarityTitle =
    const NexusI18n(RegionCode.kr).t('operatorsList.filters.rarity');

void main() {
  group('operator screens', () {
    late _FakeOperatorService operatorService;
    late _FakeRegionSyncService regionSyncService;
    late _MemoryUserDataRepository userDataRepository;

    setUp(() {
      operatorService = _FakeOperatorService();
      regionSyncService = _FakeRegionSyncService(operatorService);
      userDataRepository = _MemoryUserDataRepository();
    });

    testWidgets('lists cached operators and filters by search text',
        (tester) async {
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );

      await tester.tap(find.byKey(const Key('rail-operators')));
      await tester.pumpAndSettle();

      expect(find.byType(OperatorsScreen), findsOneWidget);
      expect(find.text('오퍼레이터 목록'), findsOneWidget);
      expect(find.text('Amiya'), findsOneWidget);
      expect(find.text('Kaltsit'), findsOneWidget);
      // Star overlay renders the rarity.
      expect(find.text('★★★★★★'), findsOneWidget);

      // Local search matches name, profession, and affiliations.
      await tester.enterText(find.byType(TextField), 'Medical');
      await tester.pumpAndSettle();

      expect(find.text('Amiya'), findsNothing);
      expect(find.text('Kaltsit'), findsOneWidget);
      expect(find.text('검색: Medical'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pumpAndSettle();

      expect(find.text('조건에 맞는 오퍼레이터가 없습니다.'), findsOneWidget);
    });

    testWidgets('applies the ?q= query from the home search', (tester) async {
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );

      await tester.enterText(find.byType(TextField), 'Kaltsit');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(OperatorsScreen), findsOneWidget);
      expect(find.text('검색: Kaltsit'), findsOneWidget);
      expect(find.text('Amiya'), findsNothing);
      expect(find.text('Kaltsit'), findsWidgets);
    });

    testWidgets('filters from the filter sheets and resets', (tester) async {
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );

      await tester.tap(find.byKey(const Key('rail-operators')));
      await tester.pumpAndSettle();

      // The filter button opens the sheet with one row per dimension.
      await tester.tap(find.byKey(const Key('operators-filter-button')));
      await tester.pumpAndSettle();
      expect(find.text('목록 필터'), findsOneWidget);

      await tester.tap(find.byKey(const Key('operators-filter-row-rarity')));
      await tester.pumpAndSettle();
      // Single-value dimensions apply and close on a pick.
      await tester
          .tap(find.byKey(const ValueKey('operators-filter-option-6 ★')));
      await tester.pumpAndSettle();
      expect(find.text('목록 필터'), findsNothing);

      // The BA tag chip opens the multi-select sheet directly.
      await tester.tap(find.byKey(const Key('operators-filter-ba-tags')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('operators-filter-option-Healing')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('operators-filter-sheet-apply')));
      await tester.pumpAndSettle();

      expect(find.text('Amiya'), findsNothing);
      expect(find.text('Kaltsit'), findsOneWidget);
      expect(find.text('$rarityTitle: 6 ★'), findsOneWidget);
      expect(find.text('용어 태그: Healing'), findsOneWidget);

      await tester.tap(find.byKey(const Key('operators-filter-button')));
      await tester.pumpAndSettle();
      final reset = find.byKey(const Key('operators-filter-reset'));
      await tester.ensureVisible(reset);
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.text('Amiya'), findsOneWidget);
      expect(find.text('Kaltsit'), findsOneWidget);
      expect(find.text('$rarityTitle: 6 ★'), findsNothing);
    });

    testWidgets('a set dimension chip clears that filter', (tester) async {
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );
      await tester.tap(find.byKey(const Key('rail-operators')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('operators-filter-affiliation')));
      await tester.pumpAndSettle();
      // The affiliation sheet is searchable.
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'medical',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('operators-filter-option-Rhodes Island')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(
          const ValueKey('operators-filter-option-Medical Department'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Amiya'), findsNothing);

      await tester.tap(find.byKey(const Key('operators-filter-affiliation')));
      await tester.pumpAndSettle();
      expect(find.text('Amiya'), findsOneWidget);
    });

    testWidgets('search matches the translated profession', (tester) async {
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );
      await tester.tap(find.byKey(const Key('rail-operators')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        const NexusI18n(RegionCode.kr).profession('MEDIC'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Amiya'), findsNothing);
      expect(find.text('Kaltsit'), findsOneWidget);
    });

    testWidgets('PC master-detail: list selection fills the detail pane',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );
      await tester.tap(find.byKey(const Key('sidebar-operators')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Sidebar filters, list and the empty detail pane.
      expect(find.byKey(const Key('operators-filter-reset')), findsOneWidget);
      expect(
        find.text(const NexusI18n(RegionCode.kr).t('rd.operators.detail.none')),
        findsOneWidget,
      );

      await tester
          .tap(find.byKey(const ValueKey('operators-filter-rarity-6 ★')));
      await tester.pumpAndSettle();
      expect(find.text('Amiya'), findsNothing);
      await tester.tap(find.byKey(const Key('operators-filter-reset')));
      await tester.pumpAndSettle();
      expect(find.text('Amiya'), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('operator-tile-char_003_kalts')));
      await tester.pump();
      // No page transition: the selected workspace replaces the other at once.
      expect(find.byType(OperatorDetailScreen), findsOneWidget);
      expect(find.byType(OperatorsScreen), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // List stays; the pane shows the operator (tile + hero name).
      expect(find.byType(OperatorDetailScreen), findsOneWidget);
      expect(find.text('Amiya'), findsOneWidget);
      expect(find.text('Doctor.'), findsOneWidget);
      expect(find.text('Kaltsit'), findsNWidgets(2));

      // Another tile switches the pane in place.
      await tester
          .tap(find.byKey(const ValueKey('operator-tile-char_002_amiya')));
      await tester.pumpAndSettle();
      expect(find.text('Leader'), findsOneWidget);

      // The pane's close button deselects.
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(OperatorsScreen), findsOneWidget);
      expect(find.text('Leader'), findsNothing);
    });

    testWidgets('PC detail pane resizes by dragging its border',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );
      await tester.tap(find.byKey(const Key('sidebar-operators')));
      await tester.pumpAndSettle();

      final handle = find.byKey(const Key('operator-detail-resize'));
      double paneLeft() => tester.getCenter(handle).dx;
      final initial = paneLeft();

      // Dragging the border left widens the pane.
      await tester.drag(
        handle,
        const Offset(-200, 0),
        kind: PointerDeviceKind.mouse,
        touchSlopX: 0,
      );
      await tester.pumpAndSettle();
      expect(paneLeft(), closeTo(initial - 200, 3));

      // The list keeps a minimum width however far the border goes.
      await tester.drag(
        handle,
        const Offset(-2000, 0),
        kind: PointerDeviceKind.mouse,
        touchSlopX: 0,
      );
      await tester.pumpAndSettle();
      expect(paneLeft(), greaterThan(76 + 240 + 300));
      expect(tester.takeException(), isNull);

      // The width survives leaving and reopening the section.
      final widened = paneLeft();
      await tester.tap(find.byKey(const Key('rail-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sidebar-operators')));
      await tester.pumpAndSettle();
      expect(paneLeft(), closeTo(widened, 1));

      // Double-click restores the initial width.
      await tester.tap(handle);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(handle);
      await tester.pumpAndSettle();
      expect(paneLeft(), closeTo(initial, 1));

      // The border stays under the cursor when several moves arrive before a
      // frame, and after the drag has run into a limit and come back.
      final gesture = await tester.startGesture(
        tester.getCenter(handle),
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(-20, 0));
      }
      await tester.pump();
      expect(paneLeft(), closeTo(initial - 100, 1));
      await gesture.moveBy(const Offset(-2000, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(2000, 0));
      await tester.pump();
      expect(paneLeft(), closeTo(initial - 100, 1));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('PC sidebar wraps long option lists and builds them on scroll',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      operatorService._operators = [
        for (var i = 0; i < 40; i++)
          OperatorDetail(
            id: 'char_${i.toString().padLeft(3, '0')}_op',
            name: 'Op $i',
            codename: 'Op $i',
            rarity: 1 + i % 6,
            profession: 'GUARD',
            branch: 'Fighter',
            teams: ['T${i.toString().padLeft(2, '0')}'],
            thumbnailHue: i,
            quote: '',
            archetypeDescription: '',
          ),
      ];
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );
      await tester.tap(find.byKey(const Key('sidebar-operators')));
      await tester.pumpAndSettle();

      Finder chip(int i) => find.byKey(
            ValueKey(
              'operators-filter-affiliation-T${i.toString().padLeft(2, '0')}',
            ),
          );
      // The long affiliation list starts folded.
      expect(chip(0), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('operators-filter-group-affiliation')),
      );
      await tester.pumpAndSettle();
      // Wrap layout: runs start at the same x, chips 6px apart in a run.
      final first = tester.getRect(chip(0));
      final second = tester.getRect(chip(1));
      expect(second.top, first.top);
      expect(second.left - first.right, 6);
      final nextRun = [
        for (var i = 2; i < 10; i++) tester.getRect(chip(i)),
      ].firstWhere((rect) => rect.top > first.top);
      expect(nextRun.left, first.left);
      expect(nextRun.top - first.bottom, 6);

      // Options far below the box's visible part are built when scrolled to.
      expect(chip(39), findsNothing);
      await tester.drag(chip(0), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(chip(39), findsOneWidget);
      await tester.tap(chip(39));
      await tester.pumpAndSettle();
      expect(find.text('Op 39'), findsOneWidget);
      expect(find.text('Op 0'), findsNothing);
    });

    testWidgets('reopening the section shows the loaded list at once',
        (tester) async {
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );
      await tester.tap(find.byKey(const Key('rail-operators')));
      await tester.pumpAndSettle();
      expect(find.text('Amiya'), findsOneWidget);
      await tester.tap(find.byKey(const Key('rail-home')));
      await tester.pumpAndSettle();
      expect(find.byType(OperatorsScreen), findsNothing);

      await tester.tap(find.byKey(const Key('rail-operators')));
      await tester.pump();
      // First frame: the tiles, not the loading state.
      expect(find.text('Amiya'), findsOneWidget);
      expect(operatorService.requestedRegions, [RegionCode.kr]);

      // A sync (new data revision) loads the list again.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OperatorsScreen)),
      );
      container.read(dataRevisionProvider.notifier).state++;
      await tester.pumpAndSettle();
      expect(operatorService.requestedRegions, [RegionCode.kr, RegionCode.kr]);
    });

    testWidgets('phone layout pushes the detail page', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );
      await tester.tap(find.byKey(const Key('tab-operators')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('operators-filter-button')), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('operator-tile-char_003_kalts')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(OperatorDetailScreen), findsOneWidget);
      expect(find.text('Doctor.'), findsOneWidget);

      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      expect(find.byType(OperatorsScreen), findsOneWidget);
      expect(find.text('Amiya'), findsOneWidget);
    });

    testWidgets('condenses the top bar on scroll and reveals more tiles',
        (tester) async {
      operatorService._operators = [
        for (var i = 0; i < 80; i++)
          OperatorDetail(
            id: 'char_${i.toString().padLeft(3, '0')}_op',
            name: 'Op $i',
            codename: 'Op $i',
            rarity: 1 + i % 6,
            profession: 'GUARD',
            branch: 'Fighter',
            thumbnailHue: i,
            quote: '',
            archetypeDescription: '',
          ),
      ];
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );
      await tester.tap(find.byKey(const Key('rail-operators')));
      await tester.pumpAndSettle();

      // Condensing folds the search field away (clipped to zero height).
      final search = find.byType(RdSearchField).hitTestable();
      expect(search, findsOneWidget);
      // Nothing filtered: the chip row starts with the dimension chips.
      expect(find.text('필터 없음'), findsNothing);
      expect(find.byKey(const Key('operators-filter-rarity')), findsOneWidget);
      expect(find.text('Op 0'), findsOneWidget);

      int revealed() =>
          (tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate
                  as SliverChildBuilderDelegate)
              .childCount!;
      // useInfiniteSlice: initialCount 36.
      expect(revealed(), 36);

      final scrollable = find.byType(CustomScrollView);
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(search, findsNothing);
      expect(find.byKey(const Key('operators-filter-rarity')), findsOneWidget);

      // Batches of 24 are revealed as the sentinel nears the viewport.
      for (var i = 0; i < 40 && find.text('Op 79').evaluate().isEmpty; i++) {
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.text('Op 79'), findsOneWidget);
      expect(revealed(), 80);

      await tester.drag(scrollable, const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(search, findsOneWidget);
    });

    group('unreleased operators', () {
      const badge = '미실장 · CN';
      const stripTitle = '미실장 1명';
      final stripToggle =
          find.byKey(const Key('operators-unreleased-strip-toggle'));

      setUp(() => operatorService.addUnreleased());

      testWidgets(
          'sit in a collapsed strip above the grid, open on a search and '
          'are hidden by the toggle', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _pumpApp(
          tester,
          operatorService,
          regionSyncService,
          userDataRepository,
        );
        await tester.tap(find.byKey(const Key('tab-operators')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Collapsed by default: the strip names the count, not the tiles.
        expect(find.text(stripTitle), findsOneWidget);
        expect(find.text('Nova'), findsNothing);
        expect(find.text('2명 · 미실장 1명'), findsOneWidget);
        // The strip sits above the released operators.
        expect(
          tester.getTopLeft(stripToggle).dy,
          lessThan(tester.getTopLeft(find.text('Amiya')).dy),
        );

        // Expanding shows the small tile with the source badge.
        await tester.tap(stripToggle);
        await tester.pumpAndSettle();
        expect(find.text('Nova'), findsOneWidget);
        final tileBadge =
            find.byKey(const ValueKey('operator-unreleased-char_900_nova'));
        expect(tileBadge, findsOneWidget);
        expect(
          find.descendant(of: tileBadge, matching: find.text('CN')),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(find.text('Nova')).dy,
          lessThan(tester.getTopLeft(find.text('Amiya')).dy),
        );
        await tester.tap(stripToggle);
        await tester.pumpAndSettle();
        expect(find.text('Nova'), findsNothing);

        // A search finds the borrowed name and opens the strip on it,
        // instead of the "no operators" state of the empty grid.
        await tester.enterText(find.byType(TextField), 'nov');
        await tester.pumpAndSettle();
        expect(find.text('Nova'), findsOneWidget);
        expect(find.text('Amiya'), findsNothing);
        expect(find.text('조건에 맞는 오퍼레이터가 없습니다.'), findsNothing);
        expect(find.text('0명 · 미실장 1명'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();
        // Clearing the search folds it again.
        expect(find.text('Nova'), findsNothing);
        expect(find.text(stripTitle), findsOneWidget);

        final toggle =
            find.byKey(const Key('operators-filter-hide-unreleased'));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(stripToggle, findsNothing);
        expect(find.text(stripTitle), findsNothing);
        expect(find.text('Amiya'), findsOneWidget);
        expect(find.text('2명'), findsOneWidget);
        // Hidden stays hidden for a search that matches them.
        await tester.enterText(find.byType(TextField), 'nov');
        await tester.pumpAndSettle();
        expect(find.text('Nova'), findsNothing);
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();

        // The reset chip shows them again.
        final reset = find.byKey(const Key('operators-filter-chip-reset'));
        await tester.ensureVisible(reset);
        await tester.pumpAndSettle();
        await tester.tap(reset);
        await tester.pumpAndSettle();
        expect(find.text(stripTitle), findsOneWidget);
      });

      testWidgets('show the badge next to the name in the detail hero',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _pumpApp(
          tester,
          operatorService,
          regionSyncService,
          userDataRepository,
        );
        await tester.tap(find.byKey(const Key('tab-operators')));
        await tester.pumpAndSettle();

        await tester.tap(stripToggle);
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('operator-tile-char_900_nova')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final header = find.byKey(const Key('operator-detail-unreleased'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(of: header, matching: find.text(badge)),
          findsOneWidget,
        );
        // Whole, beside the hero name (the app bar only has the name).
        final name = find.text('Nova').last;
        expect(
          tester.getCenter(header).dy,
          closeTo(tester.getCenter(name).dy, 8),
        );
        expect(
          tester.getSize(header).width,
          greaterThan(tester.getSize(find.text(badge)).width),
        );

        await tester.tap(find.byTooltip('뒤로가기'));
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('operator-tile-char_002_amiya')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('operator-detail-unreleased')),
          findsNothing,
        );
      });

      testWidgets('PC sidebar switch hides the strip', (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _pumpApp(
          tester,
          operatorService,
          regionSyncService,
          userDataRepository,
        );
        await tester.tap(find.byKey(const Key('sidebar-operators')));
        await tester.pumpAndSettle();

        expect(find.text(stripTitle), findsOneWidget);
        expect(find.byKey(const Key('operators-count')), findsOneWidget);
        expect(find.text('2명 · 미실장 1명'), findsOneWidget);
        final toggle =
            find.byKey(const ValueKey('operators-filter-hide-unreleased'));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text(stripTitle), findsNothing);
        expect(find.text('Kaltsit'), findsOneWidget);
        expect(find.text('2명'), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text(stripTitle), findsOneWidget);

        // A strip tile fills the detail pane like a grid tile.
        await tester.tap(stripToggle);
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('operator-tile-char_900_nova')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('operator-detail-unreleased')),
          findsOneWidget,
        );
        // The open strip stays open on the selection route.
        expect(find.text('Nova'), findsNWidgets(2));
      });
    });

    testWidgets('has no unreleased toggle without unreleased operators',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );
      await tester.tap(find.byKey(const Key('tab-operators')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('operators-filter-hide-unreleased')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('operators-unreleased-strip-toggle')),
        findsNothing,
      );
      expect(find.text('2명'), findsOneWidget);
    });

    testWidgets(
        'master-detail from 1000px wide, without the sidebar below '
        'the expanded width', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );
      await tester.tap(find.byKey(const Key('rail-operators')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(OperatorsWorkspace), findsOneWidget);
      // The filters fold into the button and the chip row over the list.
      expect(find.byKey(const Key('operators-filter-button')), findsOneWidget);
      expect(find.byKey(const Key('operators-filter-rarity')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('operators-filter-group-rarity')),
        findsNothing,
      );
      expect(
        find.text(const NexusI18n(RegionCode.kr).t('rd.operators.detail.none')),
        findsOneWidget,
      );
      // The list keeps a 404px start next to the resizable pane.
      final handle = find.byKey(const Key('operator-detail-resize'));
      expect(tester.getCenter(handle).dx, closeTo(76 + 404 + 4.5, 2));

      await tester
          .tap(find.byKey(const ValueKey('operator-tile-char_003_kalts')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(OperatorsWorkspace), findsOneWidget);
      expect(find.text('Doctor.'), findsOneWidget);
      expect(find.text('Amiya'), findsOneWidget);
      // Sticky plan actions in the pane.
      expect(
        find.byKey(const Key('operator-detail-add-to-plan')),
        findsOneWidget,
      );

      // The list never gets narrower than 360px.
      await tester.drag(
        handle,
        const Offset(-2000, 0),
        kind: PointerDeviceKind.mouse,
        touchSlopX: 0,
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(handle).dx, closeTo(76 + 360 + 4.5, 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('below 1000px the list pushes the detail page', (tester) async {
      tester.view.physicalSize = const Size(990, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );
      await tester.tap(find.byKey(const Key('rail-operators')));
      await tester.pumpAndSettle();
      expect(find.byType(OperatorsWorkspace), findsNothing);
      expect(find.byType(OperatorsListPage), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('operator-tile-char_003_kalts')));
      await tester.pumpAndSettle();
      expect(find.byType(OperatorsListPage), findsNothing);
      expect(find.text('Doctor.'), findsOneWidget);
      expect(find.byTooltip('뒤로가기'), findsOneWidget);
    });

    testWidgets('PC sidebar groups fold and unfold', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );
      await tester.tap(find.byKey(const Key('sidebar-operators')));
      await tester.pumpAndSettle();

      Finder group(String name) =>
          find.byKey(ValueKey('operators-filter-group-$name'));
      Finder header(String name) => find
          .descendant(of: group(name), matching: find.byType(InkWell))
          .first;
      const rarity = ValueKey('operators-filter-rarity-6 ★');
      const caster = ValueKey('operators-filter-profession-all');
      const rhodes = ValueKey('operators-filter-affiliation-Rhodes Island');
      const healing = ValueKey('operators-filter-ba-tags-Healing');

      // Rarity and profession open; affiliation and BA tags folded with
      // their option counts.
      expect(find.byKey(rarity), findsOneWidget);
      expect(find.byKey(caster), findsOneWidget);
      expect(find.byKey(rhodes), findsNothing);
      expect(find.byKey(healing), findsNothing);
      expect(
        find.descendant(of: group('affiliation'), matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: group('ba-tags'), matching: find.text('1')),
        findsOneWidget,
      );

      // Unfolded, the long lists keep their search box.
      await tester.tap(header('affiliation'));
      await tester.pumpAndSettle();
      expect(find.byKey(rhodes), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: group('affiliation'),
          matching: find.byType(TextField),
        ),
        'medical',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(rhodes), findsNothing);
      await tester.tap(
        find.byKey(
          const ValueKey('operators-filter-affiliation-Medical Department'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Amiya'), findsNothing);

      // Folded again, the group shows the picked value.
      await tester.tap(header('affiliation'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: group('affiliation'),
          matching: find.text('Medical Department'),
        ),
        findsOneWidget,
      );
      await tester.tap(header('rarity'));
      await tester.pumpAndSettle();
      expect(find.byKey(rarity), findsNothing);

      // The folds survive selecting an operator (another route).
      await tester
          .tap(find.byKey(const ValueKey('operator-tile-char_003_kalts')));
      await tester.pumpAndSettle();
      expect(find.byKey(rarity), findsNothing);

      await tester.tap(find.byKey(const Key('operators-filter-reset')));
      await tester.pumpAndSettle();
      expect(find.text('Amiya'), findsOneWidget);
    });

    testWidgets(
        'shows the error state when the freshness check fails, like Tauri',
        (tester) async {
      regionSyncService.failEnsure = true;

      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );

      await tester.tap(find.byKey(const Key('rail-operators')));
      await tester.pumpAndSettle();

      // `ensure_region_fresh` errors propagate to the page even with a cache.
      expect(find.text('Amiya'), findsNothing);
      expect(find.text('오퍼레이터 데이터를 불러오지 못했습니다.'), findsOneWidget);
    });

    testWidgets('shows the error state when there is no data and sync fails',
        (tester) async {
      operatorService.clear();
      regionSyncService.failEnsure = true;

      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );

      await tester.tap(find.byKey(const Key('rail-operators')));
      await tester.pumpAndSettle();

      expect(find.text('오퍼레이터 데이터를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.textContaining('offline'), findsOneWidget);
    });

    testWidgets('reloads operators for the selected region', (tester) async {
      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );

      await tester.tap(find.byKey(const Key('rail-operators')));
      await tester.pumpAndSettle();
      expect(operatorService.requestedRegions, [RegionCode.kr]);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OperatorsScreen)),
      );
      container.read(regionProvider.notifier).state = RegionCode.en;
      await tester.pumpAndSettle();

      expect(operatorService.requestedRegions, [RegionCode.kr, RegionCode.en]);
      expect(
        find.text(
          const NexusI18n(RegionCode.en).t('operatorsList.topBar.title'),
        ),
        findsOneWidget,
      );
    });

    // Operator detail coverage lives in operator_detail_screen_test.dart.

    testWidgets(
        'syncs region data before showing operators when cache is empty',
        (tester) async {
      operatorService.clear();

      await _pumpApp(
        tester,
        operatorService,
        regionSyncService,
        userDataRepository,
      );

      await tester.tap(find.byKey(const Key('rail-operators')));
      await tester.pumpAndSettle();

      expect(regionSyncService.ensureFreshCalls, 1);
      expect(find.text('Amiya'), findsOneWidget);
    });
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  OperatorService operatorService,
  RegionSyncService regionSyncService,
  UserDataRepository userDataRepository,
) async {
  // One readiness for the services and the shell, as in the app.
  final readiness = RegionReadiness(regionSyncService, NoopAppLogger());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        regionReadinessProvider.overrideWithValue(readiness),
        operatorServiceProvider.overrideWithValue(
          EnsuringOperatorService(operatorService, readiness),
        ),
        regionSyncServiceProvider.overrideWithValue(regionSyncService),
        userDataServiceProvider.overrideWithValue(
          UserDataService(userDataRepository),
        ),
        imageCacheServiceProvider.overrideWithValue(FakeImageCacheService()),
      ],
      child: const ArknightNexusApp(),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeOperatorService implements OperatorService {
  List<OperatorDetail> _operators = List.of(_fixtureOperators);
  final requestedRegions = <RegionCode>[];

  void clear() {
    _operators = [];
  }

  void restoreFixtures() {
    _operators = List.of(_fixtureOperators);
  }

  /// Puts an operator the region has not released (CN data) first, as the
  /// published snapshots do.
  void addUnreleased() {
    _operators = [
      const OperatorDetail(
        id: 'char_900_nova',
        name: 'Nova',
        codename: 'Nova',
        rarity: 6,
        profession: 'CASTER',
        branch: 'Core Caster',
        thumbnailHue: 20,
        unreleasedSource: 'cn',
        quote: 'Soon.',
        archetypeDescription: 'Core Caster',
      ),
      ..._fixtureOperators,
    ];
  }

  static const _fixtureOperators = [
    OperatorDetail(
      id: 'char_002_amiya',
      name: 'Amiya',
      codename: 'Amiya',
      rarity: 5,
      profession: 'CASTER',
      branch: 'Core Caster',
      teams: ['Rhodes Island'],
      nations: ['Rhodes Island'],
      groups: ['Rhodes Island'],
      thumbnailHue: 210,
      quote: 'Leader',
      tags: ['DPS'],
      archetypeDescription: 'Core Caster',
      modules: [
        OperatorModule(
          uniEquipId: 'uniequip_002_amiya',
          uniEquipName: 'Mind Over Matter',
          uniEquipIcon: 'amiya_module_1',
          uniEquipDesc: 'Module description',
          typeIcon: 'cmd-y',
          unlockEvolvePhase: 'PHASE_2',
          charId: 'char_002_amiya',
          unlockLevel: 40,
          isSpecialEquip: false,
        ),
      ],
    ),
    OperatorDetail(
      id: 'char_003_kalts',
      name: 'Kaltsit',
      codename: 'Kaltsit',
      rarity: 6,
      profession: 'MEDIC',
      branch: 'Physician',
      teams: ['Medical Department'],
      nations: ['Rhodes Island'],
      groups: ['Rhodes Island'],
      baTags: ['Healing'],
      thumbnailHue: 140,
      quote: 'Doctor.',
      tags: ['Healing'],
      archetypeDescription: 'Physician',
    ),
  ];

  @override
  Future<List<OperatorSummary>> listOperators(OperatorQuery query) async {
    requestedRegions.add(query.region);
    final search = query.search?.trim().toLowerCase() ?? '';
    return _operators
        .where((operator) {
          return search.isEmpty ||
              [
                operator.name,
                operator.profession,
                operator.branch,
                ...operator.teams,
                ...operator.nations,
                ...operator.groups,
              ].any((value) => value.toLowerCase().contains(search));
        })
        .map(
          (operator) => OperatorSummary(
            id: operator.id,
            name: operator.name,
            rarity: operator.rarity,
            profession: operator.profession,
            branch: operator.branch,
            teams: operator.teams,
            nations: operator.nations,
            groups: operator.groups,
            baTags: operator.baTags,
            thumbnailHue: operator.thumbnailHue,
            unreleasedSource: operator.unreleasedSource,
          ),
        )
        .toList();
  }

  @override
  Future<OperatorDetail?> getOperatorDetail(
    RegionCode region,
    String operatorId,
  ) async {
    for (final operator in _operators) {
      if (operator.id == operatorId) {
        return operator;
      }
    }
    return null;
  }
}

class _FakeRegionSyncService implements RegionSyncService {
  _FakeRegionSyncService(this._operatorService);

  final _FakeOperatorService _operatorService;
  int ensureFreshCalls = 0;
  bool failEnsure = false;

  @override
  Future<SyncResult> ensureRegionFresh(RegionCode region) async {
    ensureFreshCalls += 1;
    if (failEnsure) {
      throw StateError('offline');
    }
    // Simulates downloading into an empty cache.
    if (_operatorService._operators.isEmpty) {
      _operatorService.restoreFixtures();
    }
    return const SyncResult(
      region: RegionCode.kr,
      sourceRevision: 'main',
      sourceVersion: 'test',
      updatedAt: '2026-05-17T00:00:00Z',
      operatorCount: 2,
      status: 'success',
    );
  }

  @override
  Future<RegionSyncStatus?> getRegionSyncStatus(RegionCode region) async {
    return null;
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
  Stream<SyncStatus> syncRegion(RegionCode region) async* {}
}

class _MemoryUserDataRepository implements UserDataRepository {
  UserData data = const UserData();
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
