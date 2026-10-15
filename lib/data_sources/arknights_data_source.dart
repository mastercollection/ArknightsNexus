class ArknightsDataSource {
  const ArknightsDataSource._();

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
}
