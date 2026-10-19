import '../../core/errors/app_failure.dart';
import '../../domain/account_profile.dart';
import '../../domain/item.dart';

/// Item ids of the currencies `syncData` keeps in `status`, not `inventory`.
const orundumItemId = '4003';
const originiumItemId = '4002';

/// The parts of a `syncData` response the app uses.
class AccountSync {
  const AccountSync({required this.profile, required this.itemCounts});

  final AccountProfile profile;

  /// Depot counts by item id, currencies included; only positive counts.
  final Map<String, int> itemCounts;
}

/// Reads [data] (the whole `account/syncData` response) of an account on
/// [region].
AccountSync parseAccountSync(
  Map<String, Object?> data, {
  required String region,
  required DateTime syncedAt,
}) {
  final user = _map(data['user']);
  if (user == null) {
    throw const ParseFailure('syncData has no user');
  }
  final status = _map(user['status']) ?? const {};
  final chars = _map(_map(user['troop'])?['chars']) ?? const {};

  final operators = <String, AccountOperator>{};
  for (final raw in chars.values) {
    final char = _map(raw);
    if (char == null) {
      continue;
    }
    // Amiya keeps one entry with a template per class she can switch to;
    // each template is a separate operator in the game data.
    final templates = _map(char['tmpl']);
    if (templates != null && templates.isNotEmpty) {
      for (final entry in templates.entries) {
        final template = _map(entry.value) ?? const {};
        operators[entry.key] = _operator(entry.key, char, template);
      }
      continue;
    }
    final charId = char['charId'];
    if (charId is String && charId.isNotEmpty) {
      operators[charId] = _operator(charId, char, char);
    }
  }

  final itemCounts = <String, int>{};
  for (final entry in (_map(user['inventory']) ?? const {}).entries) {
    final count = _int(entry.value);
    if (count > 0) {
      itemCounts[entry.key] = count;
    }
  }
  final gold = _int(status['gold']);
  final orundum = _int(status['diamondShard']);
  // Both platforms' counters hold the same shared originium on Yostar.
  final android = _int(status['androidDiamond']);
  final ios = _int(status['iosDiamond']);
  final originium = android > ios ? android : ios;
  for (final (id, count) in [
    (lmdItemId, gold),
    (orundumItemId, orundum),
    (originiumItemId, originium),
  ]) {
    if (count > 0) {
      itemCounts[id] = count;
    }
  }

  final sortedOperators = operators.values.toList()
    ..sort((left, right) => left.operatorId.compareTo(right.operatorId));
  return AccountSync(
    profile: AccountProfile(
      region: region,
      uid: '${status['uid'] ?? ''}',
      nickName: '${status['nickName'] ?? ''}',
      nickNumber: '${status['nickNumber'] ?? ''}',
      level: _int(status['level']),
      syncedAt: syncedAt,
      registeredAt: _seconds(status['registerTs']),
      ap: _int(status['ap']),
      maxAp: _int(status['maxAp']),
      lastApAddTime: _seconds(status['lastApAddTime']),
      gold: gold,
      orundum: orundum,
      originium: originium,
      inventoryKinds: itemCounts.length,
      operators: sortedOperators,
    ),
    itemCounts: itemCounts,
  );
}

/// [char] holds the shared progress (elite, level, potential, skill rank);
/// [template] the skills and modules (the char itself outside Amiya).
AccountOperator _operator(
  String operatorId,
  Map<String, Object?> char,
  Map<String, Object?> template,
) {
  final skillRank = _int(char['mainSkillLvl']).clamp(1, 7);
  final skills = template['skills'] as List? ?? const [];
  final modules = <String, int>{};
  for (final entry in (_map(template['equip']) ?? const {}).entries) {
    final equip = _map(entry.value) ?? const {};
    // `uniequip_001_*` is the operator's own (basic) branch, not a module.
    if (entry.key.startsWith('uniequip_001_') || _int(equip['locked']) != 0) {
      continue;
    }
    final stage = _int(equip['level']);
    if (stage > 0) {
      modules[entry.key] = stage;
    }
  }
  return AccountOperator(
    operatorId: operatorId,
    elite: _int(char['evolvePhase']),
    level: _int(char['level']),
    potential: _int(char['potentialRank']),
    skillLevels: [
      for (final skill in skills)
        skillRank + _int(_map(skill)?['specializeLevel']).clamp(0, 3),
    ],
    modules: modules,
  );
}

Map<String, Object?>? _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : null;

int _int(Object? value) => value is num ? value.toInt() : 0;

DateTime? _seconds(Object? value) {
  final seconds = _int(value);
  return seconds > 0
      ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000)
      : null;
}
