import 'dart:convert';

import 'package:arknight_nexus/data_sources/data_version.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/building_formula.dart';
import 'package:arknight_nexus/domain/item.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/region_snapshot.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('domain JSON contracts', () {
    test('round trips item entries with camelCase fields', () {
      const item = ItemEntry(
        itemId: '30012',
        name: 'Oriron',
        description: 'Material',
        rarity: '3',
        iconId: 'MTL_SL_Orirock',
        sortId: 10,
        usage: 'Upgrade',
        obtainApproach: 'Stage',
        classifyType: 'MATERIAL',
        itemType: 'MATERIAL',
        ownedCount: 7,
        stageDropList: [
          ItemStageDrop(
            stageId: 'main_01-07',
            stageCode: '1-7',
            occPer: 'ALWAYS',
          ),
        ],
        buildingProductList: [
          ItemBuildingProduct(roomType: 'WORKSHOP', formulaId: 'formula_1'),
        ],
      );

      final json = item.toJson();
      final decoded = ItemEntry.fromJson(json);

      expect(json['itemId'], '30012');
      expect(json['stageDropList'], isA<List<Object?>>());
      expect(decoded.stageDropList.single.stageCode, '1-7');
      expect(decoded.buildingProductList.single.formulaId, 'formula_1');
    });

    test('round trips building formula bundles', () {
      const bundle = BuildingFormulaBundle(
        manufactFormulas: [
          ManufacturingFormula(
            formulaId: 'manufact_1',
            itemId: '30012',
            count: 1,
            weight: 100,
            costPoint: 60,
            formulaType: 'NORMAL',
            buffType: 'NONE',
            costs: [FormulaCost(id: 'gold', count: 100, type: 'GOLD')],
            requireRooms: [
              FormulaRoomRequirement(
                roomId: 'MANUFACTURE',
                roomLevel: 1,
                roomCount: 1,
              ),
            ],
          ),
        ],
        workshopFormulas: [
          WorkshopFormula(
            sortId: 1,
            formulaId: 'workshop_1',
            rarity: 3,
            itemId: '30013',
            count: 1,
            goldCost: 200,
            apCost: 0,
            formulaType: 'NORMAL',
            buffType: 'NONE',
            extraOutcomeRate: 0.1,
            extraOutcomeGroup: [
              FormulaExtraOutcome(weight: 1, itemId: '30012', itemCount: 1),
            ],
            costs: [FormulaCost(id: '30012', count: 2, type: 'MATERIAL')],
            requireRooms: [
              FormulaRoomRequirement(
                roomId: 'WORKSHOP',
                roomLevel: 2,
                roomCount: 1,
              ),
            ],
          ),
        ],
      );

      final decoded = BuildingFormulaBundle.fromJson(bundle.toJson());

      expect(decoded.manufactFormulas.single.costs.single.type, 'GOLD');
      expect(
        decoded.workshopFormulas.single.extraOutcomeGroup.single.itemId,
        '30012',
      );
    });

    test('round trips operator detail with nested skill and module data', () {
      final detail = OperatorDetail(
        id: 'char_002_amiya',
        name: 'Amiya',
        codename: 'Amiya',
        rarity: 5,
        profession: 'CASTER',
        branch: 'Core Caster',
        teams: const ['Rhodes Island'],
        nations: const ['Rhodes Island'],
        groups: const ['Rhodes Island'],
        baTags: const ['DPS'],
        thumbnailHue: 210,
        releaseOrder: 12,
        quote: 'Leader',
        tags: const ['Ranged'],
        traits: const [
          OperatorTrait(
            groupKey: 'trait',
            description: 'Deals Arts damage',
            elite: 0,
            level: 1,
            requiredPotentialRank: 0,
            blackboard: [OperatorBlackboardEntry(key: 'atk', value: 1.0)],
          ),
        ],
        talents: const [
          OperatorTalent(
            groupKey: 'talent',
            name: 'Absorption',
            description: 'Restores SP',
            elite: 1,
            level: 1,
            requiredPotentialRank: 0,
            blackboard: [],
          ),
        ],
        potentials: const [
          OperatorPotential(rank: 2, description: 'DP Cost -1'),
        ],
        modules: const [
          OperatorModule(
            uniEquipId: 'uniequip_002',
            uniEquipName: 'Module',
            uniEquipIcon: 'module_icon',
            uniEquipDesc: 'Module desc',
            typeIcon: 'X',
            unlockEvolvePhase: 'PHASE_2',
            charId: 'char_002_amiya',
            unlockLevel: 40,
            missionList: ['mission'],
            unlockFavors: {'favor': 100},
            unlockFavorPercents: {'favor': 50},
            itemCost: {
              '1': [OperatorCost(id: '30012', count: 2, type: 'MATERIAL')],
            },
            isSpecialEquip: false,
            battlePhases: [
              OperatorModuleBattlePhase(
                equipLevel: 1,
                parts: [
                  OperatorModuleBattlePart(
                    target: 'TRAIT',
                    traitCandidates: [
                      OperatorTraitCandidate(
                        description: 'Improved trait',
                        elite: 2,
                        level: 1,
                        requiredPotentialRank: 0,
                        blackboard: [],
                      ),
                    ],
                    talentCandidates: [],
                  ),
                ],
                attributeBlackboard: [
                  OperatorBlackboardEntry(key: 'atk', value: 40),
                ],
              ),
            ],
          ),
        ],
        archetypeDescription: 'Core caster',
        eliteCaps: const [50, 70, 80],
        eliteExpCosts: const [
          [0, 100],
        ],
        eliteUpgradeGoldCosts: const [
          [0, 30],
        ],
        eliteEvolveGoldCosts: const [0, 20000, 120000],
        eliteEvolveCosts: const [
          [OperatorCost(id: '30012', count: 3, type: 'MATERIAL')],
        ],
        allSkillLevelUpCosts: const [
          OperatorUpgradeCostStage(
            level: 2,
            costs: [OperatorCost(id: '30012', count: 1, type: 'MATERIAL')],
          ),
        ],
        stats: const [
          OperatorStatProgression(
            level: 1,
            min: OperatorStatPoint(
              hp: 100,
              attack: 30,
              defense: 20,
              resistance: 10,
              redeployTime: 70,
              dpCost: 18,
              block: 1,
              attackInterval: 1.6,
              hpRecoveryPerSec: 0,
            ),
            max: OperatorStatPoint(
              hp: 800,
              attack: 300,
              defense: 80,
              resistance: 10,
              redeployTime: 70,
              dpCost: 18,
              block: 1,
              attackInterval: 1.6,
              hpRecoveryPerSec: 0,
            ),
            range: OperatorRange(
              id: 'range_1',
              grids: [OperatorRangeGrid(row: 0, col: 1)],
            ),
          ),
        ],
        skills: const [
          OperatorSkill(
            id: 'skchr_amiya_1',
            iconId: 'skill_icon',
            name: 'Tactical Chant',
            recoveryType: 'AUTO',
            activationType: 'MANUAL',
            description: 'ATK up',
            unlockElite: 0,
            unlockLevel: 1,
            upgradeCosts: [
              OperatorUpgradeCostStage(
                level: 2,
                costs: [OperatorCost(id: '30012', count: 1, type: 'MATERIAL')],
              ),
            ],
            levels: [
              OperatorSkillLevel(
                level: 1,
                spCost: 20,
                initialSp: 0,
                duration: 20,
                description: 'ATK +10%',
                blackboard: [
                  OperatorBlackboardEntry(
                    key: 'atk',
                    value: 0.1,
                    valueStr: '10%',
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final decoded = OperatorDetail.fromJson(detail.toJson());

      expect(decoded.id, 'char_002_amiya');
      expect(decoded.releaseOrder, 12);
      expect(
        decoded.skills.single.levels.single.blackboard.single.valueStr,
        '10%',
      );
      expect(
        decoded.modules.single.battlePhases.single.parts.single.traitCandidates
            .single.description,
        'Improved trait',
      );
    });

    test('round trips snapshots, statuses, and sync results', () {
      final snapshot = RegionSnapshot(
        schemaVersionValue: RegionSnapshot.schemaVersion,
        region: RegionCode.kr,
        sourceRevision: 'etag',
        sourceVersion: const DataVersion(versionControl: '68.2.0'),
        fetchedAt: DateTime.utc(2026, 5, 17),
        stageCodeMap: const {'main_01-07': '1-7'},
        terms: const {'atk': 'Attack'},
        items: const [],
        buildingFormulas: const BuildingFormulaBundle(),
        operators: const [],
      );
      final summary = RegionSummarySnapshot(
        schemaVersionValue: RegionSnapshot.schemaVersion,
        region: RegionCode.kr,
        sourceRevision: 'etag',
        sourceVersion: const DataVersion(versionControl: '68.2.0'),
        fetchedAt: DateTime.utc(2026, 5, 17),
        operators: const [
          OperatorSummary(
            id: 'char_002_amiya',
            name: 'Amiya',
            rarity: 5,
            profession: 'CASTER',
            branch: 'Core Caster',
            teams: ['Rhodes Island'],
            nations: ['Rhodes Island'],
            groups: ['Rhodes Island'],
            baTags: ['DPS'],
            thumbnailHue: 210,
            releaseOrder: 7,
          ),
        ],
      );
      const status = RegionSyncStatus(
        region: RegionCode.kr,
        sourceRevision: 'etag',
        sourceVersion: '68.2.0',
        fetchedAt: null,
        operatorCount: 1,
        isReady: true,
      );
      const result = SyncResult(
        region: RegionCode.kr,
        sourceRevision: 'etag',
        sourceVersion: '68.2.0',
        updatedAt: '2026-05-17T00:00:00.000Z',
        operatorCount: 1,
        status: 'success',
      );

      final snapshotJson =
          jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, Object?>;
      final summaryJson =
          jsonDecode(jsonEncode(summary.toJson())) as Map<String, Object?>;

      expect(
        RegionSnapshot.fromJson(snapshotJson).stageCodeMap['main_01-07'],
        '1-7',
      );
      expect(
        RegionSummarySnapshot.fromJson(summaryJson).operators.single.name,
        'Amiya',
      );
      expect(
        RegionSummarySnapshot.fromJson(summaryJson)
            .operators
            .single
            .releaseOrder,
        7,
      );
      expect(RegionSyncStatus.fromJson(status.toJson()).isReady, isTrue);
      expect(SyncResult.fromJson(result.toJson()).status, 'success');
    });

    test('reads a missing release order as 0 (not in the handbook)', () {
      final json = const OperatorSummary(
        id: 'char_002_amiya',
        name: 'Amiya',
        rarity: 5,
        profession: 'CASTER',
        branch: 'Core Caster',
        thumbnailHue: 210,
        releaseOrder: 3,
      ).toJson()
        ..remove('releaseOrder');
      expect(OperatorSummary.fromJson(json).releaseOrder, 0);
    });
  });
}
