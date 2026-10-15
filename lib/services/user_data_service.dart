import 'dart:collection';
import 'dart:convert';

import '../core/errors/app_failure.dart';
import '../domain/user_data.dart';
import '../repositories/user_data_repository.dart';

class UserDataService {
  const UserDataService(this._repository);

  static const maxUserDataImportBytes = 1024 * 1024;
  static const _maxElite = 2;
  static const _maxSkillLevel = 10;
  static const _maxModuleStage = 3;
  static const _maxPlanLevel = 90;

  final UserDataRepository _repository;

  Future<List<String>> getFavorites() async {
    final data = await _repository.read();
    return _sanitizeIds(data.favorites);
  }

  Future<bool> toggleOperatorFavorite(String operatorId) async {
    final normalizedId = _sanitizeId(operatorId);
    if (normalizedId.isEmpty) {
      return false;
    }

    final data = await _repository.read();
    final favorites = _sanitizeIds(data.favorites);
    final removed = favorites.remove(normalizedId);
    if (!removed) {
      favorites.add(normalizedId);
      favorites.sort();
    }

    await _repository.write(
      data.copyWith(
        schemaVersion: UserData.schemaVersionValue,
        favorites: favorites,
      ),
    );
    return !removed;
  }

  Future<UserPlan> getUserPlan() async {
    final data = await _repository.read();
    final normalized = _normalizeUserData(data);
    return UserPlan(
      selectedOperatorIds: normalized.selectedOperatorIds,
      operators: normalized.operatorPlans,
    );
  }

  Future<String> exportUserData() async {
    final data = _normalizeUserData(await _repository.read());
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data.toJson());
  }

  Future<void> importUserData(String content) async {
    final trimmed = _validateImportContent(content);
    final parsed = _parseUserData(trimmed);
    final normalized = _normalizeUserData(parsed);
    await _repository.backup();
    await _repository.write(normalized);
  }

  Future<List<String>> saveUserPlanSelection(List<String> operatorIds) async {
    final data = await _repository.read();
    final selectedOperatorIds = _sanitizeIds(operatorIds);
    final operatorPlans = data.operatorPlans
        .where((plan) => selectedOperatorIds.contains(plan.operatorId))
        .toList();
    await _repository.write(
      data.copyWith(
        schemaVersion: UserData.schemaVersionValue,
        selectedOperatorIds: selectedOperatorIds,
        operatorPlans: operatorPlans,
      ),
    );
    return selectedOperatorIds;
  }

  Future<UserPlanOperator> saveUserPlanOperator(UserPlanOperator plan) async {
    final data = await _repository.read();
    final validated = _validatePlan(plan);
    final plans = <UserPlanOperator>[
      for (final entry in data.operatorPlans)
        if (entry.operatorId != validated.operatorId) entry,
      validated,
    ]..sort((left, right) => left.operatorId.compareTo(right.operatorId));

    final selected = _sanitizeIds([
      ...data.selectedOperatorIds,
      validated.operatorId,
    ]);

    await _repository.write(
      data.copyWith(
        schemaVersion: UserData.schemaVersionValue,
        selectedOperatorIds: selected,
        operatorPlans: plans,
      ),
    );
    return validated;
  }

  Future<bool> removeUserPlanOperator(String operatorId) async {
    final normalizedId = _sanitizeId(operatorId);
    if (normalizedId.isEmpty) {
      return false;
    }

    final data = await _repository.read();
    final selected = List<String>.of(data.selectedOperatorIds)
      ..removeWhere((value) => value == normalizedId);
    final plans = List<UserPlanOperator>.of(data.operatorPlans)
      ..removeWhere((value) => value.operatorId == normalizedId);
    final changed = selected.length != data.selectedOperatorIds.length ||
        plans.length != data.operatorPlans.length;

    if (changed) {
      await _repository.write(
        data.copyWith(
          schemaVersion: UserData.schemaVersionValue,
          selectedOperatorIds: selected,
          operatorPlans: plans,
        ),
      );
    }
    return changed;
  }

  Future<int> saveUserItemCount(String itemId, int count) async {
    final normalizedId = _sanitizeId(itemId);
    if (normalizedId.isEmpty) {
      throw const InvalidInputFailure('itemId');
    }

    final data = await _repository.read();
    final itemCounts = _sanitizeItemCounts(data.itemCounts);
    if (count == 0) {
      itemCounts.remove(normalizedId);
    } else {
      itemCounts[normalizedId] = count;
    }

    await _repository.write(
      data.copyWith(
        schemaVersion: UserData.schemaVersionValue,
        itemCounts: itemCounts,
      ),
    );
    return count;
  }

  Future<int> importUserItemCounts(String content) async {
    final trimmed = _validateImportContent(content);
    final parsed = jsonDecode(trimmed);
    if (parsed is! Map) {
      throw const InvalidInputFailure('content');
    }
    final imported = _sanitizeItemCounts(
      Map<String, Object?>.from(parsed).map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
    );
    if (imported.isEmpty) {
      throw const InvalidInputFailure('content');
    }

    final data = await _repository.read();
    final itemCounts = _sanitizeItemCounts(data.itemCounts);
    itemCounts.addAll(imported);
    await _repository.write(
      data.copyWith(
        schemaVersion: UserData.schemaVersionValue,
        itemCounts: itemCounts,
      ),
    );
    return imported.length;
  }

  String _validateImportContent(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty ||
        utf8.encode(trimmed).length > maxUserDataImportBytes) {
      throw const InvalidInputFailure('content');
    }
    return trimmed;
  }

  UserData _parseUserData(String content) {
    final parsed = jsonDecode(content);
    if (parsed is! Map) {
      throw const InvalidInputFailure('content');
    }
    return UserData.fromJson(Map<String, Object?>.from(parsed));
  }

  UserData _normalizeUserData(UserData data) {
    final plansByOperatorId = SplayTreeMap<String, UserPlanOperator>();
    for (final plan in data.operatorPlans) {
      final validated = _validatePlan(plan);
      plansByOperatorId[validated.operatorId] = validated;
    }

    return UserData(
      schemaVersion: UserData.schemaVersionValue,
      favorites: _sanitizeIds(data.favorites),
      selectedOperatorIds: _sanitizeIds(data.selectedOperatorIds),
      operatorPlans: plansByOperatorId.values.toList(),
      itemCounts: _sanitizeItemCounts(data.itemCounts),
    );
  }

  UserPlanOperator _validatePlan(UserPlanOperator plan) {
    final operatorId = _sanitizeId(plan.operatorId);
    if (operatorId.isEmpty) {
      throw const InvalidInputFailure('operatorId');
    }
    return UserPlanOperator(
      operatorId: operatorId,
      current: _validateState(plan.current),
      target: _validateState(plan.target),
    );
  }

  UserPlanOperatorState _validateState(UserPlanOperatorState state) {
    if (state.elite < 0 || state.elite > _maxElite) {
      throw const InvalidInputFailure('elite');
    }
    if (state.level <= 0 || state.level > _maxPlanLevel) {
      throw const InvalidInputFailure('level');
    }

    final skillLevels = state.skillLevels.isEmpty
        ? const [1, 1, 1]
        : state.skillLevels.map((level) {
            if (level < 1 || level > _maxSkillLevel) {
              throw const InvalidInputFailure('skillLevels');
            }
            return level;
          }).toList();

    return UserPlanOperatorState(
      elite: state.elite,
      level: state.level,
      skillLevels: skillLevels,
      modules: state.modules.map(_validateModule).toList(),
    );
  }

  UserPlanModule _validateModule(UserPlanModule module) {
    final moduleId = _sanitizeId(module.moduleId);
    if (moduleId.isEmpty) {
      throw const InvalidInputFailure('moduleId');
    }
    if (module.currentStage < 0 ||
        module.currentStage > _maxModuleStage ||
        module.targetStage < 0 ||
        module.targetStage > _maxModuleStage) {
      throw const InvalidInputFailure('moduleStage');
    }
    return UserPlanModule(
      moduleId: moduleId,
      currentStage: module.currentStage,
      targetStage: module.targetStage,
    );
  }

  List<String> _sanitizeIds(List<String> values) {
    final normalized = values
        .map(_sanitizeId)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return normalized;
  }

  String _sanitizeId(String value) => value.trim();

  Map<String, int> _sanitizeItemCounts(Map<String, int> values) {
    final normalized = SplayTreeMap<String, int>();
    for (final entry in values.entries) {
      final itemId = _sanitizeId(entry.key);
      if (itemId.isNotEmpty && entry.value > 0) {
        normalized[itemId] = entry.value;
      }
    }
    return normalized;
  }
}
