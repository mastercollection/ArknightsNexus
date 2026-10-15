class UserData {
  const UserData({
    this.schemaVersion = schemaVersionValue,
    this.favorites = const [],
    this.selectedOperatorIds = const [],
    this.operatorPlans = const [],
    this.itemCounts = const {},
  });

  static const schemaVersionValue = 3;

  final int schemaVersion;
  final List<String> favorites;
  final List<String> selectedOperatorIds;
  final List<UserPlanOperator> operatorPlans;
  final Map<String, int> itemCounts;

  factory UserData.fromJson(Map<String, Object?> json) {
    return UserData(
      schemaVersion: _int(json['schemaVersion'] ?? 0),
      favorites: _strings(json['favorites']),
      selectedOperatorIds: _strings(json['selectedOperatorIds']),
      operatorPlans: _list(
        json['operatorPlans'],
        (value) => UserPlanOperator.fromJson(_map(value)),
      ),
      itemCounts: _intMap(json['itemCounts']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'favorites': favorites,
      'selectedOperatorIds': selectedOperatorIds,
      'operatorPlans': operatorPlans.map((entry) => entry.toJson()).toList(),
      'itemCounts': itemCounts,
    };
  }

  UserData copyWith({
    int? schemaVersion,
    List<String>? favorites,
    List<String>? selectedOperatorIds,
    List<UserPlanOperator>? operatorPlans,
    Map<String, int>? itemCounts,
  }) {
    return UserData(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      favorites: favorites ?? this.favorites,
      selectedOperatorIds: selectedOperatorIds ?? this.selectedOperatorIds,
      operatorPlans: operatorPlans ?? this.operatorPlans,
      itemCounts: itemCounts ?? this.itemCounts,
    );
  }
}

class UserPlan {
  const UserPlan({
    this.selectedOperatorIds = const [],
    this.operators = const [],
  });

  final List<String> selectedOperatorIds;
  final List<UserPlanOperator> operators;
}

class UserPlanOperator {
  const UserPlanOperator({
    required this.operatorId,
    required this.current,
    required this.target,
  });

  final String operatorId;
  final UserPlanOperatorState current;
  final UserPlanOperatorState target;

  factory UserPlanOperator.fromJson(Map<String, Object?> json) {
    return UserPlanOperator(
      operatorId: json['operatorId'] as String? ?? '',
      current: UserPlanOperatorState.fromJson(_map(json['current'])),
      target: UserPlanOperatorState.fromJson(_map(json['target'])),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'operatorId': operatorId,
      'current': current.toJson(),
      'target': target.toJson(),
    };
  }

  UserPlanOperator copyWith({
    UserPlanOperatorState? current,
    UserPlanOperatorState? target,
  }) {
    return UserPlanOperator(
      operatorId: operatorId,
      current: current ?? this.current,
      target: target ?? this.target,
    );
  }
}

class UserPlanOperatorState {
  const UserPlanOperatorState({
    required this.elite,
    required this.level,
    this.skillLevels = const [],
    this.modules = const [],
  });

  final int elite;
  final int level;
  final List<int> skillLevels;
  final List<UserPlanModule> modules;

  factory UserPlanOperatorState.fromJson(Map<String, Object?> json) {
    return UserPlanOperatorState(
      elite: _int(json['elite']),
      level: _int(json['level']),
      skillLevels: _ints(json['skillLevels']),
      modules: _list(
        json['modules'],
        (value) => UserPlanModule.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'elite': elite,
      'level': level,
      'skillLevels': skillLevels,
      'modules': modules.map((entry) => entry.toJson()).toList(),
    };
  }

  UserPlanOperatorState copyWith({
    int? elite,
    int? level,
    List<int>? skillLevels,
    List<UserPlanModule>? modules,
  }) {
    return UserPlanOperatorState(
      elite: elite ?? this.elite,
      level: level ?? this.level,
      skillLevels: skillLevels ?? this.skillLevels,
      modules: modules ?? this.modules,
    );
  }

  /// Skill [index] set to [level]; skills before it that have no level yet
  /// start at 1.
  UserPlanOperatorState withSkillLevel(int index, int level) {
    final next = List<int>.of(skillLevels);
    while (next.length <= index) {
      next.add(1);
    }
    next[index] = level;
    return copyWith(skillLevels: next);
  }

  /// The plan entry of [moduleId], if the state has one.
  UserPlanModule? module(String moduleId) {
    for (final module in modules) {
      if (module.moduleId == moduleId) {
        return module;
      }
    }
    return null;
  }

  /// [moduleId]'s entry with the given stages replaced; other modules (and
  /// a module the state does not list) stay as they are.
  UserPlanOperatorState withModuleStage(
    String moduleId, {
    int? currentStage,
    int? targetStage,
  }) {
    return copyWith(
      modules: [
        for (final module in modules)
          if (module.moduleId == moduleId)
            UserPlanModule(
              moduleId: module.moduleId,
              currentStage: currentStage ?? module.currentStage,
              targetStage: targetStage ?? module.targetStage,
            )
          else
            module,
      ],
    );
  }
}

class UserPlanModule {
  const UserPlanModule({
    required this.moduleId,
    required this.currentStage,
    required this.targetStage,
  });

  final String moduleId;
  final int currentStage;
  final int targetStage;

  factory UserPlanModule.fromJson(Map<String, Object?> json) {
    return UserPlanModule(
      moduleId: json['moduleId'] as String? ?? '',
      currentStage: _int(json['currentStage']),
      targetStage: _int(json['targetStage']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'moduleId': moduleId,
      'currentStage': currentStage,
      'targetStage': targetStage,
    };
  }
}

Map<String, Object?> _map(Object? value) {
  return Map<String, Object?>.from(value as Map? ?? const {});
}

List<T> _list<T>(Object? value, T Function(Object?) convert) {
  return (value as List? ?? const []).map(convert).toList();
}

List<String> _strings(Object? value) {
  return (value as List? ?? const []).map((entry) => entry as String).toList();
}

List<int> _ints(Object? value) {
  return (value as List? ?? const []).map(_int).toList();
}

Map<String, int> _intMap(Object? value) {
  return Map<String, Object?>.from(value as Map? ?? const {}).map(
    (key, entry) => MapEntry(key, _int(entry)),
  );
}

int _int(Object? value) => (value as num? ?? 0).toInt();
