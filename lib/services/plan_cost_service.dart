import '../domain/building_formula.dart';
import '../domain/item.dart';
import '../domain/operator.dart';
import '../domain/user_data.dart';

const _ls6ExpPerRun = 10000;
const _ce6LmdPerRun = 10000;
const _supplyStageSanity = 36;
const _maxElite = 2;
const _maxModuleStage = 3;
const _maxSkillLevel = 10;

abstract interface class PlanCostService {
  int getEliteLevelCap(OperatorDetail detail, int elite);

  UserPlanOperator createDefaultPlanOperator(OperatorDetail detail);

  UserPlanOperator resolvePlanOperator(
    OperatorDetail detail,
    UserPlanOperator? plan,
  );

  UserPlanOperator? getPlanByOperatorId(UserPlan plan, String operatorId);

  PlanCostBreakdown calculatePlanCostsWithItems(
    OperatorDetail detail,
    UserPlanOperator plan,
    Map<String, ItemEntry> itemsById,
  );

  PlanAggregateBreakdown aggregatePlanCostsWithItems(
    List<PlanCostEntry> entries,
    Map<String, ItemEntry> itemsById,
  );

  PlanFarmingEstimate estimatePlanFarming(PlanCostBreakdown breakdown);

  List<PlanMaterialTotal> expandPlanMaterials(
    List<PlanMaterialTotal> materials,
    BuildingFormulaBundle formulas,
    Map<String, ItemEntry> itemsById,
  );
}

class DartPlanCostService implements PlanCostService {
  const DartPlanCostService();

  @override
  int getEliteLevelCap(OperatorDetail detail, int elite) {
    final safeElite = _clamp(elite, 0, detail.eliteCaps.length - 1);
    return detail.eliteCaps.elementAtOrNull(safeElite) ?? 1;
  }

  @override
  UserPlanOperator createDefaultPlanOperator(OperatorDetail detail) {
    final targetElite = detail.eliteCaps.length > 2
        ? 2
        : (detail.eliteCaps.length - 1).clamp(0, _maxElite);
    return UserPlanOperator(
      operatorId: detail.id,
      current: UserPlanOperatorState(
        elite: 0,
        level: 1,
        skillLevels: _buildDefaultSkillLevels(detail.skills.length),
        modules: [
          for (final module in detail.modules)
            UserPlanModule(
              moduleId: module.uniEquipId,
              currentStage: 0,
              targetStage: 0,
            ),
        ],
      ),
      target: UserPlanOperatorState(
        elite: targetElite,
        level: getEliteLevelCap(detail, targetElite),
        skillLevels: _buildDefaultSkillLevels(detail.skills.length),
        modules: [
          for (final module in detail.modules)
            UserPlanModule(
              moduleId: module.uniEquipId,
              currentStage: 0,
              targetStage: _getMaxModuleStage(module),
            ),
        ],
      ),
    );
  }

  @override
  UserPlanOperator resolvePlanOperator(
    OperatorDetail detail,
    UserPlanOperator? plan,
  ) {
    final fallback = createDefaultPlanOperator(detail);
    if (plan == null) {
      return fallback;
    }
    return UserPlanOperator(
      operatorId: detail.id,
      current: _normalizePlanState(detail, plan.current, fallback.current),
      target: _normalizePlanState(detail, plan.target, fallback.target),
    );
  }

  @override
  UserPlanOperator? getPlanByOperatorId(UserPlan plan, String operatorId) {
    final normalized = operatorId.trim();
    for (final entry in plan.operators) {
      if (entry.operatorId == normalized) {
        return entry;
      }
    }
    return null;
  }

  @override
  PlanCostBreakdown calculatePlanCostsWithItems(
    OperatorDetail detail,
    UserPlanOperator plan,
    Map<String, ItemEntry> itemsById,
  ) {
    final resolved = resolvePlanOperator(detail, plan);
    final errors = _validatePlanRange(detail, resolved);
    final materialMap = <String, PlanMaterialTotal>{};
    var exp = 0.0;

    if (errors.isNotEmpty) {
      return PlanCostBreakdown(
        valid: false,
        exp: exp,
        materials: const [],
        errors: errors,
      );
    }

    for (final segment in _collectLevelSegments(
      detail,
      resolved.current,
      resolved.target,
    )) {
      final expTable =
          detail.eliteExpCosts.elementAtOrNull(segment.elite) ?? const [];
      final goldTable =
          detail.eliteUpgradeGoldCosts.elementAtOrNull(segment.elite) ??
              const [];
      for (var level = segment.fromLevel; level < segment.toLevel; level++) {
        exp += expTable.elementAtOrNull(level - 1) ?? 0;
        _appendVirtualItemMaterial(
          materialMap,
          itemsById,
          lmdItemId,
          (goldTable.elementAtOrNull(level - 1) ?? 0).toDouble(),
        );
      }
    }

    for (var elite = resolved.current.elite;
        elite < resolved.target.elite;
        elite++) {
      _appendVirtualItemMaterial(
        materialMap,
        itemsById,
        lmdItemId,
        (detail.eliteEvolveGoldCosts.elementAtOrNull(elite) ?? 0).toDouble(),
      );
      for (final cost in detail.eliteEvolveCosts.elementAtOrNull(elite) ??
          const <OperatorCost>[]) {
        _appendCost(materialMap, cost);
      }
    }

    for (var skillIndex = 0; skillIndex < detail.skills.length; skillIndex++) {
      final currentLevel =
          resolved.current.skillLevels.elementAtOrNull(skillIndex) ?? 1;
      final targetLevel =
          resolved.target.skillLevels.elementAtOrNull(skillIndex) ??
              currentLevel;

      for (var nextLevel = currentLevel + 1;
          nextLevel <= targetLevel;
          nextLevel++) {
        final stage = nextLevel <= 7
            ? _findCostStage(detail.allSkillLevelUpCosts, nextLevel)
            : _findCostStage(
                detail.skills[skillIndex].upgradeCosts,
                nextLevel,
              );
        for (final cost in stage?.costs ?? const <OperatorCost>[]) {
          _appendCost(materialMap, cost);
        }
      }
    }

    for (final module in _mergeModuleRanges(
      detail,
      resolved.current.modules,
      resolved.target.modules,
    )) {
      if (module.currentStage > module.targetStage) {
        continue;
      }
      final detailModule = detail.modules
          .where((entry) => entry.uniEquipId == module.moduleId)
          .firstOrNull;
      if (detailModule == null) {
        continue;
      }

      for (var stage = module.currentStage + 1;
          stage <= module.targetStage;
          stage++) {
        for (final cost in detailModule.itemCost?[stage.toString()] ??
            const <OperatorCost>[]) {
          _appendCost(materialMap, cost);
        }
      }
    }

    return PlanCostBreakdown(
      valid: true,
      exp: exp,
      materials: _sortedMaterials(materialMap),
      errors: errors,
    );
  }

  @override
  PlanAggregateBreakdown aggregatePlanCostsWithItems(
    List<PlanCostEntry> entries,
    Map<String, ItemEntry> itemsById,
  ) {
    final aggregateMap = <String, PlanMaterialTotal>{};
    final errors = <String>{};
    var exp = 0.0;
    var operatorCount = 0;

    for (final entry in entries) {
      final result = calculatePlanCostsWithItems(
        entry.detail,
        entry.plan,
        itemsById,
      );
      errors.addAll(result.errors);
      if (!result.valid) {
        continue;
      }

      operatorCount += 1;
      exp += result.exp;

      for (final material in result.materials) {
        _appendMaterial(aggregateMap, material);
      }
    }

    return PlanAggregateBreakdown(
      valid: errors.isEmpty,
      exp: exp,
      materials: _sortedMaterials(aggregateMap),
      errors: errors.toList(),
      operatorCount: operatorCount,
    );
  }

  @override
  PlanFarmingEstimate estimatePlanFarming(PlanCostBreakdown breakdown) {
    final lmdItem = breakdown.materials
        .where((material) => material.id == lmdItemId)
        .firstOrNull;
    final lmd = lmdItem?.count ?? 0;
    final expRuns = (breakdown.exp / _ls6ExpPerRun).ceil();
    final lmdRuns = (lmd / _ce6LmdPerRun).ceil();

    return PlanFarmingEstimate(
      exp: breakdown.exp,
      lmd: lmd,
      lmdItem: lmdItem,
      expStage: PlanStageEstimate(
        code: 'LS-6',
        runs: expRuns,
        sanity: expRuns * _supplyStageSanity,
      ),
      lmdStage: PlanStageEstimate(
        code: 'CE-6',
        runs: lmdRuns,
        sanity: lmdRuns * _supplyStageSanity,
      ),
      totalSanity: (expRuns + lmdRuns) * _supplyStageSanity,
    );
  }

  @override
  List<PlanMaterialTotal> expandPlanMaterials(
    List<PlanMaterialTotal> materials,
    BuildingFormulaBundle formulas,
    Map<String, ItemEntry> itemsById,
  ) {
    final workshopFormulaByItemId = {
      for (final formula in formulas.workshopFormulas)
        if (formula.formulaType != 'F_ASC') formula.itemId: formula,
    };
    final manufactFormulaByItemId = {
      for (final formula in formulas.manufactFormulas)
        if (formula.formulaType == 'F_ASC') formula.itemId: formula,
    };
    final expanded = <String, PlanMaterialTotal>{};

    for (final material in materials) {
      _appendExpandedMaterial(
        expanded,
        material,
        workshopFormulaByItemId,
        manufactFormulaByItemId,
        itemsById,
        <String>{},
      );
    }

    return expanded.values.toList();
  }

  UserPlanOperatorState _normalizePlanState(
    OperatorDetail detail,
    UserPlanOperatorState state,
    UserPlanOperatorState fallback,
  ) {
    final maxElite = detail.eliteCaps.isEmpty
        ? 0
        : (_maxElite).clamp(0, detail.eliteCaps.length - 1);
    final elite = _clamp(state.elite, 0, maxElite);
    final level = _clamp(state.level, 1, getEliteLevelCap(detail, elite));
    final skillCount = detail.skills.length > 3 ? detail.skills.length : 3;
    final skillLevels = [
      for (var index = 0; index < skillCount; index++)
        _clamp(
          state.skillLevels.elementAtOrNull(index) ??
              fallback.skillLevels.elementAtOrNull(index) ??
              1,
          1,
          _maxSkillLevel,
        ),
    ];
    final modules = [
      for (final module in _mergeModuleFallbacks(
        detail,
        state.modules,
        fallback.modules,
      ))
        UserPlanModule(
          moduleId: module.moduleId,
          currentStage: _clamp(module.currentStage, 0, _maxModuleStage),
          targetStage: _clamp(module.targetStage, 0, _maxModuleStage),
        ),
    ];

    return UserPlanOperatorState(
      elite: elite,
      level: level,
      skillLevels: skillLevels,
      modules: modules,
    );
  }

  List<String> _validatePlanRange(
    OperatorDetail detail,
    UserPlanOperator plan,
  ) {
    final errors = <String>[];

    if (_compareState(plan.current, plan.target) > 0) {
      errors.add('${detail.name}: 초기 육성 단계가 목표보다 높습니다.');
    }

    for (var index = 0; index < plan.current.skillLevels.length; index++) {
      final level = plan.current.skillLevels[index];
      final target = plan.target.skillLevels.elementAtOrNull(index) ?? level;
      if (level > target) {
        errors.add('${detail.name}: 스킬 ${index + 1}의 초기 레벨이 목표보다 높습니다.');
      }
    }

    for (final module in _mergeModuleRanges(
      detail,
      plan.current.modules,
      plan.target.modules,
    )) {
      if (module.currentStage > module.targetStage) {
        errors.add('${detail.name}: 모듈 단계 설정이 올바르지 않습니다.');
      }
    }

    return errors;
  }

  List<_LevelSegment> _collectLevelSegments(
    OperatorDetail detail,
    UserPlanOperatorState current,
    UserPlanOperatorState target,
  ) {
    final segments = <_LevelSegment>[];

    if (current.elite == target.elite) {
      segments.add(
        _LevelSegment(
          elite: current.elite,
          fromLevel: current.level,
          toLevel: target.level,
        ),
      );
      return segments;
    }

    segments.add(
      _LevelSegment(
        elite: current.elite,
        fromLevel: current.level,
        toLevel: getEliteLevelCap(detail, current.elite),
      ),
    );
    for (var elite = current.elite + 1; elite < target.elite; elite++) {
      segments.add(
        _LevelSegment(
          elite: elite,
          fromLevel: 1,
          toLevel: getEliteLevelCap(detail, elite),
        ),
      );
    }
    segments.add(
      _LevelSegment(
        elite: target.elite,
        fromLevel: 1,
        toLevel: target.level,
      ),
    );

    return segments;
  }

  List<UserPlanModule> _mergeModuleFallbacks(
    OperatorDetail detail,
    List<UserPlanModule> primary,
    List<UserPlanModule> fallback,
  ) {
    return [
      for (final module in detail.modules)
        UserPlanModule(
          moduleId: module.uniEquipId,
          currentStage: primary
                  .where((entry) => entry.moduleId == module.uniEquipId)
                  .firstOrNull
                  ?.currentStage ??
              fallback
                  .where((entry) => entry.moduleId == module.uniEquipId)
                  .firstOrNull
                  ?.currentStage ??
              0,
          targetStage: primary
                  .where((entry) => entry.moduleId == module.uniEquipId)
                  .firstOrNull
                  ?.targetStage ??
              fallback
                  .where((entry) => entry.moduleId == module.uniEquipId)
                  .firstOrNull
                  ?.targetStage ??
              _getMaxModuleStage(module),
        ),
    ];
  }

  /// Deliberate fix over `usePlanCosts.ts`: the Vue `mergeModules` reads
  /// module target stages from the *current* state (always 0), so the Tauri
  /// app never counts module costs. Here current stages come from current and
  /// target stages from target, so module targets affect the totals.
  List<UserPlanModule> _mergeModuleRanges(
    OperatorDetail detail,
    List<UserPlanModule> current,
    List<UserPlanModule> target,
  ) {
    return [
      for (final module in detail.modules)
        UserPlanModule(
          moduleId: module.uniEquipId,
          currentStage: current
                  .where((entry) => entry.moduleId == module.uniEquipId)
                  .firstOrNull
                  ?.currentStage ??
              0,
          targetStage: target
                  .where((entry) => entry.moduleId == module.uniEquipId)
                  .firstOrNull
                  ?.targetStage ??
              _getMaxModuleStage(module),
        ),
    ];
  }

  void _appendExpandedMaterial(
    Map<String, PlanMaterialTotal> expanded,
    PlanMaterialTotal material,
    Map<String, WorkshopFormula> workshopFormulaByItemId,
    Map<String, ManufacturingFormula> manufactFormulaByItemId,
    Map<String, ItemEntry> itemsById,
    Set<String> visiting,
  ) {
    if (visiting.contains(material.id)) {
      _appendMaterial(expanded, material);
      return;
    }

    final workshopFormula = workshopFormulaByItemId[material.id];
    final manufactFormula = manufactFormulaByItemId[material.id];

    if (workshopFormula != null) {
      _appendExpandedByFormula(
        expanded,
        material,
        workshopFormula.costs,
        workshopFormula.count,
        workshopFormula.goldCost,
        workshopFormulaByItemId,
        manufactFormulaByItemId,
        itemsById,
        visiting,
      );
      return;
    }

    if (manufactFormula != null) {
      _appendExpandedByFormula(
        expanded,
        material,
        manufactFormula.costs,
        manufactFormula.count,
        0,
        workshopFormulaByItemId,
        manufactFormulaByItemId,
        itemsById,
        visiting,
      );
      return;
    }

    _appendMaterial(expanded, material);
  }

  void _appendExpandedByFormula(
    Map<String, PlanMaterialTotal> expanded,
    PlanMaterialTotal material,
    List<FormulaCost> costs,
    int outputCount,
    int goldCost,
    Map<String, WorkshopFormula> workshopFormulaByItemId,
    Map<String, ManufacturingFormula> manufactFormulaByItemId,
    Map<String, ItemEntry> itemsById,
    Set<String> visiting,
  ) {
    if (costs.isEmpty && goldCost <= 0) {
      _appendMaterial(expanded, material);
      return;
    }

    final requiredCrafts =
        (material.count / (outputCount < 1 ? 1 : outputCount)).ceil();
    final nextVisiting = {...visiting, material.id};
    for (final cost in costs) {
      _appendExpandedCost(
        expanded,
        cost,
        requiredCrafts,
        workshopFormulaByItemId,
        manufactFormulaByItemId,
        itemsById,
        nextVisiting,
      );
    }
    if (goldCost > 0) {
      _appendExpandedCost(
        expanded,
        const FormulaCost(id: lmdItemId, count: 0, type: 'MATERIAL'),
        requiredCrafts,
        workshopFormulaByItemId,
        manufactFormulaByItemId,
        itemsById,
        nextVisiting,
        countOverride: goldCost.toDouble(),
      );
    }
  }

  void _appendExpandedCost(
    Map<String, PlanMaterialTotal> expanded,
    FormulaCost cost,
    int multiplier,
    Map<String, WorkshopFormula> workshopFormulaByItemId,
    Map<String, ManufacturingFormula> manufactFormulaByItemId,
    Map<String, ItemEntry> itemsById,
    Set<String> visiting, {
    double? countOverride,
  }) {
    final item = itemsById[cost.id];
    final nextMaterial = PlanMaterialTotal(
      id: cost.id,
      name: item?.name.trim().isNotEmpty == true ? item!.name : cost.id,
      iconId: item?.iconId,
      rarity: item?.rarity,
      type: item?.itemType,
      count: (countOverride ?? cost.count) * multiplier,
    );
    _appendExpandedMaterial(
      expanded,
      nextMaterial,
      workshopFormulaByItemId,
      manufactFormulaByItemId,
      itemsById,
      visiting,
    );
  }
}

class PlanMaterialTotal {
  const PlanMaterialTotal({
    required this.id,
    required this.name,
    this.iconId,
    this.rarity,
    this.type,
    required this.count,
  });

  final String id;
  final String name;
  final String? iconId;
  final String? rarity;
  final String? type;
  final double count;

  PlanMaterialTotal copyWithCount(double count) {
    return PlanMaterialTotal(
      id: id,
      name: name,
      iconId: iconId,
      rarity: rarity,
      type: type,
      count: count,
    );
  }
}

class PlanCostBreakdown {
  const PlanCostBreakdown({
    required this.valid,
    required this.exp,
    required this.materials,
    required this.errors,
  });

  final bool valid;
  final double exp;
  final List<PlanMaterialTotal> materials;
  final List<String> errors;
}

class PlanAggregateBreakdown extends PlanCostBreakdown {
  const PlanAggregateBreakdown({
    required super.valid,
    required super.exp,
    required super.materials,
    required super.errors,
    required this.operatorCount,
  });

  final int operatorCount;
}

class PlanFarmingEstimate {
  const PlanFarmingEstimate({
    required this.exp,
    required this.lmd,
    required this.lmdItem,
    required this.expStage,
    required this.lmdStage,
    required this.totalSanity,
  });

  final double exp;
  final double lmd;
  final PlanMaterialTotal? lmdItem;
  final PlanStageEstimate expStage;
  final PlanStageEstimate lmdStage;
  final int totalSanity;
}

class PlanStageEstimate {
  const PlanStageEstimate({
    required this.code,
    required this.runs,
    required this.sanity,
  });

  final String code;
  final int runs;
  final int sanity;
}

class PlanCostEntry {
  const PlanCostEntry({
    required this.detail,
    required this.plan,
  });

  final OperatorDetail detail;
  final UserPlanOperator plan;
}

class _LevelSegment {
  const _LevelSegment({
    required this.elite,
    required this.fromLevel,
    required this.toLevel,
  });

  final int elite;
  final int fromLevel;
  final int toLevel;
}

OperatorUpgradeCostStage? _findCostStage(
  List<OperatorUpgradeCostStage> stages,
  int level,
) {
  for (final stage in stages) {
    if (stage.level == level) {
      return stage;
    }
  }
  return null;
}

void _appendCost(
  Map<String, PlanMaterialTotal> materialMap,
  OperatorCost cost,
) {
  _appendNamedMaterial(
    materialMap,
    cost.id,
    cost.itemName?.trim().isNotEmpty == true ? cost.itemName! : cost.id,
    cost.count,
    cost.itemIconId,
    cost.itemRarity,
    cost.itemType,
  );
}

void _appendNamedMaterial(
  Map<String, PlanMaterialTotal> materialMap,
  String id,
  String name,
  double count, [
  String? iconId,
  String? rarity,
  String? type,
]) {
  if (count <= 0) {
    return;
  }
  final existing = materialMap[id];
  if (existing != null) {
    materialMap[id] = existing.copyWithCount(existing.count + count);
    return;
  }
  materialMap[id] = PlanMaterialTotal(
    id: id,
    name: name,
    iconId: iconId,
    rarity: rarity,
    type: type,
    count: count,
  );
}

void _appendVirtualItemMaterial(
  Map<String, PlanMaterialTotal> materialMap,
  Map<String, ItemEntry> itemsById,
  String itemId,
  double count,
) {
  final item = itemsById[itemId];
  _appendNamedMaterial(
    materialMap,
    itemId,
    item?.name.trim().isNotEmpty == true ? item!.name : itemId,
    count,
    item?.iconId,
    item?.rarity,
    item?.itemType,
  );
}

void _appendMaterial(
  Map<String, PlanMaterialTotal> materialMap,
  PlanMaterialTotal material,
) {
  final existing = materialMap[material.id];
  if (existing != null) {
    materialMap[material.id] = existing.copyWithCount(
      existing.count + material.count,
    );
    return;
  }
  materialMap[material.id] = material;
}

List<PlanMaterialTotal> _sortedMaterials(
  Map<String, PlanMaterialTotal> materialMap,
) {
  return materialMap.values.toList()..sort(_comparePlanMaterials);
}

int _comparePlanMaterials(PlanMaterialTotal left, PlanMaterialTotal right) {
  final tierCompare = _getMaterialTier(right) - _getMaterialTier(left);
  if (tierCompare != 0) {
    return tierCompare;
  }
  final countCompare = right.count.compareTo(left.count);
  if (countCompare != 0) {
    return countCompare;
  }
  return left.name.compareTo(right.name);
}

int _getMaterialTier(PlanMaterialTotal material) {
  final matched = RegExp(r'\d+').firstMatch(material.rarity ?? '');
  return matched == null ? 0 : int.parse(matched.group(0)!);
}

int _compareState(UserPlanOperatorState left, UserPlanOperatorState right) {
  if (left.elite != right.elite) {
    return left.elite - right.elite;
  }
  return left.level - right.level;
}

int _getMaxModuleStage(OperatorModule module) =>
    _clamp(module.maxStage, 0, _maxModuleStage);

List<int> _buildDefaultSkillLevels(int skillCount) {
  return List.filled(skillCount > 3 ? skillCount : 3, 1);
}

int _clamp(int value, int min, int max) {
  if (max < min) {
    return min;
  }
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
