import 'dart:collection';
import 'dart:convert';

import '../core/errors/app_failure.dart';
import '../domain/account_profile.dart';
import '../domain/user_data.dart';
import '../repositories/user_data_repository.dart';

/// Validated access to `user_data.json`.
///
/// Every operation runs through one queue, so the read-modify-write of one
/// save never interleaves with another (two item counts saved at once, or a
/// favorite toggle racing the plan autosave, would otherwise drop one of the
/// updates). Reads queue too, so they observe all earlier saves.
class UserDataService {
  UserDataService(this._repository);

  static const maxUserDataImportBytes = 1024 * 1024;
  static const _maxElite = 2;
  static const _maxSkillLevel = 10;
  static const _maxModuleStage = 3;
  static const _maxPlanLevel = 90;

  final UserDataRepository _repository;

  /// Completes when the last queued operation has finished; null when the
  /// queue is idle.
  Future<void>? _tail;

  /// Runs [operation] after every previously queued one has finished. An
  /// idle queue starts it right away.
  Future<T> _serialized<T>(Future<T> Function() operation) {
    final previous = _tail;
    final result =
        previous == null ? operation() : previous.then((_) => operation());
    final tail = result.then<void>((_) {}, onError: (Object _) {});
    _tail = tail;
    tail.whenComplete(() {
      if (identical(_tail, tail)) {
        _tail = null;
      }
    });
    return result;
  }

  Future<List<String>> getFavorites() => _serialized(_getFavorites);

  Future<List<String>> _getFavorites() async {
    final data = await _repository.read();
    return _sanitizeIds(data.favorites);
  }

  Future<bool> toggleOperatorFavorite(String operatorId) =>
      _serialized(() => _toggleOperatorFavorite(operatorId));

  Future<bool> _toggleOperatorFavorite(String operatorId) async {
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

  Future<UserPlan> getUserPlan() => _serialized(_getUserPlan);

  Future<UserPlan> _getUserPlan() async {
    final data = await _repository.read();
    final normalized = _normalizeUserData(data);
    return UserPlan(
      selectedOperatorIds: normalized.selectedOperatorIds,
      operators: normalized.operatorPlans,
    );
  }

  Future<String> exportUserData() => _serialized(_exportUserData);

  Future<String> _exportUserData() async {
    final data = _normalizeUserData(await _repository.read());
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data.toJson());
  }

  Future<void> importUserData(String content) =>
      _serialized(() => _importUserData(content));

  Future<void> _importUserData(String content) async {
    final trimmed = _validateImportContent(content);
    final parsed = _parseUserData(trimmed);
    final normalized = _normalizeUserData(parsed);
    await _repository.backup();
    await _repository.write(normalized);
  }

  Future<List<String>> saveUserPlanSelection(List<String> operatorIds) =>
      _serialized(() => _saveUserPlanSelection(operatorIds));

  Future<List<String>> _saveUserPlanSelection(List<String> operatorIds) async {
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

  Future<UserPlanOperator> saveUserPlanOperator(UserPlanOperator plan) =>
      _serialized(() => _saveUserPlanOperator(plan));

  Future<UserPlanOperator> _saveUserPlanOperator(UserPlanOperator plan) async {
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

  Future<bool> removeUserPlanOperator(String operatorId) =>
      _serialized(() => _removeUserPlanOperator(operatorId));

  Future<bool> _removeUserPlanOperator(String operatorId) async {
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

  Future<int> saveUserItemCount(String itemId, int count) =>
      _serialized(() => _saveUserItemCount(itemId, count));

  Future<int> _saveUserItemCount(String itemId, int count) async {
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

  Future<int> importUserItemCounts(String content) =>
      _serialized(() => _importUserItemCounts(content));

  Future<int> _importUserItemCounts(String content) async {
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

  Future<AccountProfile?> getAccount() =>
      _serialized(() async => (await _repository.read()).account);

  /// Stores [profile] and copies the account into the user data: the depot
  /// replaces every item count, and planned operators the account owns get
  /// their current training from it (their targets are raised to at least
  /// that). The previous data is backed up first.
  Future<AccountApplyResult> saveAccount(
    AccountProfile profile,
    Map<String, int> itemCounts,
  ) =>
      _serialized(() => _saveAccount(profile, itemCounts));

  Future<AccountApplyResult> _saveAccount(
    AccountProfile profile,
    Map<String, int> itemCounts,
  ) async {
    final data = await _repository.read();
    var updatedPlans = 0;
    final plans = <UserPlanOperator>[];
    for (final plan in data.operatorPlans) {
      final owned = profile.operator(plan.operatorId);
      if (owned == null) {
        plans.add(plan);
        continue;
      }
      plans.add(_validatePlan(applyAccountOperator(plan, owned)));
      updatedPlans++;
    }
    await _repository.backup();
    await _repository.write(
      data.copyWith(
        schemaVersion: UserData.schemaVersionValue,
        itemCounts: _sanitizeItemCounts(itemCounts),
        operatorPlans: plans,
        account: profile,
      ),
    );
    return AccountApplyResult(
      itemKinds: itemCounts.length,
      updatedPlans: updatedPlans,
    );
  }

  /// Forgets the account; item counts and plans stay as they are.
  Future<void> clearAccount() => _serialized(() async {
        final data = await _repository.read();
        await _repository.write(
          data.copyWith(
            schemaVersion: UserData.schemaVersionValue,
            clearAccount: true,
          ),
        );
      });

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
      account: data.account,
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

class AccountApplyResult {
  const AccountApplyResult({
    required this.itemKinds,
    required this.updatedPlans,
  });

  final int itemKinds;
  final int updatedPlans;
}

/// [plan] with the current state taken from [owned]; the target keeps its
/// values where they are above the new current state.
UserPlanOperator applyAccountOperator(
  UserPlanOperator plan,
  AccountOperator owned,
) {
  final skillCount = [
    plan.current.skillLevels.length,
    plan.target.skillLevels.length,
    owned.skillLevels.length,
  ].reduce((a, b) => a > b ? a : b);
  final currentSkills = [
    for (var index = 0; index < skillCount; index++)
      owned.skillLevels.elementAtOrNull(index) ??
          owned.skillLevels.firstOrNull?.clamp(1, 7) ??
          1,
  ];
  final current = UserPlanOperatorState(
    elite: owned.elite,
    level: owned.level,
    skillLevels: currentSkills,
    modules: [
      for (final module in plan.current.modules)
        UserPlanModule(
          moduleId: module.moduleId,
          currentStage: owned.modules[module.moduleId] ?? 0,
          targetStage: module.targetStage,
        ),
    ],
  );

  final target = plan.target;
  final targetAhead = target.elite > current.elite ||
      (target.elite == current.elite && target.level >= current.level);
  final targetModules = {
    for (final module in target.modules) module.moduleId: module,
  };
  return plan.copyWith(
    current: current,
    target: UserPlanOperatorState(
      elite: targetAhead ? target.elite : current.elite,
      level: targetAhead ? target.level : current.level,
      skillLevels: [
        for (var index = 0; index < skillCount; index++)
          _max(
            target.skillLevels.elementAtOrNull(index) ?? 1,
            currentSkills[index],
          ),
      ],
      modules: [
        for (final module in current.modules)
          UserPlanModule(
            moduleId: module.moduleId,
            currentStage: module.currentStage,
            targetStage: _max(
              targetModules[module.moduleId]?.targetStage ?? 0,
              module.currentStage,
            ),
          ),
      ],
    ),
  );
}

int _max(int a, int b) => a > b ? a : b;
