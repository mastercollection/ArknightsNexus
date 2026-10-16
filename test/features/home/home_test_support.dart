import 'dart:async';

import 'package:arknight_nexus/app/providers.dart';
import 'package:arknight_nexus/app/shell.dart';
import 'package:arknight_nexus/app/theme.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/building_formula.dart';
import 'package:arknight_nexus/domain/item.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/features/home/home_screen.dart';
import 'package:arknight_nexus/features/settings/settings_screen.dart';
import 'package:arknight_nexus/repositories/user_data_repository.dart';
import 'package:arknight_nexus/services/item_service.dart';
import 'package:arknight_nexus/services/operator_service.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:arknight_nexus/services/user_data_file_service.dart';
import 'package:arknight_nexus/services/user_data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_diagnostics_service.dart';
import '../../support/fake_image_cache_service.dart';
import '../../support/noop_app_logger.dart';

const phoneSize = Size(390, 844);
const desktopSize = Size(1440, 900);

/// Pumps home and settings inside the real [NexusShell] with a router that
/// stubs the other areas' pages (so these tests only depend on this area).
Future<GoRouter> pumpHomeArea(
  WidgetTester tester, {
  required Size size,
  HomeFakeRegionSyncService? regionSync,
  bool settle = true,
  HomeFakeOperatorService? operators,
  HomeFakeItemService? items,
  HomeMemoryUserDataRepository? userData,
  FakeDiagnosticsService? diagnostics,
  UserDataFileService? userDataFiles,
  String initialLocation = '/',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            NexusShell(location: state.uri.toString(), child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/operators',
            builder: (_, state) => _Stub(
              'operators:${state.uri.queryParameters['q'] ?? ''}',
            ),
          ),
          GoRoute(path: '/items', builder: (_, __) => const _Stub('items')),
          GoRoute(path: '/plan', builder: (_, __) => const _Stub('plan')),
          GoRoute(
            path: '/plan/:id',
            builder: (_, state) => _Stub('plan:${state.pathParameters['id']}'),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLoggerProvider.overrideWithValue(NoopAppLogger()),
        regionSyncServiceProvider.overrideWithValue(
          regionSync ?? HomeFakeRegionSyncService(),
        ),
        operatorServiceProvider.overrideWithValue(
          operators ?? HomeFakeOperatorService(),
        ),
        itemServiceProvider.overrideWithValue(items ?? HomeFakeItemService()),
        userDataServiceProvider.overrideWithValue(
          UserDataService(userData ?? HomeMemoryUserDataRepository()),
        ),
        imageCacheServiceProvider.overrideWithValue(FakeImageCacheService()),
        diagnosticsServiceProvider.overrideWithValue(
          diagnostics ?? FakeDiagnosticsService(),
        ),
        if (userDataFiles != null)
          userDataFileServiceProvider.overrideWithValue(userDataFiles),
      ],
      child: MaterialApp.router(
        theme: NexusTheme.dark(),
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
  return router;
}

class _Stub extends StatelessWidget {
  const _Stub(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Material(child: Center(child: Text('stub $label')));
}

class HomeFakeRegionSyncService implements RegionSyncService {
  int syncCalls = 0;
  int ensureCalls = 0;
  bool ready = true;

  /// When set, [ensureRegionFresh] waits for it and then marks the region
  /// ready, like a first visit downloading the region.
  Completer<void>? ensureGate;
  bool failSync = false;
  final statusRegions = <RegionCode>[];

  @override
  Future<SyncResult> ensureRegionFresh(RegionCode region) async {
    ensureCalls += 1;
    final gate = ensureGate;
    if (gate != null) {
      await gate.future;
      ready = true;
    }
    return SyncResult(
      region: region,
      sourceRevision: 'main',
      sourceVersion: 'test',
      updatedAt: '2026-05-17T00:00:00Z',
      operatorCount: 415,
      status: 'ready',
    );
  }

  @override
  Future<RegionSyncStatus?> getRegionSyncStatus(RegionCode region) async {
    statusRegions.add(region);
    return RegionSyncStatus(
      region: region,
      operatorCount: 415,
      isReady: ready,
    );
  }

  @override
  Future<Map<String, String>> getRegionStageCodes(RegionCode region) async =>
      const {};

  @override
  Future<Map<String, String>> getRegionTerms(RegionCode region) async =>
      const {};

  @override
  Stream<SyncStatus> syncRegion(RegionCode region) async* {
    syncCalls += 1;
    yield SyncStatus(region: region, phase: SyncPhase.checkingVersion);
    if (failSync) {
      throw StateError('sync exploded');
    }
    ready = true;
    yield SyncStatus(region: region, phase: SyncPhase.complete);
  }
}

class HomeFakeOperatorService implements OperatorService {
  HomeFakeOperatorService({this.details = const [], this.summaries = const []});

  final List<OperatorDetail> details;

  /// Listed after the [details]' summaries (e.g. unreleased operators).
  final List<OperatorSummary> summaries;

  @override
  Future<OperatorDetail?> getOperatorDetail(
    RegionCode region,
    String operatorId,
  ) async {
    return details.where((detail) => detail.id == operatorId).firstOrNull;
  }

  @override
  Future<List<OperatorSummary>> listOperators(OperatorQuery query) async {
    return [
      for (final detail in details)
        OperatorSummary(
          id: detail.id,
          name: detail.name,
          rarity: detail.rarity,
          profession: detail.profession,
          branch: detail.branch,
          thumbnailHue: detail.thumbnailHue,
        ),
      ...summaries,
    ];
  }
}

class HomeFakeItemService implements ItemService {
  HomeFakeItemService({this.items = const []});

  final List<ItemEntry> items;

  @override
  Future<BuildingFormulaBundle> listBuildingFormulas(RegionCode region) async =>
      const BuildingFormulaBundle();

  @override
  Future<List<ItemEntry>> listItems(ItemQuery query) async => items;
}

class HomeMemoryUserDataRepository implements UserDataRepository {
  HomeMemoryUserDataRepository([this.data = const UserData()]);

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

/// Minimal six-star operator: E0 levels cost 100/200/300 EXP and 10/20/30
/// LMD, promotion to E1 costs 1000 LMD.
OperatorDetail homeOperatorDetail(String id, String name) {
  return OperatorDetail(
    id: id,
    name: name,
    codename: name,
    rarity: 6,
    profession: 'Medic',
    branch: 'Core',
    thumbnailHue: 210,
    quote: '',
    archetypeDescription: '',
    eliteCaps: const [50, 80, 90],
    eliteExpCosts: const [
      [100, 200, 300],
      [],
      [],
    ],
    eliteUpgradeGoldCosts: const [
      [10, 20, 30],
      [],
      [],
    ],
    eliteEvolveGoldCosts: const [1000, 2000],
  );
}

ItemEntry homeLmdItem({int owned = 0}) => ItemEntry(
      itemId: '4001',
      name: '용문폐',
      description: '',
      rarity: '4',
      iconId: 'GOLD',
      sortId: 1,
      usage: '',
      obtainApproach: '',
      classifyType: 'NONE',
      itemType: 'GOLD',
      ownedCount: owned,
    );

UserPlanOperator homePlan(String id) => UserPlanOperator(
      operatorId: id,
      current: const UserPlanOperatorState(elite: 0, level: 1),
      target: const UserPlanOperatorState(elite: 1, level: 1),
    );

/// Fails the test when anything (overflow included) threw while pumping.
void expectNoErrors(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}
