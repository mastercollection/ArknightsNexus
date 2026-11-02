class ArknightsDataSource {
  const ArknightsDataSource._();

  static const dataVersionFile = 'data_version.txt';

  static const requiredTableFiles = [
    characterTableFile,
    skillTableFile,
    gamedataConstFile,
    uniequipTableFile,
    handbookTeamTableFile,
    rangeTableFile,
    itemTableFile,
    stageTableFile,
    buildingDataFile,
    battleEquipTableFile,
    favorTableFile,
    handbookInfoTableFile,
    zoneTableFile,
    enemyHandbookTableFile,
    enemyDatabaseFile,
  ];

  static const characterTableFile = 'character_table.json';
  static const skillTableFile = 'skill_table.json';
  static const gamedataConstFile = 'gamedata_const.json';
  static const uniequipTableFile = 'uniequip_table.json';
  static const handbookTeamTableFile = 'handbook_team_table.json';
  static const rangeTableFile = 'range_table.json';
  static const itemTableFile = 'item_table.json';
  static const stageTableFile = 'stage_table.json';
  static const buildingDataFile = 'building_data.json';
  static const battleEquipTableFile = 'battle_equip_table.json';
  static const favorTableFile = 'favor_table.json';

  /// Only the key order of its `handbookDict` is used: the release order.
  static const handbookInfoTableFile = 'handbook_info_table.json';
  static const zoneTableFile = 'zone_table.json';
  static const enemyHandbookTableFile = 'enemy_handbook_table.json';

  /// Every enemy's stats; the one table outside `excel/`.
  static const enemyDatabaseFile = 'enemy_database.json';

  /// Where [fileName] sits under a region's `gamedata/`.
  static String tablePath(String fileName) => fileName == enemyDatabaseFile
      ? 'levels/enemydata/$fileName'
      : 'excel/$fileName';
}
