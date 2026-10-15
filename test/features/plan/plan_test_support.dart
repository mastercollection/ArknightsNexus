import 'package:arknight_nexus/app/providers.dart';
import 'package:arknight_nexus/app/shell.dart';
import 'package:arknight_nexus/app/theme.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/building_formula.dart';
import 'package:arknight_nexus/domain/item.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/features/plan/operator_plan_screen.dart';
import 'package:arknight_nexus/features/plan/plan_screen.dart';
import 'package:arknight_nexus/repositories/user_data_repository.dart';
import 'package:arknight_nexus/services/item_service.dart';
import 'package:arknight_nexus/services/operator_service.dart';
import 'package:arknight_nexus/services/user_data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_image_cache_service.dart';

/// Pumps the full app with in-memory plan data and opens the Plan page from
/// the home menu. [size] picks the layout (phone 390x844, PC 1440x900...);
/// [inShell] wraps the plan routes in the app's [NexusShell].
Future<void> pumpPlanPage(
  WidgetTester tester, {
  required PlanFakeOperatorService operatorService,
  required PlanFakeItemService itemService,
  required PlanMemoryUserDataRepository userDataRepository,
  Size size = const Size(1000, 2400),
  bool inShell = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        operatorServiceProvider.overrideWithValue(operatorService),
        itemServiceProvider.overrideWithValue(itemService),
        userDataServiceProvider.overrideWithValue(
          UserDataService(userDataRepository),
        ),
        imageCacheServiceProvider.overrideWithValue(FakeImageCacheService()),
      ],
      child: MaterialApp.router(
        theme: NexusTheme.dark(),
        routerConfig: _planTestRouter(inShell: inShell),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open plan'));
  await tester.pumpAndSettle();
}

/// Router limited to the plan feature so these tests do not depend on other
/// screens. `/items/:itemId` is a stub target for material links.
GoRouter _planTestRouter({required bool inShell}) {
  final planRoutes = <RouteBase>[
    GoRoute(
      path: '/plan',
      builder: (context, state) => const PlanScreen(),
    ),
    GoRoute(
      path: '/plan/:operatorId',
      builder: (context, state) => OperatorPlanScreen(
        operatorId: state.pathParameters['operatorId']!,
      ),
    ),
    GoRoute(
      path: '/items/:itemId',
      builder: (context, state) =>
          Scaffold(body: Text('item:${state.pathParameters['itemId']}')),
    ),
  ];
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push('/plan'),
              child: const Text('Open plan'),
            ),
          ),
        ),
      ),
      if (inShell)
        ShellRoute(
          builder: (context, state, child) =>
              NexusShell(location: state.uri.toString(), child: child),
          routes: planRoutes,
        )
      else
        ...planRoutes,
    ],
  );
}

/// Finds text inside plain [Text] widgets and [Text.rich] spans.
Finder findPlanText(String text) => find.text(text, findRichText: true);

class PlanFakeOperatorService implements OperatorService {
  PlanFakeOperatorService(this.operators);

  final List<OperatorDetail> operators;

  /// Makes [listOperators] throw (page load error).
  bool failList = false;

  @override
  Future<List<OperatorSummary>> listOperators(OperatorQuery query) async {
    if (failList) {
      throw StateError('list failed');
    }
    return operators
        .map(
          (operator) => OperatorSummary(
            id: operator.id,
            name: operator.name,
            rarity: operator.rarity,
            profession: operator.profession,
            branch: operator.branch,
            thumbnailHue: operator.thumbnailHue,
          ),
        )
        .toList();
  }

  @override
  Future<OperatorDetail?> getOperatorDetail(
    RegionCode region,
    String operatorId,
  ) async {
    for (final operator in operators) {
      if (operator.id == operatorId) {
        return operator;
      }
    }
    return null;
  }
}

class PlanFakeItemService implements ItemService {
  PlanFakeItemService({this.formulas = const BuildingFormulaBundle()});

  final BuildingFormulaBundle formulas;

  @override
  Future<BuildingFormulaBundle> listBuildingFormulas(RegionCode region) async {
    return formulas;
  }

  @override
  Future<List<ItemEntry>> listItems(ItemQuery query) async {
    return const [
      ItemEntry(
        itemId: '4001',
        name: 'LMD',
        description: '',
        rarity: '4',
        iconId: 'lmd',
        sortId: 1,
        usage: '',
        obtainApproach: '',
        classifyType: 'MATERIAL',
        itemType: 'MATERIAL',
      ),
      ItemEntry(
        itemId: '5001',
        name: 'EXP',
        description: '',
        rarity: '4',
        iconId: 'exp',
        sortId: 2,
        usage: '',
        obtainApproach: '',
        classifyType: 'MATERIAL',
        itemType: 'MATERIAL',
      ),
      ItemEntry(
        itemId: 'skill_book',
        name: 'Skill Book',
        description: '',
        rarity: '3',
        iconId: 'skill_book',
        sortId: 3,
        usage: '',
        obtainApproach: '',
        classifyType: 'MATERIAL',
        itemType: 'MATERIAL',
        ownedCount: 1,
      ),
      ItemEntry(
        itemId: 'skill_page',
        name: 'Skill Page',
        description: '',
        rarity: '2',
        iconId: 'skill_page',
        sortId: 4,
        usage: '',
        obtainApproach: '',
        classifyType: 'MATERIAL',
        itemType: 'MATERIAL',
      ),
    ];
  }
}

/// Workshop recipe: 1 Skill Book <- 2 Skill Page.
const planSkillBookFormulas = BuildingFormulaBundle(
  workshopFormulas: [
    WorkshopFormula(
      sortId: 1,
      formulaId: 'w1',
      rarity: 3,
      itemId: 'skill_book',
      count: 1,
      goldCost: 0,
      apCost: 0,
      formulaType: 'F_SKILL',
      buffType: '',
      extraOutcomeRate: 0,
      costs: [FormulaCost(id: 'skill_page', count: 2, type: 'MATERIAL')],
    ),
  ],
);

class PlanMemoryUserDataRepository implements UserDataRepository {
  PlanMemoryUserDataRepository(this.data);

  UserData data;

  /// Makes every [write] throw (autosave failure).
  bool failWrites = false;

  @override
  Future<void> backup() async {}

  @override
  Future<UserData> read() async => data;

  @override
  Future<void> write(UserData data) async {
    if (failWrites) {
      throw StateError('disk full');
    }
    this.data = data;
  }
}

OperatorDetail planOperatorDetail(
  String id,
  String name,
  String profession, {
  List<OperatorModule> modules = const [],
}) {
  return OperatorDetail(
    id: id,
    name: name,
    codename: name,
    rarity: 6,
    profession: profession,
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
    modules: modules,
    allSkillLevelUpCosts: const [
      OperatorUpgradeCostStage(
        level: 2,
        costs: [
          OperatorCost(
            id: 'skill_book',
            count: 3,
            type: 'MATERIAL',
            itemName: 'Skill Book',
            itemRarity: '3',
            itemIconId: 'skill_book',
            itemType: 'MATERIAL',
          ),
        ],
      ),
      OperatorUpgradeCostStage(
        level: 3,
        costs: [
          OperatorCost(
            id: 'skill_book',
            count: 4,
            type: 'MATERIAL',
            itemName: 'Skill Book',
            itemRarity: '3',
            itemIconId: 'skill_book',
            itemType: 'MATERIAL',
          ),
        ],
      ),
    ],
    skills: const [
      OperatorSkill(
        id: 'skill_1',
        name: 'Skill 1',
        recoveryType: 'AUTO',
        activationType: 'MANUAL',
        description: '',
      ),
    ],
  );
}

const planTestModule = OperatorModule(
  uniEquipId: 'uniequip_002_amiya',
  uniEquipName: 'Amiya Module',
  uniEquipIcon: '',
  uniEquipDesc: '',
  typeIcon: '',
  unlockEvolvePhase: 'PHASE_2',
  charId: 'char_002_amiya',
  unlockLevel: 40,
  isSpecialEquip: false,
  battlePhases: [
    OperatorModuleBattlePhase(equipLevel: 1),
    OperatorModuleBattlePhase(equipLevel: 2),
    OperatorModuleBattlePhase(equipLevel: 3),
  ],
);
