import '../../domain/stage.dart';
import '../../raw_models/enemy_database.dart';
import '../../raw_models/enemy_handbook.dart';
import '../../raw_models/level_data.dart';
import '../../raw_models/stage_table.dart';
import '../../raw_models/zone_table.dart';

class StageNormalizer {
  const StageNormalizer();

  /// Every stage of [stageTable] with an id and a code.
  List<StageSummary> summaries(
    RawStageTable stageTable,
    RawZoneTable zoneTable,
  ) {
    final result = <StageSummary>[];
    for (final raw in stageTable.stages.values) {
      final stageId = raw.stageId.trim();
      final code = (raw.code ?? '').trim();
      if (stageId.isEmpty || code.isEmpty) {
        continue;
      }
      final zone = zoneTable.zones[raw.zoneId];
      result.add(
        StageSummary(
          stageId: stageId,
          code: code,
          name: (raw.name ?? '').trim(),
          zoneId: raw.zoneId,
          zoneName: zone == null ? null : _zoneName(zone),
          stageType: raw.stageType,
          difficulty: raw.difficulty,
          diffGroup: raw.diffGroup,
          levelId: raw.levelId,
          apCost: raw.apCost,
          dangerLevel: raw.dangerLevel,
          bossMark: raw.bossMark,
        ),
      );
    }
    return result;
  }

  /// The battle of [stageId], whose level file is [level]. Enemies missing
  /// from [enemyDatabase] are left out.
  StageDetail detail(
    String stageId,
    RawLevelData level,
    RawEnemyDatabase enemyDatabase,
    RawEnemyHandbookTable handbook,
  ) {
    final counts = <String, int>{};
    var hasVariableSpawns = false;
    for (final wave in level.waves) {
      for (final fragment in wave.fragments) {
        for (final action in fragment.actions) {
          if (!action.isSpawn) {
            continue;
          }
          if (action.hiddenGroup != null ||
              action.randomSpawnGroupKey != null) {
            hasVariableSpawns = true;
          }
          counts[action.key] = (counts[action.key] ?? 0) + action.count;
        }
      }
    }

    final enemies = <StageEnemy>[];
    final seen = <String>{};
    for (final ref in level.enemyDbRefs) {
      if (!seen.add(ref.id)) {
        continue;
      }
      final data = _enemyData(ref, enemyDatabase);
      if (data == null) {
        continue;
      }
      enemies.add(
        _enemy(ref.id, data, handbook.enemyData[ref.id], counts[ref.id] ?? 0),
      );
    }

    return StageDetail(
      stageId: stageId,
      options: StageOptions(
        characterLimit: level.options.characterLimit,
        maxLifePoint: level.options.maxLifePoint,
        initialCost: level.options.initialCost,
        maxCost: level.options.maxCost,
        costIncreaseTime: level.options.costIncreaseTime,
      ),
      map: _map(level.mapData),
      routes: [
        for (final route in level.routes)
          StageRoute(
            motionMode: route.motionMode,
            start: _position(route.startPosition),
            end: _position(route.endPosition),
            waypoints: [
              for (final checkpoint in route.checkpoints)
                if (checkpoint.type == 'MOVE') _position(checkpoint.position),
            ],
          ),
      ],
      enemies: enemies,
      devices: [
        for (final token in level.tokenInsts)
          StageDevice(
            characterKey: token.characterKey,
            position: _position(token.position),
          ),
      ],
      hasVariableSpawns: hasVariableSpawns,
    );
  }

  String _zoneName(RawZoneEntry zone) {
    return [zone.zoneNameFirst, zone.zoneNameSecond]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  /// The enemy as this stage has it: its database level with the stage's
  /// own changes on top.
  RawEnemyData? _enemyData(RawEnemyDbRef ref, RawEnemyDatabase database) {
    final overwritten = ref.overwrittenData;
    if (!ref.useDb) {
      return overwritten;
    }
    final base = database.resolve(ref.id, ref.level);
    if (base == null || overwritten == null) {
      return base;
    }
    return base.overlay(overwritten);
  }

  StageEnemy _enemy(
    String id,
    RawEnemyData data,
    RawEnemyHandbookEntry? archive,
    int count,
  ) {
    final attributes = data.attributes;
    return StageEnemy(
      enemyId: id,
      name: archive?.name ?? data.name.value ?? id,
      enemyIndex: archive?.enemyIndex,
      levelType: (data.levelType.defined ? data.levelType.value : null) ??
          archive?.enemyLevel ??
          data.levelType.value ??
          'NORMAL',
      count: count,
      stats: EnemyStats(
        maxHp: attributes.maxHp.value,
        atk: attributes.atk.value,
        def: attributes.def.value,
        magicResistance: attributes.magicResistance.value,
        moveSpeed: attributes.moveSpeed.value,
        attackSpeed: attributes.attackSpeed.value,
        baseAttackTime: attributes.baseAttackTime.value,
        // Almost no enemy defines it: undefined means the game's default.
        blockCnt: attributes.blockCnt.defined ? attributes.blockCnt.value : 1,
        massLevel: attributes.massLevel.value,
        rangeRadius: data.rangeRadius.value,
        lifePointReduce: data.lifePointReduce.value,
        hpRecoveryPerSec: attributes.hpRecoveryPerSec.value,
        applyWay: data.applyWay.value ?? 'NONE',
        motion: data.motion.value ?? 'WALK',
        immunities: [
          for (final entry in attributes.immunities.entries)
            if (entry.value.value) entry.key,
        ],
      ),
      damageType: archive?.damageType ?? const [],
      abilities: [
        for (final ability in archive?.abilityList ?? const <RawEnemyAbility>[])
          ability.text,
      ],
    );
  }

  /// Flips the upstream top-row-first grid to bottom-row-first.
  StageMap _map(RawMapData mapData) {
    final rows = mapData.map;
    final height = rows.length;
    final width = height == 0 ? 0 : rows.first.length;
    return StageMap(
      width: width,
      height: height,
      tiles: [
        for (var row = 0; row < height; row++)
          for (final index in rows[height - 1 - row])
            _tile(mapData.tiles[index]),
      ],
    );
  }

  StageTile _tile(RawTile raw) {
    return StageTile(
      tileKey: raw.tileKey,
      heightType: raw.heightType,
      buildableType: raw.buildableType,
      passableMask: raw.passableMask,
    );
  }

  GridPosition _position(RawGridPosition raw) {
    return GridPosition(row: raw.row, col: raw.col);
  }
}
