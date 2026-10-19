/// What the app keeps of a game account read with `account/syncData`: the
/// profile, a few counters for the My Account page and every owned
/// operator's training. The full response (several MB) is not stored.
class AccountProfile {
  AccountProfile({
    required this.region,
    required this.uid,
    required this.nickName,
    required this.nickNumber,
    required this.level,
    required this.syncedAt,
    this.registeredAt,
    this.ap = 0,
    this.maxAp = 0,
    this.lastApAddTime,
    this.gold = 0,
    this.orundum = 0,
    this.originium = 0,
    this.inventoryKinds = 0,
    this.operators = const [],
  });

  /// One AP recovers every 6 minutes.
  static const apRecoverySeconds = 360;

  /// `RegionCode.value` of the server the account is on.
  final String region;
  final String uid;
  final String nickName;
  final String nickNumber;
  final int level;
  final DateTime syncedAt;
  final DateTime? registeredAt;

  /// AP when [lastApAddTime] was recorded; see [currentAp].
  final int ap;
  final int maxAp;
  final DateTime? lastApAddTime;
  final int gold;
  final int orundum;
  final int originium;

  /// Item kinds with a positive count in the depot.
  final int inventoryKinds;
  final List<AccountOperator> operators;

  /// AP now, counting recovery since the sync (never above [maxAp], but an
  /// account already above it keeps its surplus).
  int currentAp(DateTime now) {
    final since = lastApAddTime;
    if (since == null || ap >= maxAp) {
      return ap;
    }
    final recovered = now.difference(since).inSeconds ~/ apRecoverySeconds;
    final value = ap + (recovered < 0 ? 0 : recovered);
    return value > maxAp ? maxAp : value;
  }

  /// The training of [operatorId], or null when it is not owned.
  AccountOperator? operator(String operatorId) => _byId[operatorId];

  late final Map<String, AccountOperator> _byId = {
    for (final entry in operators) entry.operatorId: entry,
  };

  factory AccountProfile.fromJson(Map<String, Object?> json) {
    return AccountProfile(
      region: json['region'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      nickName: json['nickName'] as String? ?? '',
      nickNumber: json['nickNumber'] as String? ?? '',
      level: _int(json['level']),
      syncedAt:
          _time(json['syncedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      registeredAt: _time(json['registeredAt']),
      ap: _int(json['ap']),
      maxAp: _int(json['maxAp']),
      lastApAddTime: _time(json['lastApAddTime']),
      gold: _int(json['gold']),
      orundum: _int(json['orundum']),
      originium: _int(json['originium']),
      inventoryKinds: _int(json['inventoryKinds']),
      operators: [
        for (final entry in json['operators'] as List? ?? const [])
          AccountOperator.fromJson(Map<String, Object?>.from(entry as Map)),
      ],
    );
  }

  Map<String, Object?> toJson() {
    return {
      'region': region,
      'uid': uid,
      'nickName': nickName,
      'nickNumber': nickNumber,
      'level': level,
      'syncedAt': syncedAt.millisecondsSinceEpoch,
      if (registeredAt != null)
        'registeredAt': registeredAt!.millisecondsSinceEpoch,
      'ap': ap,
      'maxAp': maxAp,
      if (lastApAddTime != null)
        'lastApAddTime': lastApAddTime!.millisecondsSinceEpoch,
      'gold': gold,
      'orundum': orundum,
      'originium': originium,
      'inventoryKinds': inventoryKinds,
      'operators': operators.map((entry) => entry.toJson()).toList(),
    };
  }
}

/// An owned operator's training, in the plan's terms: [skillLevels] are 1-7
/// then 8-10 for masteries 1-3, [modules] map a module id to its stage
/// (only unlocked modules are listed).
class AccountOperator {
  const AccountOperator({
    required this.operatorId,
    required this.elite,
    required this.level,
    this.potential = 0,
    this.skillLevels = const [],
    this.modules = const {},
  });

  final String operatorId;
  final int elite;
  final int level;

  /// 0 for no extra potential, 5 for full potential.
  final int potential;
  final List<int> skillLevels;
  final Map<String, int> modules;

  /// The highest mastery of any skill (0-3).
  int get maxMastery {
    var best = 0;
    for (final level in skillLevels) {
      final mastery = level - 7;
      if (mastery > best) {
        best = mastery;
      }
    }
    return best;
  }

  factory AccountOperator.fromJson(Map<String, Object?> json) {
    return AccountOperator(
      operatorId: json['operatorId'] as String? ?? '',
      elite: _int(json['elite']),
      level: _int(json['level']),
      potential: _int(json['potential']),
      skillLevels: [
        for (final level in json['skillLevels'] as List? ?? const [])
          _int(level),
      ],
      modules: {
        for (final entry
            in Map<String, Object?>.from(json['modules'] as Map? ?? const {})
                .entries)
          entry.key: _int(entry.value),
      },
    );
  }

  Map<String, Object?> toJson() {
    return {
      'operatorId': operatorId,
      'elite': elite,
      'level': level,
      'potential': potential,
      'skillLevels': skillLevels,
      if (modules.isNotEmpty) 'modules': modules,
    };
  }
}

int _int(Object? value) => (value as num? ?? 0).toInt();

DateTime? _time(Object? value) =>
    value is num ? DateTime.fromMillisecondsSinceEpoch(value.toInt()) : null;
