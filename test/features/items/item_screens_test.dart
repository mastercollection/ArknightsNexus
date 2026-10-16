import 'dart:async';

import 'package:arknight_nexus/app/app.dart';
import 'package:arknight_nexus/app/providers.dart';
import 'package:arknight_nexus/app/router.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/building_formula.dart';
import 'package:arknight_nexus/domain/item.dart';
import 'package:arknight_nexus/domain/penguin_matrix.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/features/items/item_format.dart';
import 'package:arknight_nexus/features/items/item_detail_screen.dart';
import 'package:arknight_nexus/features/items/items_screen.dart';
import 'package:arknight_nexus/i18n/nexus_i18n.dart';
import 'package:arknight_nexus/repositories/user_data_repository.dart';
import 'package:arknight_nexus/services/item_service.dart';
import 'package:arknight_nexus/services/penguin_stats_service.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:arknight_nexus/services/user_data_service.dart';
import 'package:arknight_nexus/ui/redesign/rd_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_image_cache_service.dart';
import '../../support/fake_penguin_stats_service.dart';

void main() {
  group('item formatting helpers', () {
    test('formats owned counts like the web list', () {
      expect(formatOwnedCount(1234567, '30012'), '1,234,567');
      expect(formatOwnedCount(-3, '30012'), '0');
      expect(formatOwnedCount(12345, lmdItemId), '12.3K');
      expect(formatOwnedCount(2500000, lmdItemId), '2.5M');
      // An empty or small LMD wallet is written out, not "0.0K".
      expect(formatOwnedCount(0, lmdItemId), '0');
      expect(formatOwnedCount(999, lmdItemId), '999');
      expect(formatOwnedCount(1000, lmdItemId), '1.0K');
    });

    test('normalizes owned count input', () {
      expect(normalizeOwnedCountInput(''), '0');
      expect(normalizeOwnedCountInput('0a12'), '12');
      expect(normalizeOwnedCountInput('123456789012'), '9999999');
      expect(ownedCountHoldStep(const Duration(milliseconds: 200)), 1);
      expect(ownedCountHoldStep(const Duration(milliseconds: 1600)), 5);
      expect(ownedCountHoldStep(const Duration(seconds: 3)), 10);
    });

    test('resolves penguin stage labels with _perm fallback', () {
      const map = {'main_01-07': '1-7'};
      expect(penguinStageLabel('main_01-07_perm', map), '1-7');
      expect(penguinStageLabel('unknown', map), 'unknown');
      expect(formatJsNumber(2.0), '2');
      expect(formatJsNumber(0.5), '0.5');
    });

    test('derives item kinds and tiers from the game data', () {
      ItemEntry entry(
        String id, {
        String type = 'MATERIAL',
        String classify = 'MATERIAL',
        String rarity = 'TIER_3',
      }) =>
          _entry(
            id,
            id,
            rarity: rarity,
            itemType: type,
            classifyType: classify,
          );
      expect(
        itemKindOf(entry('4001', type: 'GOLD', classify: 'NORMAL')),
        ItemKind.currency,
      );
      expect(itemKindOf(entry('2004', type: 'CARD_EXP')), ItemKind.exp);
      expect(itemKindOf(entry('3303')), ItemKind.skill);
      expect(itemKindOf(entry('mod_unlock_token')), ItemKind.module);
      expect(itemKindOf(entry('3213')), ItemKind.chip);
      expect(itemKindOf(entry('32001')), ItemKind.chip);
      expect(itemKindOf(entry('tier6_pioneer')), ItemKind.token);
      expect(itemKindOf(entry('30014')), ItemKind.material);
      expect(
        itemKindOf(entry('furni_1', type: 'FURN', classify: 'NONE')),
        ItemKind.other,
      );
      expect(itemTierOf(entry('30014', rarity: 'TIER_4')), 4);
      expect(itemTierOf(entry('30012', rarity: '3')), 3);
      expect(itemTierOf(entry('x', rarity: '')), 0);
    });

    test('infinite slice reveals items in batches', () {
      final slice = InfiniteSlice(
        initialCount: ItemsScreen.initialCount,
        batchSize: ItemsScreen.batchSize,
      )..reset(100);
      expect(slice.visibleCount, 48);
      expect(slice.loadMore(100), isTrue);
      expect(slice.visibleCount, 78);
      expect(slice.loadMore(100), isTrue);
      expect(slice.visibleCount, 100);
      expect(slice.loadMore(100), isFalse);
      slice.reset(10);
      expect(slice.visibleCount, 10);
    });
  });

  group('item screens', () {
    late _FakeItemService itemService;
    late _MemoryUserDataRepository userDataRepository;

    setUp(() {
      itemService = _FakeItemService();
      userDataRepository = _MemoryUserDataRepository(
        const UserData(itemCounts: {'30012': 11}),
      );
    });

    testWidgets('lists material items and filters by search text',
        (tester) async {
      await _pumpApp(tester, itemService, userDataRepository);
      await _openItems(tester);

      expect(_inItems(find.text('아이템')), findsOneWidget);
      expect(find.text('Oriron'), findsOneWidget);
      expect(find.text('Orirock'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(itemService.lastClassifyType, 'MATERIAL');

      // Search also covers description/usage like the web page.
      await tester.enterText(find.byType(TextField), 'rock material');
      await tester.pumpAndSettle();
      expect(find.text('Oriron'), findsNothing);
      expect(find.text('Orirock'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nothing-matches');
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 아이템이 없습니다.'), findsOneWidget);
    });

    testWidgets('reveals long lists incrementally', (tester) async {
      itemService = _FakeItemService(extraCount: 120);
      await _pumpApp(tester, itemService, userDataRepository);
      await _openItems(tester);

      // Only the first slice is materialized up front.
      expect(find.text('Extra 119'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Extra 119'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 200,
      );
      expect(find.text('Extra 119'), findsOneWidget);
    });

    testWidgets('edits owned item count with stepper and input',
        (tester) async {
      await _pumpApp(tester, itemService, userDataRepository);
      await _openItems(tester);

      await tester.tap(find.text('11'));
      await tester.pumpAndSettle();
      expect(find.text('현재 보유 수량'), findsOneWidget);

      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
      expect((await userDataRepository.read()).itemCounts['30012'], 12);

      await tester.enterText(find.byType(TextField).last, '23');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect((await userDataRepository.read()).itemCounts['30012'], 23);

      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(find.text('현재 보유 수량'), findsNothing);
      expect(find.text('23'), findsOneWidget);
    });

    testWidgets('imports item counts from JSON', (tester) async {
      await _pumpApp(tester, itemService, userDataRepository);
      await _openItems(tester);

      await tester.tap(find.text('JSON 임포트'));
      await tester.pumpAndSettle();
      expect(find.text('아이템 수량 JSON 임포트'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '{"30013": 5}');
      await tester.tap(find.text('임포트 적용'));
      await tester.pumpAndSettle();

      expect((await userDataRepository.read()).itemCounts['30013'], 5);
      expect(find.text('아이템 수량 JSON 임포트'), findsNothing);
      expect(find.text('1개 아이템 수량을 반영했습니다.'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Let the toast dismiss itself.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('1개 아이템 수량을 반영했습니다.'), findsNothing);
    });

    testWidgets('opens item detail with building recipe costs', (tester) async {
      await _pumpApp(tester, itemService, userDataRepository);
      await _openItems(tester);
      await tester.tap(find.text('Oriron'));
      await tester.pumpAndSettle();

      expect(find.text('Oriron'), findsWidgets);
      expect(find.text('제조 레시피'), findsOneWidget);
      expect(find.text('Orirock'), findsOneWidget);
      expect(find.text('T2 · 재료'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
      expect(find.text('제조소'), findsOneWidget);
      // Header chips and the item's own text.
      expect(find.text('T3'), findsOneWidget);
      expect(find.text('Upgrade material'), findsOneWidget);
      expect(find.text('Stage'), findsOneWidget);
      expect(find.text('펭귄 통계'), findsOneWidget);
      expect(find.text('표시할 Penguin Stats 드랍 데이터가 없습니다.'), findsOneWidget);
    });

    testWidgets('groups items into kind tabs and tier sections',
        (tester) async {
      itemService = _FakeItemService(
        moreItems: [
          _entry(
            '4001',
            'LMD',
            rarity: 'TIER_4',
            itemType: 'GOLD',
            classifyType: 'NORMAL',
          ),
          _entry(
            '2001',
            'Drill Battle Record',
            rarity: 'TIER_2',
            itemType: 'CARD_EXP',
          ),
          _entry('3211', 'Vanguard Chip', rarity: 'TIER_3'),
          _entry('30014', 'Orirock Concentration', rarity: 'TIER_4'),
        ],
      );
      await _pumpApp(tester, itemService, userDataRepository);
      await _openItems(tester);

      // Only kinds present in the data get a tab.
      for (final label in ['전체', '재화', '작전기록', '칩', '재료']) {
        expect(_inItems(find.text(label)), findsWidgets, reason: label);
      }
      for (final label in ['스킬', '모듈', '증표']) {
        expect(_inItems(find.text(label)), findsNothing, reason: label);
      }
      // "All" is grouped by kind: the tab and the section header.
      expect(_inItems(find.text('재화')), findsNWidgets(2));
      expect(find.text('LMD'), findsOneWidget);
      expect(find.text('Vanguard Chip'), findsOneWidget);

      // Materials: sections by tier, highest first.
      await tester.tap(_inItems(find.text('재료')).first);
      await tester.pumpAndSettle();
      expect(find.text('LMD'), findsNothing);
      expect(find.text('Vanguard Chip'), findsNothing);
      expect(find.text('T4'), findsOneWidget);
      expect(find.text('T3'), findsOneWidget);
      expect(find.text('T2'), findsOneWidget);
      expect(
        _readsBefore(
          tester,
          find.text('Orirock Concentration'),
          find.text('Oriron'),
        ),
        isTrue,
      );
      expect(
        _readsBefore(tester, find.text('Oriron'), find.text('Orirock')),
        isTrue,
      );

      // A kind without sub-sections lists its items alone.
      await tester.tap(_inItems(find.text('칩')).first);
      await tester.pumpAndSettle();
      expect(find.text('Vanguard Chip'), findsOneWidget);
      expect(find.text('Oriron'), findsNothing);
      expect(find.text('T3'), findsNothing);

      // Search filters inside the selected tab.
      await tester.tap(_inItems(find.text('전체')).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'battle');
      await tester.pumpAndSettle();
      expect(find.text('Drill Battle Record'), findsOneWidget);
      expect(find.text('Oriron'), findsNothing);
    });

    testWidgets('mutes zero owned counts and writes small LMD counts out',
        (tester) async {
      itemService = _FakeItemService(
        moreItems: [
          _entry(
            '4001',
            'LMD',
            rarity: 'TIER_4',
            itemType: 'GOLD',
            classifyType: 'NORMAL',
          ),
        ],
      );
      await _pumpApp(tester, itemService, userDataRepository);
      await _openItems(tester);

      // Orirock and LMD are not owned.
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('0.0K'), findsNothing);
      for (final element in find.text('0').evaluate()) {
        expect((element.widget as Text).style?.color, RdColors.text3);
      }
      expect(
        tester.widget<Text>(find.text('11')).style?.color,
        RdColors.text,
      );
    });

    testWidgets('shows the item and recipe while Penguin Stats is pending',
        (tester) async {
      final penguin = _BlockingPenguinStatsService();
      await _pumpApp(
        tester,
        itemService,
        userDataRepository,
        penguinStatsService: penguin,
        stageCodes: const {'main_02-07': '2-7'},
      );
      await _openItems(tester);
      await tester.tap(find.text('Oriron'));
      // The loading row spins, so advance frame by frame instead of settling.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Upgrade material'), findsOneWidget);
      expect(find.text('제조 레시피'), findsOneWidget);
      expect(find.text('Orirock'), findsOneWidget);
      expect(find.byTooltip('수량 늘리기 (길게 누르면 가속)'), findsOneWidget);
      expect(find.text('Penguin Stats에서 불러오는 중'), findsOneWidget);
      expect(find.text('40.00%'), findsNothing);

      penguin.complete([
        const PenguinMatrixEntry(
          stageId: 'main_02-07',
          itemId: '30012',
          quantity: 40,
          times: 100,
          dropRate: 0.4,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Penguin Stats에서 불러오는 중'), findsNothing);
      expect(find.text('2-7'), findsOneWidget);
      expect(find.text('40.00%'), findsOneWidget);
    });

    testWidgets('edits the owned count inline on the detail page',
        (tester) async {
      await _pumpApp(tester, itemService, userDataRepository);
      await _openItems(tester);
      await tester.tap(find.text('Oriron'));
      await tester.pumpAndSettle();

      expect(find.text('보유'), findsOneWidget);
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
      expect((await userDataRepository.read()).itemCounts['30012'], 12);

      await tester.tap(find.text('−'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('−'));
      await tester.pumpAndSettle();
      expect((await userDataRepository.read()).itemCounts['30012'], 10);

      await tester.enterText(find.byType(TextField), '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect((await userDataRepository.read()).itemCounts['30012'], isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField)).style?.color,
        RdColors.text3,
      );

      // Back on the list, the tile shows the count saved on the detail page.
      await tester.tap(find.byTooltip('아이템 목록으로'));
      await tester.pumpAndSettle();
      expect(find.text('11'), findsNothing);
      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('shows not found state for unknown items', (tester) async {
      await _pumpApp(tester, itemService, userDataRepository);
      _router(tester).go('/items/unknown');
      await tester.pumpAndSettle();

      expect(find.text('아이템을 찾을 수 없습니다.'), findsOneWidget);
      expect(find.text('목록으로 돌아가기'), findsOneWidget);
    });

    testWidgets('shows, sorts and re-fetches penguin drops per server',
        (tester) async {
      final penguin = FakePenguinStatsService({
        '30012': [
          const PenguinMatrixEntry(
            stageId: 'main_02-07',
            itemId: '30012',
            quantity: 40,
            times: 100,
            dropRate: 0.4,
          ),
          const PenguinMatrixEntry(
            stageId: 'main_03-01_perm',
            itemId: '30012',
            quantity: 100,
            times: 1000,
            dropRate: 0.1,
          ),
        ],
      });

      await _pumpApp(
        tester,
        itemService,
        userDataRepository,
        penguinStatsService: penguin,
        stageCodes: const {'main_02-07': '2-7', 'main_03-01': '3-1'},
      );
      await _openItems(tester);
      await tester.tap(find.text('Oriron'));
      await tester.pumpAndSettle();

      expect(find.text('40.00%'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('Penguin Stats · CN'), findsOneWidget);
      expect(_readsBefore(tester, find.text('2-7'), find.text('3-1')), isTrue);

      // Sort by sample count.
      await tester.tap(find.text('드랍률').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('표본 수').last);
      await tester.pumpAndSettle();
      expect(_readsBefore(tester, find.text('3-1'), find.text('2-7')), isTrue);

      // Switch Penguin server.
      await tester.tap(find.text('CN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('KR').last);
      await tester.pumpAndSettle();
      expect(penguin.requestedServers, [PenguinServer.cn, PenguinServer.kr]);
      expect(find.text('Penguin Stats · KR'), findsOneWidget);
    });

    testWidgets('reloads items in the selected region language',
        (tester) async {
      await _pumpApp(tester, itemService, userDataRepository);
      await _openItems(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ItemsScreen)),
      );
      container.read(regionProvider.notifier).state = RegionCode.cn;
      await tester.pumpAndSettle();

      expect(_inItems(find.text('道具')), findsOneWidget);
      expect(itemService.requestedRegions.last, RegionCode.cn);
    });

    testWidgets('queues closing the count editor while a save is running',
        (tester) async {
      final blocking = _BlockingUserDataRepository(
        const UserData(itemCounts: {'30012': 11}),
      );
      await _pumpApp(tester, itemService, blocking);
      await _openItems(tester);

      await tester.tap(find.text('11'));
      await tester.pumpAndSettle();
      blocking.block();
      await tester.tap(find.text('+'));
      await tester.pump();
      expect(find.text('저장 중… 완료될 때까지 닫을 수 없습니다.'), findsOneWidget);

      // Close (button and Android back) is queued, not dropped.
      await tester.tap(find.byTooltip('닫기'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('현재 보유 수량'), findsOneWidget);

      blocking.release();
      await tester.pumpAndSettle();
      expect(find.text('현재 보유 수량'), findsNothing);
      expect(find.text('12'), findsOneWidget);
      expect((await blocking.read()).itemCounts['30012'], 12);
    });
  });

  group('item screen layouts', () {
    for (final size in const [Size(390, 844), Size(1440, 900)]) {
      testWidgets('list and detail fit ${size.width.toInt()}px',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        // Collect framework errors so the check below covers the items
        // screens. Errors raised by the shell's own widgets (lib/app/shell.dart,
        // not part of this area) are reported separately and skipped here.
        final errors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = errors.add;
        List<String> itemErrors() => [
              for (final error in errors)
                if (!error.toString().contains('app/shell.dart'))
                  error.toString(),
            ];
        try {
          final itemService = _FakeItemService(extraCount: 60);
          final repository = _MemoryUserDataRepository(
            const UserData(itemCounts: {'30012': 11, '4001': 250000}),
          );
          await _pumpApp(
            tester,
            itemService,
            repository,
            penguinStatsService: FakePenguinStatsService({
              '30012': [
                for (var i = 1; i <= 5; i++)
                  PenguinMatrixEntry(
                    stageId: 'main_0$i-07',
                    itemId: '30012',
                    quantity: 10 * i,
                    times: 100,
                    dropRate: i / 10,
                  ),
              ],
            }),
            // On phones the screens are pumped without the shell, whose bottom
            // tab bar currently throws "No Material widget found" in tests.
            router: size.width < 720 ? _plainItemsRouter() : null,
          );
          _router(tester).go('/items');
          await tester.pumpAndSettle();

          expect(itemErrors(), isEmpty);
          expect(find.byType(ItemsScreen), findsOneWidget);
          expect(find.byType(TextField), findsOneWidget);
          final compact = size.width < 720;
          final importButton =
              compact ? find.byTooltip('JSON 임포트') : find.text('JSON 임포트');
          expect(importButton, findsOneWidget);
          expect(find.text('11'), findsOneWidget);
          // The items list is a section root: no back button.
          expect(find.byTooltip('뒤로가기'), findsNothing);

          await tester.tap(find.text('11'));
          await tester.pumpAndSettle();
          expect(itemErrors(), isEmpty);
          expect(find.text('+'), findsOneWidget);
          expect(find.text('−'), findsOneWidget);
          expect(find.text('0초 ±1'), findsOneWidget);
          await tester.tap(find.byTooltip('닫기'));
          await tester.pumpAndSettle();

          await tester.tap(importButton);
          await tester.pumpAndSettle();
          expect(itemErrors(), isEmpty);
          expect(find.text('임포트 적용'), findsOneWidget);
          await tester.tap(find.text('취소'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Oriron'));
          await tester.pumpAndSettle();
          expect(itemErrors(), isEmpty);
          expect(find.byTooltip('아이템 목록으로'), findsOneWidget);
          expect(find.text('제조 레시피'), findsOneWidget);
          expect(find.text('Penguin Stats · CN'), findsOneWidget);
          expect(find.text('50.00%'), findsOneWidget);
          // The inline owned-count stepper sits in the header.
          expect(find.byTooltip('수량 늘리기 (길게 누르면 가속)'), findsOneWidget);
          expect(find.byTooltip('정렬'), findsOneWidget);
          expect(find.byTooltip('서버'), findsOneWidget);

          // Recipe ingredients open their own detail page.
          await tester.tap(find.text('Orirock'));
          await tester.pumpAndSettle();
          expect(find.text('Orirock'), findsOneWidget);
          expect(find.text('제조 레시피'), findsNothing);
          expect(itemErrors(), isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }
      });
    }
  });
}

ItemEntry _entry(
  String id,
  String name, {
  required String rarity,
  String itemType = 'MATERIAL',
  String classifyType = 'MATERIAL',
}) {
  return ItemEntry(
    itemId: id,
    name: name,
    description: '',
    rarity: rarity,
    iconId: '',
    sortId: 0,
    usage: '',
    obtainApproach: '',
    classifyType: classifyType,
    itemType: itemType,
  );
}

/// Holds every Penguin Stats request until [complete].
class _BlockingPenguinStatsService implements PenguinStatsService {
  final _pending = <Completer<List<PenguinMatrixEntry>>>[];

  void complete(List<PenguinMatrixEntry> entries) {
    for (final completer in _pending) {
      completer.complete(entries);
    }
    _pending.clear();
  }

  @override
  Future<List<PenguinMatrixEntry>> getItemMatrix(
    String itemId, {
    PenguinServer server = PenguinServer.cn,
  }) {
    final completer = Completer<List<PenguinMatrixEntry>>();
    _pending.add(completer);
    return completer.future;
  }
}

/// [finder] limited to the items list screen (the shell has its own labels).
Finder _inItems(Finder finder) =>
    find.descendant(of: find.byType(ItemsScreen), matching: finder);

/// Whether [first] comes before [second] in reading order (row by row, left
/// to right): the drop cards form a grid on wide layouts.
bool _readsBefore(WidgetTester tester, Finder first, Finder second) {
  final a = tester.getTopLeft(first);
  final b = tester.getTopLeft(second);
  return a.dy < b.dy || (a.dy == b.dy && a.dx < b.dx);
}

/// Items routes without [NexusShell].
GoRouter _plainItemsRouter() {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SizedBox()),
      GoRoute(
        path: '/items',
        builder: (context, state) => const ItemsScreen(),
      ),
      GoRoute(
        path: '/items/:itemId',
        builder: (context, state) =>
            ItemDetailScreen(itemId: state.pathParameters['itemId']!),
      ),
    ],
  );
}

GoRouter _router(WidgetTester tester) {
  return GoRouter.of(tester.element(find.byType(Navigator).first));
}

Future<void> _openItems(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('rail-items')));
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(
  WidgetTester tester,
  ItemService itemService,
  UserDataRepository userDataRepository, {
  PenguinStatsService? penguinStatsService,
  Map<String, String> stageCodes = const {},
  GoRouter? router,
}) async {
  if (itemService is _FakeItemService) {
    itemService.userData = userDataRepository;
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itemServiceProvider.overrideWithValue(itemService),
        userDataServiceProvider.overrideWithValue(
          UserDataService(userDataRepository),
        ),
        imageCacheServiceProvider.overrideWithValue(FakeImageCacheService()),
        regionSyncServiceProvider.overrideWithValue(
          _FakeRegionSyncService(stageCodes),
        ),
        penguinStatsServiceProvider.overrideWithValue(
          penguinStatsService ?? FakePenguinStatsService(),
        ),
        if (router != null) routerProvider.overrideWithValue(router),
      ],
      child: const ArknightNexusApp(),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeRegionSyncService implements RegionSyncService {
  _FakeRegionSyncService(this._stageCodes);

  final Map<String, String> _stageCodes;

  @override
  Future<Map<String, String>> getRegionStageCodes(RegionCode region) async {
    return _stageCodes;
  }

  @override
  Future<Map<String, String>> getRegionTerms(RegionCode region) async => {};

  @override
  Future<RegionSyncStatus?> getRegionSyncStatus(RegionCode region) async =>
      null;

  @override
  Future<SyncResult> ensureRegionFresh(RegionCode region) {
    throw UnimplementedError();
  }

  @override
  Stream<SyncStatus> syncRegion(RegionCode region) {
    throw UnimplementedError();
  }
}

/// Mirrors [CachedItemService]: snapshot items plus owned counts read from
/// the shared user-data repository.
class _FakeItemService implements ItemService {
  _FakeItemService({
    int extraCount = 0,
    List<ItemEntry> moreItems = const [],
  }) : _items = [
          const ItemEntry(
            itemId: '30012',
            name: 'Oriron',
            description: 'Upgrade material',
            rarity: '3',
            iconId: 'MTL_SL_Iron',
            sortId: 10,
            usage: 'Upgrade',
            obtainApproach: 'Stage',
            classifyType: 'MATERIAL',
            itemType: 'MATERIAL',
            stageDropList: [
              ItemStageDrop(
                stageId: 'main_01-07',
                stageCode: '1-7',
                occPer: 'SOMETIMES',
              ),
            ],
            buildingProductList: [
              ItemBuildingProduct(
                roomType: 'MANUFACTURE',
                formulaId: 'manufact_1',
              ),
            ],
          ),
          const ItemEntry(
            itemId: '30013',
            name: 'Orirock',
            description: 'Rock material',
            rarity: '2',
            iconId: 'MTL_SL_Rock',
            sortId: 20,
            usage: 'Upgrade',
            obtainApproach: 'Stage',
            classifyType: 'MATERIAL',
            itemType: 'MATERIAL',
          ),
          for (var i = 0; i < extraCount; i++)
            ItemEntry(
              itemId: 'extra_$i',
              name: 'Extra $i',
              description: '',
              rarity: '1',
              iconId: '',
              sortId: 100 + i,
              usage: '',
              obtainApproach: '',
              classifyType: 'MATERIAL',
              itemType: 'MATERIAL',
            ),
          ...moreItems,
        ];

  final List<ItemEntry> _items;
  UserDataRepository? userData;
  String? lastClassifyType;
  final requestedRegions = <RegionCode>[];

  @override
  Future<BuildingFormulaBundle> listBuildingFormulas(RegionCode region) async {
    return const BuildingFormulaBundle(
      manufactFormulas: [
        ManufacturingFormula(
          formulaId: 'manufact_1',
          itemId: '30012',
          count: 1,
          weight: 100,
          costPoint: 60,
          formulaType: 'NORMAL',
          buffType: 'NONE',
          costs: [
            FormulaCost(id: '30013', count: 2, type: 'MATERIAL'),
          ],
        ),
      ],
    );
  }

  @override
  Future<List<ItemEntry>> listItems(ItemQuery query) async {
    lastClassifyType = query.classifyType;
    requestedRegions.add(query.region);
    final counts = (await userData?.read())?.itemCounts ?? const {};
    final classifyType = query.classifyType?.trim().toLowerCase();
    return _items
        .where(
          (item) =>
              classifyType == null ||
              item.classifyType.toLowerCase() == classifyType ||
              item.itemType.toUpperCase() == 'GOLD',
        )
        .map((item) => item.copyWith(ownedCount: counts[item.itemId] ?? 0))
        .toList();
  }
}

class _MemoryUserDataRepository implements UserDataRepository {
  _MemoryUserDataRepository(this.data);

  UserData data;

  @override
  Future<void> backup() async {}

  @override
  Future<UserData> read() async => data;

  @override
  Future<void> write(UserData data) async {
    this.data = data;
  }
}

/// Holds `write` until [release] once [block] was called.
class _BlockingUserDataRepository extends _MemoryUserDataRepository {
  _BlockingUserDataRepository(super.data);

  Completer<void>? _gate;

  void block() => _gate = Completer<void>();

  void release() => _gate?.complete();

  @override
  Future<void> write(UserData data) async {
    await _gate?.future;
    await super.write(data);
  }
}
