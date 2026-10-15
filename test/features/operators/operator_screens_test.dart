import 'package:arknight_nexus/app/app.dart';
import 'package:arknight_nexus/app/providers.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/features/operators/operator_detail_screen.dart';
import 'package:arknight_nexus/features/operators/operators_screen.dart';
import 'package:arknight_nexus/i18n/nexus_i18n.dart';
import 'package:arknight_nexus/repositories/user_data_repository.dart';
import 'package:arknight_nexus/services/operator_service.dart';
import 'package:arknight_nexus/services/region_readiness.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:arknight_nexus/services/user_data_service.dart';
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

      await tester.tap(find.byKey(const Key('home-menu-operators')));
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

      await tester.tap(find.byKey(const Key('home-menu-operators')));
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
      await tester.tap(find.byKey(const Key('home-menu-operators')));
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
      await tester.tap(find.byKey(const Key('home-menu-operators')));
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
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // List stays; the pane shows the operator (header + hero name).
      expect(find.byType(OperatorDetailScreen), findsOneWidget);
      expect(find.text('Amiya'), findsOneWidget);
      expect(find.text('Doctor.'), findsOneWidget);
      expect(find.text('Kaltsit'), findsNWidgets(3));

      // Another tile switches the pane in place.
      await tester
          .tap(find.byKey(const ValueKey('operator-tile-char_002_amiya')));
      await tester.pumpAndSettle();
      expect(find.text('Leader'), findsOneWidget);

      // The pane's back button deselects.
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      expect(find.byType(OperatorsScreen), findsOneWidget);
      expect(find.text('Leader'), findsNothing);
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
      await tester.tap(find.byKey(const Key('home-menu-operators')));
      await tester.pumpAndSettle();

      const description = '검색과 필터를 고정 상단에서 바로 제어합니다.';
      expect(find.text(description), findsOneWidget);
      // The chip row always says when nothing is filtered.
      expect(find.text('필터 없음'), findsOneWidget);
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

      expect(find.text(description), findsNothing);
      expect(find.text('필터 없음'), findsOneWidget);

      // Batches of 24 are revealed as the sentinel nears the viewport.
      for (var i = 0; i < 40 && find.text('Op 79').evaluate().isEmpty; i++) {
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.text('Op 79'), findsOneWidget);
      expect(revealed(), 80);

      await tester.drag(scrollable, const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(find.text(description), findsOneWidget);
    });

    group('unreleased operators', () {
      const badge = '미실장 · CN';

      setUp(() => operatorService.addUnreleased());

      testWidgets(
          'are listed first with a badge, found by name and hidden '
          'by the toggle', (tester) async {
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
        expect(find.text('Nova'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('operator-unreleased-char_900_nova')),
          findsOneWidget,
        );
        expect(find.text(badge), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Nova')).dy,
          lessThan(tester.getTopLeft(find.text('Amiya')).dy + 1),
        );

        // The borrowed name is searchable like any other.
        await tester.enterText(find.byType(TextField), 'nov');
        await tester.pumpAndSettle();
        expect(find.text('Nova'), findsOneWidget);
        expect(find.text('Amiya'), findsNothing);
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();

        final toggle =
            find.byKey(const Key('operators-filter-hide-unreleased'));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('Nova'), findsNothing);
        expect(find.text(badge), findsNothing);
        expect(find.text('Amiya'), findsOneWidget);

        // The reset chip shows it again.
        final reset = find.byKey(const Key('operators-filter-chip-reset'));
        await tester.ensureVisible(reset);
        await tester.pumpAndSettle();
        await tester.tap(reset);
        await tester.pumpAndSettle();
        expect(find.text('Nova'), findsOneWidget);
      });

      testWidgets('show the badge in the detail header', (tester) async {
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

      testWidgets('PC sidebar toggle hides them', (tester) async {
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

        expect(find.text('Nova'), findsOneWidget);
        final toggle =
            find.byKey(const ValueKey('operators-filter-hide-unreleased'));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('Nova'), findsNothing);
        expect(find.text('Kaltsit'), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('Nova'), findsOneWidget);
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
      expect(find.text('미실장 · CN'), findsNothing);
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

      await tester.tap(find.byKey(const Key('home-menu-operators')));
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

      await tester.tap(find.byKey(const Key('home-menu-operators')));
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

      await tester.tap(find.byKey(const Key('home-menu-operators')));
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

      await tester.tap(find.byKey(const Key('home-menu-operators')));
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
