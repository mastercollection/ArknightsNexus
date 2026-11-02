import 'raw_helpers.dart';

/// `gamedata/levels/enemydata/enemy_database.json`: enemy id → its level
/// entries. Level 0 is the full enemy; the other levels (and a stage's
/// `overwrittenData`) only patch the fields they mark `m_defined`, so read a
/// stat with [RawEnemyData.overlay].
class RawEnemyDatabase {
  const RawEnemyDatabase({this.enemies = const {}});

  final Map<String, List<RawEnemyLevel>> enemies;

  factory RawEnemyDatabase.fromJson(Map<String, Object?> json) {
    return RawEnemyDatabase(
      enemies: json.map(
        (id, levels) => MapEntry(id, rawListOf(levels, RawEnemyLevel.fromJson)),
      ),
    );
  }

  /// [id] at [level]: level 0 with that level's patch applied. Null when the
  /// database does not have [id].
  RawEnemyData? resolve(String id, int level) {
    final levels = enemies[id];
    if (levels == null || levels.isEmpty) {
      return null;
    }
    final base = levels.firstWhere(
      (entry) => entry.level == 0,
      orElse: () => levels.first,
    );
    if (level == base.level) {
      return base.enemyData;
    }
    for (final entry in levels) {
      if (entry.level == level) {
        return base.enemyData.overlay(entry.enemyData);
      }
    }
    return base.enemyData;
  }
}

class RawEnemyLevel {
  const RawEnemyLevel({required this.level, required this.enemyData});

  final int level;
  final RawEnemyData enemyData;

  factory RawEnemyLevel.fromJson(Map<String, Object?> json) {
    return RawEnemyLevel(
      level: rawInt(json, 'level'),
      enemyData: RawEnemyData.fromJson(rawMap(json['enemyData'])),
    );
  }
}

/// An upstream `{m_defined, m_value}` field.
class RawDefined<T> {
  const RawDefined(this.value, {this.defined = true});

  /// Whether the entry sets this field; a patch leaves the others alone.
  final bool defined;
  final T value;

  /// [patch] where it is defined, this field otherwise.
  RawDefined<T> overlay(RawDefined<T> patch) => patch.defined ? patch : this;

  static RawDefined<T> parse<T>(
    Object? json,
    T Function(Object? value) convert,
  ) {
    final map = rawMap(json);
    return RawDefined(
      convert(map['m_value']),
      defined: map['m_defined'] == true,
    );
  }
}

String? _optString(Object? value) => value?.toString();
int _int(Object? value) => value is num ? value.toInt() : 0;
double _double(Object? value) => value is num ? value.toDouble() : 0;
bool _bool(Object? value) => value == true;

class RawEnemyData {
  const RawEnemyData({
    this.name = const RawDefined(null, defined: false),
    this.description = const RawDefined(null, defined: false),
    this.applyWay = const RawDefined(null, defined: false),
    this.motion = const RawDefined(null, defined: false),
    this.levelType = const RawDefined(null, defined: false),
    this.lifePointReduce = const RawDefined(0, defined: false),
    this.rangeRadius = const RawDefined(0, defined: false),
    this.enemyTags = const RawDefined([], defined: false),
    this.attributes = const RawEnemyAttributes(),
    this.skills,
    this.talents,
  });

  final RawDefined<String?> name;
  final RawDefined<String?> description;

  /// `MELEE`, `RANGED`, `ALL` or `NONE`.
  final RawDefined<String?> applyWay;

  /// `WALK` or `FLY`.
  final RawDefined<String?> motion;

  /// `NORMAL`, `ELITE` or `BOSS`.
  final RawDefined<String?> levelType;
  final RawDefined<int> lifePointReduce;

  /// Attack range in tiles; 0 for melee enemies.
  final RawDefined<double> rangeRadius;
  final RawDefined<List<String>> enemyTags;
  final RawEnemyAttributes attributes;

  /// Null when the entry leaves the skills alone (a patch keeps the ones
  /// below); a list replaces them whole.
  final List<RawEnemySkill>? skills;

  /// The talent values (`talentBlackboard`); null as for [skills].
  final List<RawBlackboard>? talents;

  RawEnemyData overlay(RawEnemyData patch) {
    return RawEnemyData(
      name: name.overlay(patch.name),
      description: description.overlay(patch.description),
      applyWay: applyWay.overlay(patch.applyWay),
      motion: motion.overlay(patch.motion),
      levelType: levelType.overlay(patch.levelType),
      lifePointReduce: lifePointReduce.overlay(patch.lifePointReduce),
      rangeRadius: rangeRadius.overlay(patch.rangeRadius),
      enemyTags: enemyTags.overlay(patch.enemyTags),
      attributes: attributes.overlay(patch.attributes),
      skills: patch.skills ?? skills,
      talents: patch.talents ?? talents,
    );
  }

  factory RawEnemyData.fromJson(Map<String, Object?> json) {
    return RawEnemyData(
      name: RawDefined.parse(json['name'], _optString),
      description: RawDefined.parse(json['description'], _optString),
      applyWay: RawDefined.parse(json['applyWay'], _optString),
      motion: RawDefined.parse(json['motion'], _optString),
      levelType: RawDefined.parse(json['levelType'], _optString),
      lifePointReduce: RawDefined.parse(json['lifePointReduce'], _int),
      rangeRadius: RawDefined.parse(json['rangeRadius'], _double),
      enemyTags: RawDefined.parse(json['enemyTags'], rawStringList),
      attributes: RawEnemyAttributes.fromJson(rawMap(json['attributes'])),
      skills: rawOptListOf(json['skills'], RawEnemySkill.fromJson),
      talents: rawOptListOf(json['talentBlackboard'], RawBlackboard.fromJson),
    );
  }
}

/// A skill of an enemy. The data names it only by its [prefabKey]
/// (`ArcticBlast`); what it does is the archive's ability text.
class RawEnemySkill {
  const RawEnemySkill({
    required this.prefabKey,
    required this.priority,
    required this.cooldown,
    required this.initCooldown,
    required this.spCost,
    this.blackboard = const [],
  });

  final String prefabKey;
  final int priority;

  /// Seconds between uses.
  final double cooldown;

  /// Seconds before the first use.
  final double initCooldown;
  final int spCost;
  final List<RawBlackboard> blackboard;

  factory RawEnemySkill.fromJson(Map<String, Object?> json) {
    return RawEnemySkill(
      prefabKey: rawString(json, 'prefabKey'),
      priority: rawInt(json, 'priority'),
      cooldown: rawDouble(json, 'cooldown'),
      initCooldown: rawDouble(json, 'initCooldown'),
      spCost: rawInt(json, 'spCost'),
      blackboard: rawListOf(json['blackboard'], RawBlackboard.fromJson),
    );
  }
}

class RawEnemyAttributes {
  const RawEnemyAttributes({
    this.maxHp = const RawDefined(0, defined: false),
    this.atk = const RawDefined(0, defined: false),
    this.def = const RawDefined(0, defined: false),
    this.magicResistance = const RawDefined(0, defined: false),
    this.moveSpeed = const RawDefined(0, defined: false),
    this.attackSpeed = const RawDefined(0, defined: false),
    this.baseAttackTime = const RawDefined(0, defined: false),
    this.blockCnt = const RawDefined(0, defined: false),
    this.massLevel = const RawDefined(0, defined: false),
    this.hpRecoveryPerSec = const RawDefined(0, defined: false),
    this.epDamageResistance = const RawDefined(0, defined: false),
    this.epResistance = const RawDefined(0, defined: false),
    this.immunities = const {},
  });

  final RawDefined<int> maxHp;
  final RawDefined<int> atk;
  final RawDefined<int> def;
  final RawDefined<double> magicResistance;
  final RawDefined<double> moveSpeed;
  final RawDefined<double> attackSpeed;
  final RawDefined<double> baseAttackTime;
  final RawDefined<int> blockCnt;
  final RawDefined<int> massLevel;
  final RawDefined<double> hpRecoveryPerSec;

  /// Elemental damage resistance.
  final RawDefined<double> epDamageResistance;

  /// Elemental injury resistance.
  final RawDefined<double> epResistance;

  /// The `*Immune` attributes keyed by their name without the suffix
  /// (`stun`, `silence`, `sleep`, `frozen`, `levitate`, ...).
  final Map<String, RawDefined<bool>> immunities;

  RawEnemyAttributes overlay(RawEnemyAttributes patch) {
    return RawEnemyAttributes(
      maxHp: maxHp.overlay(patch.maxHp),
      atk: atk.overlay(patch.atk),
      def: def.overlay(patch.def),
      magicResistance: magicResistance.overlay(patch.magicResistance),
      moveSpeed: moveSpeed.overlay(patch.moveSpeed),
      attackSpeed: attackSpeed.overlay(patch.attackSpeed),
      baseAttackTime: baseAttackTime.overlay(patch.baseAttackTime),
      blockCnt: blockCnt.overlay(patch.blockCnt),
      massLevel: massLevel.overlay(patch.massLevel),
      hpRecoveryPerSec: hpRecoveryPerSec.overlay(patch.hpRecoveryPerSec),
      epDamageResistance: epDamageResistance.overlay(patch.epDamageResistance),
      epResistance: epResistance.overlay(patch.epResistance),
      immunities: {
        ...immunities,
        for (final entry in patch.immunities.entries)
          entry.key:
              (immunities[entry.key] ?? entry.value).overlay(entry.value),
      },
    );
  }

  static const _immuneSuffix = 'Immune';

  factory RawEnemyAttributes.fromJson(Map<String, Object?> json) {
    return RawEnemyAttributes(
      maxHp: RawDefined.parse(json['maxHp'], _int),
      atk: RawDefined.parse(json['atk'], _int),
      def: RawDefined.parse(json['def'], _int),
      magicResistance: RawDefined.parse(json['magicResistance'], _double),
      moveSpeed: RawDefined.parse(json['moveSpeed'], _double),
      attackSpeed: RawDefined.parse(json['attackSpeed'], _double),
      baseAttackTime: RawDefined.parse(json['baseAttackTime'], _double),
      blockCnt: RawDefined.parse(json['blockCnt'], _int),
      massLevel: RawDefined.parse(json['massLevel'], _int),
      hpRecoveryPerSec: RawDefined.parse(json['hpRecoveryPerSec'], _double),
      epDamageResistance: RawDefined.parse(json['epDamageResistance'], _double),
      epResistance: RawDefined.parse(json['epResistance'], _double),
      immunities: {
        for (final entry in json.entries)
          if (entry.key.endsWith(_immuneSuffix))
            entry.key.substring(0, entry.key.length - _immuneSuffix.length):
                RawDefined.parse(entry.value, _bool),
      },
    );
  }
}
