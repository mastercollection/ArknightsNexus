import 'package:arknight_nexus/domain/building_formula.dart';
import 'package:arknight_nexus/domain/item.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/services/plan_cost_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DartPlanCostService', () {
    const service = DartPlanCostService();

    test('creates a default plan from operator skill and module data', () {
      final detail = _operatorDetail();

      final plan = service.createDefaultPlanOperator(detail);

      expect(plan.operatorId, 'char_001_test');
      expect(plan.current.elite, 0);
      expect(plan.current.level, 1);
      expect(plan.current.skillLevels, [1, 1, 1]);
      expect(plan.target.elite, 2);
      expect(plan.target.level, 90);
      expect(plan.target.skillLevels, [1, 1, 1]);
      expect(plan.target.modules.single.targetStage, 3);
    });

    test('calculates level, promotion, skill, module, exp, and lmd costs', () {
      final detail = _operatorDetail();
      const plan = UserPlanOperator(
        operatorId: 'char_001_test',
        current: UserPlanOperatorState(
          elite: 0,
          level: 1,
          skillLevels: [1],
          modules: [
            UserPlanModule(
              moduleId: 'uniequip_001_test',
              currentStage: 0,
              targetStage: 0,
            ),
          ],
        ),
        target: UserPlanOperatorState(
          elite: 1,
          level: 2,
          skillLevels: [8],
          modules: [
            UserPlanModule(
              moduleId: 'uniequip_001_test',
              currentStage: 0,
              targetStage: 2,
            ),
          ],
        ),
      );

      final result = service.calculatePlanCostsWithItems(
        detail,
        plan,
        _itemsById,
      );
      final materials = {
        for (final material in result.materials) material.id: material,
      };

      expect(result.valid, isTrue);
      expect(result.exp, 600);
      expect(result.errors, isEmpty);
      expect(materials['4001']?.name, 'LMD');
      expect(materials['4001']?.count, 560);
      expect(materials['mat_evolve']?.count, 2);
      expect(materials['mat_skill']?.count, 8);
      expect(materials['mat_mastery']?.count, 8);
      expect(materials['mat_module']?.count, 3);
    });

    test('returns validation errors for reversed ranges', () {
      final result = service.calculatePlanCostsWithItems(
        _operatorDetail(),
        const UserPlanOperator(
          operatorId: 'char_001_test',
          current: UserPlanOperatorState(
            elite: 1,
            level: 20,
            skillLevels: [9],
            modules: [
              UserPlanModule(
                moduleId: 'uniequip_001_test',
                currentStage: 2,
                targetStage: 0,
              ),
            ],
          ),
          target: UserPlanOperatorState(
            elite: 0,
            level: 10,
            skillLevels: [7],
            modules: [
              UserPlanModule(
                moduleId: 'uniequip_001_test',
                currentStage: 2,
                targetStage: 1,
              ),
            ],
          ),
        ),
        const {},
      );

      expect(result.valid, isFalse);
      expect(result.materials, isEmpty);
      expect(result.errors, contains('Test Operator: 초기 육성 단계가 목표보다 높습니다.'));
      expect(result.errors, contains('Test Operator: 스킬 1의 초기 레벨이 목표보다 높습니다.'));
      expect(result.errors, contains('Test Operator: 모듈 단계 설정이 올바르지 않습니다.'));
    });

    test('aggregates operator costs and estimates farming runs', () {
      final detail = _operatorDetail();
      final plan = service.resolvePlanOperator(
        detail,
        const UserPlanOperator(
          operatorId: 'char_001_test',
          current: UserPlanOperatorState(elite: 0, level: 1),
          target: UserPlanOperatorState(elite: 0, level: 3),
        ),
      );

      final aggregate = service.aggregatePlanCostsWithItems(
        [
          PlanCostEntry(detail: detail, plan: plan),
          PlanCostEntry(detail: detail, plan: plan),
        ],
        _itemsById,
      );
      final farming = service.estimatePlanFarming(aggregate);

      expect(aggregate.valid, isTrue);
      expect(aggregate.operatorCount, 2);
      expect(aggregate.exp, 600);
      expect(
        aggregate.materials.singleWhere((entry) => entry.id == '4001').count,
        60,
      );
      expect(farming.expStage.code, 'LS-6');
      expect(farming.expStage.runs, 1);
      expect(farming.lmdStage.code, 'CE-6');
      expect(farming.lmdStage.runs, 1);
      expect(farming.totalSanity, 72);
    });

    test('expands crafting recipes into lower-tier materials and lmd', () {
      final expanded = service.expandPlanMaterials(
        const [
          PlanMaterialTotal(
            id: 'mat_t4',
            name: 'T4 Material',
            rarity: '4',
            count: 3,
          ),
        ],
        const BuildingFormulaBundle(
          workshopFormulas: [
            WorkshopFormula(
              sortId: 1,
              formulaId: 'workshop_t4',
              rarity: 4,
              itemId: 'mat_t4',
              count: 2,
              goldCost: 100,
              apCost: 0,
              formulaType: 'F_EVOLVE',
              buffType: 'NONE',
              extraOutcomeRate: 0,
              costs: [
                FormulaCost(id: 'mat_t3', count: 2, type: 'MATERIAL'),
              ],
            ),
          ],
          manufactFormulas: [
            ManufacturingFormula(
              formulaId: 'manufact_t3',
              itemId: 'mat_t3',
              count: 1,
              weight: 1,
              costPoint: 0,
              formulaType: 'F_ASC',
              buffType: 'NONE',
              costs: [
                FormulaCost(id: 'mat_t2', count: 3, type: 'MATERIAL'),
              ],
            ),
          ],
        ),
        _itemsById,
      );
      final materials = {
        for (final material in expanded) material.id: material,
      };

      expect(materials['mat_t2']?.count, 12);
      expect(materials['4001']?.count, 200);
      expect(materials.containsKey('mat_t4'), isFalse);
      expect(materials.containsKey('mat_t3'), isFalse);
    });
  });
}

final _itemsById = {
  '4001': _item('4001', 'LMD', rarity: '4', ownedCount: 100),
  'mat_evolve': _item('mat_evolve', 'Evolve Material', rarity: '4'),
  'mat_skill': _item('mat_skill', 'Skill Material', rarity: '3'),
  'mat_mastery': _item('mat_mastery', 'Mastery Material', rarity: '4'),
  'mat_module': _item('mat_module', 'Module Material', rarity: '5'),
  'mat_t2': _item('mat_t2', 'T2 Material', rarity: '2'),
  'mat_t3': _item('mat_t3', 'T3 Material', rarity: '3'),
  'mat_t4': _item('mat_t4', 'T4 Material', rarity: '4'),
};

ItemEntry _item(
  String itemId,
  String name, {
  String rarity = '1',
  int ownedCount = 0,
}) {
  return ItemEntry(
    itemId: itemId,
    name: name,
    description: '',
    rarity: rarity,
    iconId: '${itemId}_icon',
    sortId: 0,
    usage: '',
    obtainApproach: '',
    classifyType: 'MATERIAL',
    itemType: 'MATERIAL',
    ownedCount: ownedCount,
  );
}

OperatorDetail _operatorDetail() {
  return const OperatorDetail(
    id: 'char_001_test',
    name: 'Test Operator',
    codename: 'test',
    rarity: 6,
    profession: 'CASTER',
    branch: 'CORE_CASTER',
    thumbnailHue: 120,
    quote: '',
    archetypeDescription: '',
    eliteCaps: [50, 80, 90],
    eliteExpCosts: [
      [100, 200, 0],
      [300],
      [],
    ],
    eliteUpgradeGoldCosts: [
      [10, 20, 0],
      [30],
      [],
    ],
    eliteEvolveGoldCosts: [500, 0],
    eliteEvolveCosts: [
      [
        OperatorCost(
          id: 'mat_evolve',
          count: 2,
          type: 'MATERIAL',
          itemName: 'Evolve Material',
          itemRarity: '4',
          itemIconId: 'mat_evolve_icon',
          itemType: 'MATERIAL',
        ),
      ],
    ],
    allSkillLevelUpCosts: [
      OperatorUpgradeCostStage(
        level: 2,
        costs: [
          OperatorCost(
            id: 'mat_skill',
            count: 1,
            type: 'MATERIAL',
            itemName: 'Skill Material',
            itemRarity: '3',
            itemIconId: 'mat_skill_icon',
            itemType: 'MATERIAL',
          ),
        ],
      ),
      OperatorUpgradeCostStage(
        level: 7,
        costs: [
          OperatorCost(
            id: 'mat_skill',
            count: 7,
            type: 'MATERIAL',
            itemName: 'Skill Material',
            itemRarity: '3',
            itemIconId: 'mat_skill_icon',
            itemType: 'MATERIAL',
          ),
        ],
      ),
    ],
    skills: [
      OperatorSkill(
        id: 'skill_001_test',
        name: 'Test Skill',
        recoveryType: 'AUTO',
        activationType: 'MANUAL',
        description: '',
        upgradeCosts: [
          OperatorUpgradeCostStage(
            level: 8,
            costs: [
              OperatorCost(
                id: 'mat_mastery',
                count: 8,
                type: 'MATERIAL',
                itemName: 'Mastery Material',
                itemRarity: '4',
                itemIconId: 'mat_mastery_icon',
                itemType: 'MATERIAL',
              ),
            ],
          ),
        ],
      ),
    ],
    modules: [
      OperatorModule(
        uniEquipId: 'uniequip_001_test',
        uniEquipName: 'Test Module',
        uniEquipIcon: '',
        uniEquipDesc: '',
        typeIcon: '',
        unlockEvolvePhase: 'PHASE_2',
        charId: 'char_001_test',
        unlockLevel: 60,
        itemCost: {
          '1': [
            OperatorCost(
              id: 'mat_module',
              count: 1,
              type: 'MATERIAL',
              itemName: 'Module Material',
              itemRarity: '5',
              itemIconId: 'mat_module_icon',
              itemType: 'MATERIAL',
            ),
          ],
          '2': [
            OperatorCost(
              id: 'mat_module',
              count: 2,
              type: 'MATERIAL',
              itemName: 'Module Material',
              itemRarity: '5',
              itemIconId: 'mat_module_icon',
              itemType: 'MATERIAL',
            ),
          ],
        },
        isSpecialEquip: false,
        battlePhases: [
          OperatorModuleBattlePhase(equipLevel: 1),
          OperatorModuleBattlePhase(equipLevel: 2),
          OperatorModuleBattlePhase(equipLevel: 3),
        ],
      ),
    ],
  );
}
