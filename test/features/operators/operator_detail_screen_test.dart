import 'package:arknight_nexus/app/providers.dart';
import 'package:arknight_nexus/app/theme.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/features/operators/operator_detail_screen.dart';
import 'package:arknight_nexus/features/operators/operator_detail_view_model.dart';
import 'package:arknight_nexus/i18n/nexus_i18n.dart';
import 'package:arknight_nexus/repositories/user_data_repository.dart';
import 'package:arknight_nexus/services/operator_service.dart';
import 'package:arknight_nexus/services/region_readiness.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:arknight_nexus/services/user_data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_image_cache_service.dart';
import '../../support/noop_app_logger.dart';

const _i18n = NexusI18n(RegionCode.kr);

void main() {
  late _MemoryUserDataRepository userData;
  late _FakeRegionSyncService sync;

  setUp(() {
    userData = _MemoryUserDataRepository();
    sync = _FakeRegionSyncService();
  });

  Future<void> pumpDetail(
    WidgetTester tester, {
    String id = _operatorId,
    // Below the operators master-detail width: the detail page.
    Size size = const Size(900, 6000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/operators/$id',
      routes: [
        GoRoute(
          path: '/operators',
          builder: (context, state) => const Scaffold(body: Text('LIST')),
        ),
        GoRoute(
          path: '/operators/:operatorId',
          builder: (context, state) => OperatorDetailScreen(
            operatorId: state.pathParameters['operatorId']!,
          ),
        ),
        GoRoute(
          path: '/plan/:operatorId',
          builder: (context, state) => Scaffold(
            body: Text('PLAN ${state.pathParameters['operatorId']}'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          operatorServiceProvider.overrideWithValue(
            EnsuringOperatorService(
              _FakeOperatorService(),
              RegionReadiness(sync, NoopAppLogger()),
            ),
          ),
          regionSyncServiceProvider.overrideWithValue(sync),
          userDataServiceProvider.overrideWithValue(UserDataService(userData)),
          imageCacheServiceProvider.overrideWithValue(FakeImageCacheService()),
        ],
        child: MaterialApp.router(
          theme: NexusTheme.dark(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders hero header and every detail section tab',
      (tester) async {
    await pumpDetail(tester);

    expect(sync.ensureFreshCalls, 1);
    // App bar title + hero name.
    expect(find.text('Testia'), findsNWidgets(2));
    expect(find.text('A quote.'), findsOneWidget);
    expect(find.text('Rhodes Island'), findsOneWidget);
    expect(find.text(_i18n.profession('Caster')), findsOneWidget);
    expect(find.text('Core Caster'), findsOneWidget);
    expect(find.text('Arts Damage'), findsOneWidget);
    expect(find.text('★★★★★'), findsOneWidget);

    // One tab per section, right under the hero, without a description
    // line for the tab or for the headings inside it.
    for (final section in [
      'stats',
      'abilities',
      'potentials',
      'modules',
      'skills',
    ]) {
      await openSection(tester, section);
      expect(
        find.text(_i18n.t('operatorDetail.summaries.$section')),
        findsNothing,
      );
      expect(
        find.text(_i18n.t('operatorDetail.sections.$section')),
        findsOneWidget,
      );
      for (final key in [
        'trait',
        'talent',
        'skillDisplayLevel',
        'skillLevelComparison',
      ]) {
        expect(
          find.text(_i18n.t('operatorDetail.descriptions.$key')),
          findsNothing,
          reason: '$section $key',
        );
      }
    }

    await openSection(tester, 'potentials');
    expect(
      find.text(_i18n.t('operatorDetail.labels.potentialStage', {'rank': 2})),
      findsOneWidget,
    );
    expect(find.text('Cost -1'), findsOneWidget);
  });

  testWidgets('elite and level controls recompute stats', (tester) async {
    await pumpDetail(tester);

    // E0 Lv1 -> min stats.
    expect(find.text('1000'), findsOneWidget);
    expect(find.text(_i18n.secondsValue('1.6')), findsOneWidget);

    // Switch to elite 1: level stays 1, E1 min stats.
    await tester.tap(
      find.image(const AssetImage('assets/icons/elite/1.webp')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('1500'), findsOneWidget);

    // Max out the level slider.
    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(2000, 0));
    await tester.pumpAndSettle();
    expect(find.text('2000'), findsOneWidget);
    expect(find.text('80/80'), findsOneWidget);

    // The stepper lowers the level by one.
    await tester.tap(find.byTooltip(_i18n.t('rd.operators.detail.levelDown')));
    await tester.pumpAndSettle();
    expect(find.text('79/80'), findsOneWidget);
  });

  testWidgets('elite segments show the icon alone and read out the phase',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpDetail(tester);

    final eliteName = _i18n.t('operatorDetail.labels.elite');
    expect(find.text('$eliteName 0'), findsNothing);
    expect(find.text('$eliteName 1'), findsNothing);
    expect(find.bySemanticsLabel('$eliteName 1'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('switches sections with the tabs', (tester) async {
    await pumpDetail(tester);

    final statLabel = find.text(_i18n.statLabel('hp'));
    expect(statLabel, findsOneWidget);
    await openSection(tester, 'skills');
    expect(statLabel, findsNothing);
    expect(find.text('Skill One'), findsWidgets);
  });

  testWidgets('toggles favorite with debounced persistence', (tester) async {
    await pumpDetail(tester);

    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pump();
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect((await userData.read()).favorites, isEmpty);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect((await userData.read()).favorites, [_operatorId]);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('adds the operator to the plan and opens the plan',
      (tester) async {
    await pumpDetail(tester);

    await tester.tap(find.byKey(const Key('operator-detail-add-to-plan')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect((await userData.read()).selectedOperatorIds, [_operatorId]);
    expect(find.text(_i18n.t('rd.operators.detail.added')), findsOneWidget);
    expect(find.byKey(const Key('operator-detail-in-plan')), findsOneWidget);
    expect(find.byKey(const Key('operator-detail-add-to-plan')), findsNothing);
    // Let the toast time out.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('operator-detail-open-plan')));
    await tester.pumpAndSettle();
    expect(find.text('PLAN $_operatorId'), findsOneWidget);
  });

  testWidgets('shows the in-plan state for planned operators', (tester) async {
    userData.data = const UserData(selectedOperatorIds: [_operatorId]);
    await pumpDetail(tester);

    expect(find.byKey(const Key('operator-detail-in-plan')), findsOneWidget);
  });

  testWidgets('folds potential talent variants into inline badges',
      (tester) async {
    await pumpDetail(tester);
    await openSection(tester, 'abilities');

    // Base value with the rank-5 diff badge.
    expect(find.text('15%(+5%)'), findsOneWidget);
    // Structurally different variant falls back to a separate description.
    expect(
      find.text(_i18n.t('operatorDetail.labels.potentialValue', {'value': 3})),
      findsOneWidget,
    );
    expect(
      find.text('Totally different text', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('opens the term drawer from a term link', (tester) async {
    await pumpDetail(tester);
    await openSection(tester, 'abilities');

    // The paragraph is stretched; tap on the term itself (left edge).
    await tester.tapAt(
      tester.getTopLeft(find.text('Stun', findRichText: true)) +
          const Offset(8, 8),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('term-drawer')), findsOneWidget);
    expect(
      find.text(_i18n.t('operatorDetail.labels.termSheet')),
      findsOneWidget,
    );
    expect(
      find.text('Cannot move or attack.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('module stage switch shows stat bonuses and overrides',
      (tester) async {
    await pumpDetail(tester);
    await openSection(tester, 'modules');

    expect(find.text('MOD-X'), findsOneWidget);
    expect(find.text('Test Module'), findsOneWidget);
    expect(
      find.text(_i18n.t('operatorDetail.labels.missionUnlocked')),
      findsOneWidget,
    );
    expect(find.text('+50'), findsOneWidget);
    expect(find.text('Upgraded Talent'), findsNothing);

    final stageSegment = find.descendant(
      of: find.byKey(const ValueKey('module-stage')),
      matching: find.text('2'),
    );
    await tester.tap(stageSegment);
    await tester.pumpAndSettle();

    expect(find.text('+80'), findsOneWidget);
    expect(find.text('Upgraded Talent'), findsOneWidget);
    expect(find.text('ATK 20%', findRichText: true), findsOneWidget);
  });

  testWidgets('skill selection, level slider and comparison table',
      (tester) async {
    await pumpDetail(tester);
    await openSection(tester, 'skills');

    expect(find.text('Skill One'), findsWidgets);
    expect(find.byKey(const ValueKey('skill-table')), findsWidgets);
    expect(find.text('SP Cost'), findsWidgets);
    expect(find.text('Atk Scale'), findsWidgets);
    expect(find.text('1.5'), findsWidgets);
    expect(find.text('Hit for 150%', findRichText: true), findsOneWidget);

    // Move the display level to the max: M3 icon in the summary chip, the
    // range chip, the slider readout and the table header.
    final levelSlider = find.byType(Slider).last;
    await tester.drag(levelSlider, const Offset(2000, 0));
    await tester.pumpAndSettle();
    expect(find.text('Hit for 240%', findRichText: true), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/icons/skill/10.png')),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('skill-level')),
        matching: find.image(const AssetImage('assets/icons/skill/10.png')),
      ),
      findsOneWidget,
    );

    // Select the second skill: level resets to 1.
    await tester.tap(find.byKey(const ValueKey('skill-skill_2')));
    await tester.pumpAndSettle();
    expect(find.text('Skill Two'), findsWidgets);
    expect(find.text('Second skill', findRichText: true), findsOneWidget);
    expect(find.text('Lv.1'), findsWidgets);
    expect(find.text(_i18n.skillRecovery('attack_recovery')), findsOneWidget);
  });

  testWidgets('shows not-found state for unknown operators', (tester) async {
    await pumpDetail(tester, id: 'char_missing');

    expect(
      find.text(_i18n.t('operatorDetail.states.notFoundTitle')),
      findsOneWidget,
    );
    await tester.tap(find.text(_i18n.t('operatorDetail.states.backToList')));
    await tester.pumpAndSettle();
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('lays out without overflow on a phone and on PC', (tester) async {
    for (final size in const [Size(390, 844), Size(1440, 900)]) {
      await pumpDetail(tester, size: size);
      for (final section in [
        'stats',
        'abilities',
        'potentials',
        'modules',
        'skills',
      ]) {
        await openSection(tester, section);
        expect(tester.takeException(), isNull, reason: '$size $section');
      }
      expect(
        find.byKey(const Key('operator-detail-add-to-plan')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('operator-detail-open-plan')),
        findsOneWidget,
      );
    }
  });

  test('range matrix places origin and active cells', () {
    final matrix = buildRangeMatrix(
      const OperatorRange(
        id: 'x',
        grids: [
          OperatorRangeGrid(row: 0, col: 1),
          OperatorRangeGrid(row: 1, col: 1),
        ],
      ),
    )!;
    expect(matrix.columnCount, 2);
    expect(matrix.rows.length, 2);
    // Rows run from max row down to min row.
    expect(matrix.rows[0][1].isActive, isTrue);
    expect(matrix.rows[1][0].isOrigin, isTrue);
    expect(matrix.rows[1][1].isActive, isTrue);
  });
}

const _operatorId = 'char_test';

OperatorStatPoint _stat(int hp, int atk, double interval) => OperatorStatPoint(
      hp: hp,
      attack: atk,
      defense: 100,
      resistance: 10,
      redeployTime: 70,
      dpCost: 18,
      block: 1,
      attackInterval: interval,
    );

OperatorSkillLevel _skillLevel(int level, double scale) => OperatorSkillLevel(
      level: level,
      spCost: 40 - level,
      initialSp: 10,
      duration: 20,
      description: 'Hit for {atk_scale:0%}',
      blackboard: [OperatorBlackboardEntry(key: 'atk_scale', value: scale)],
      range: const OperatorRange(
        id: 'skill-range',
        grids: [OperatorRangeGrid(row: 0, col: 1)],
      ),
    );

final _fixture = OperatorDetail(
  id: _operatorId,
  name: 'Testia',
  codename: 'Testia',
  rarity: 5,
  profession: 'Caster',
  branch: 'Core Caster',
  teams: const ['Rhodes Island'],
  thumbnailHue: 200,
  quote: 'A quote.',
  tags: const ['Arts Damage'],
  archetypeDescription: 'Deals arts damage',
  eliteCaps: const [50, 80],
  stats: [
    OperatorStatProgression(
      level: 50,
      min: _stat(1000, 300, 1.6),
      max: _stat(1400, 400, 1.6),
      range: const OperatorRange(
        id: 'r0',
        grids: [OperatorRangeGrid(row: 0, col: 1)],
      ),
    ),
    OperatorStatProgression(
      level: 80,
      min: _stat(1500, 450, 1.6),
      max: _stat(2000, 600, 1.6),
    ),
  ],
  traits: const [
    OperatorTrait(
      groupKey: 'trait',
      description: 'Deals arts damage',
      elite: 0,
      level: 1,
      requiredPotentialRank: 0,
    ),
  ],
  talents: const [
    OperatorTalent(
      groupKey: 'talent_1',
      name: 'Focus',
      description: 'ATK {atk:0%} up',
      elite: 0,
      level: 1,
      requiredPotentialRank: 0,
      blackboard: [OperatorBlackboardEntry(key: 'atk', value: 0.1)],
    ),
    OperatorTalent(
      groupKey: 'talent_1',
      name: 'Focus',
      description: 'ATK {atk:0%} up',
      elite: 0,
      level: 1,
      requiredPotentialRank: 4,
      blackboard: [OperatorBlackboardEntry(key: 'atk', value: 0.15)],
    ),
    OperatorTalent(
      groupKey: 'talent_1',
      name: 'Focus',
      description: 'Totally different text',
      elite: 0,
      level: 1,
      requiredPotentialRank: 2,
    ),
    OperatorTalent(
      groupKey: 'talent_2',
      name: 'Shock',
      description: r'<$ba.stun>Stun</>',
      elite: 0,
      level: 1,
      requiredPotentialRank: 0,
    ),
  ],
  potentials: const [
    OperatorPotential(rank: 1, description: 'Cost -1'),
    OperatorPotential(rank: 2, description: 'ATK +25'),
  ],
  modules: const [
    OperatorModule(
      uniEquipId: 'uniequip_test',
      uniEquipName: 'Test Module',
      uniEquipIcon: 'test_module',
      uniEquipDesc: '',
      typeIcon: 'mod-x',
      unlockEvolvePhase: 'PHASE_1',
      charId: _operatorId,
      unlockLevel: 40,
      missionList: ['mission_1'],
      unlockFavorPercents: {'1': 0, '2': 100},
      isSpecialEquip: false,
      battlePhases: [
        OperatorModuleBattlePhase(
          equipLevel: 1,
          attributeBlackboard: [
            OperatorBlackboardEntry(key: 'atk', value: 50),
          ],
        ),
        OperatorModuleBattlePhase(
          equipLevel: 2,
          attributeBlackboard: [
            OperatorBlackboardEntry(key: 'atk', value: 80),
          ],
          parts: [
            OperatorModuleBattlePart(
              target: 'TALENT',
              talentCandidates: [
                OperatorTalentCandidate(
                  name: 'Upgraded Talent',
                  description: 'ATK {atk:0%}',
                  elite: 1,
                  level: 1,
                  requiredPotentialRank: 0,
                  blackboard: [OperatorBlackboardEntry(key: 'atk', value: 0.2)],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
  skills: [
    OperatorSkill(
      id: 'skill_1',
      name: 'Skill One',
      recoveryType: 'auto_recovery',
      activationType: 'manual_trigger',
      description: '',
      unlockElite: 0,
      unlockLevel: 1,
      levels: [
        for (var level = 1; level <= 10; level++)
          _skillLevel(level, 1.5 + (level - 1) * 0.1),
      ],
    ),
    const OperatorSkill(
      id: 'skill_2',
      name: 'Skill Two',
      recoveryType: 'attack_recovery',
      activationType: 'auto_trigger',
      description: '',
      unlockElite: 1,
      unlockLevel: 1,
      levels: [
        OperatorSkillLevel(
          level: 1,
          spCost: 5,
          initialSp: 0,
          duration: 0,
          description: 'Second skill',
        ),
      ],
    ),
  ],
);

class _FakeOperatorService implements OperatorService {
  @override
  Future<OperatorDetail?> getOperatorDetail(
    RegionCode region,
    String operatorId,
  ) async {
    return operatorId == _operatorId ? _fixture : null;
  }

  @override
  Future<List<OperatorSummary>> listOperators(OperatorQuery query) async =>
      const [];
}

class _FakeRegionSyncService implements RegionSyncService {
  int ensureFreshCalls = 0;

  @override
  Future<SyncResult> ensureRegionFresh(RegionCode region) async {
    ensureFreshCalls += 1;
    return SyncResult(
      region: region,
      sourceRevision: 'main',
      sourceVersion: 'test',
      updatedAt: '2026-05-17T00:00:00Z',
      operatorCount: 1,
      status: 'ready',
    );
  }

  @override
  Future<RegionSyncStatus?> getRegionSyncStatus(RegionCode region) async =>
      null;

  @override
  Future<Map<String, String>> getRegionStageCodes(RegionCode region) async =>
      const {};

  @override
  Future<Map<String, String>> getRegionTerms(RegionCode region) async =>
      const {'ba.stun': 'Cannot move or attack.'};

  @override
  Stream<SyncStatus> syncRegion(RegionCode region) async* {}
}

class _MemoryUserDataRepository implements UserDataRepository {
  UserData data = const UserData();

  @override
  Future<void> backup() async {}

  @override
  Future<UserData> read() async => data;

  @override
  Future<void> write(UserData data) async {
    this.data = data;
  }
}

/// Taps a section tab (the header pill repeats the current label).
Future<void> openSection(WidgetTester tester, String section) async {
  final tab = find.descendant(
    of: find.byKey(const ValueKey('detail-tabs')),
    matching: find.text(_i18n.t('operatorDetail.sections.$section')),
  );
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}
