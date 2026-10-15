import 'raw_helpers.dart';

class RawUniequipTable {
  const RawUniequipTable({
    this.subProfDict = const {},
    this.equipDict = const {},
  });

  final Map<String, RawSubProfession> subProfDict;
  final Map<String, RawEquipEntry> equipDict;

  factory RawUniequipTable.fromJson(Map<String, Object?> json) {
    return RawUniequipTable(
      subProfDict: rawMapOf(json['subProfDict'], RawSubProfession.fromJson),
      equipDict: rawMapOf(json['equipDict'], RawEquipEntry.fromJson),
    );
  }

  /// Port of Tauri `RawUniequipTable::into_sub_prof_names`.
  Map<String, String> subProfNames() {
    final result = <String, String>{};
    for (final entry in subProfDict.entries) {
      final id = entry.value.subProfessionId.trim().isEmpty
          ? entry.key
          : entry.value.subProfessionId;
      final name = entry.value.subProfessionName.trim();
      if (id.trim().isEmpty || name.isEmpty) {
        continue;
      }
      result[id] = name;
    }
    return result;
  }

  /// Port of Tauri `RawUniequipTable::into_equip_modules_by_char`: modules
  /// grouped by trimmed `charId`, sorted by `charEquipOrder` then
  /// `uniEquipId`.
  Map<String, List<RawEquipEntry>> modulesByChar() {
    final result = <String, List<RawEquipEntry>>{};
    for (final equip in equipDict.values) {
      final charId = equip.charId.trim();
      if (charId.isEmpty) {
        continue;
      }
      result.putIfAbsent(charId, () => []).add(equip);
    }
    for (final modules in result.values) {
      modules.sort((left, right) {
        final order = left.charEquipOrder.compareTo(right.charEquipOrder);
        if (order != 0) {
          return order;
        }
        return compareRustStrings(left.uniEquipId, right.uniEquipId);
      });
    }
    return result;
  }
}

class RawSubProfession {
  const RawSubProfession({
    required this.subProfessionId,
    required this.subProfessionName,
  });

  final String subProfessionId;
  final String subProfessionName;

  factory RawSubProfession.fromJson(Map<String, Object?> json) {
    return RawSubProfession(
      subProfessionId: rawString(json, 'subProfessionId'),
      subProfessionName: rawString(json, 'subProfessionName'),
    );
  }
}

class RawEquipEntry {
  const RawEquipEntry({
    required this.uniEquipId,
    required this.uniEquipName,
    required this.uniEquipIcon,
    required this.uniEquipDesc,
    required this.typeIcon,
    required this.charId,
    required this.unlockEvolvePhase,
    required this.unlockLevel,
    this.missionList = const [],
    this.unlockFavors,
    this.itemCost,
    this.isSpecialEquip = false,
    this.specialEquipDesc,
    this.charEquipOrder = 0,
  });

  final String uniEquipId;
  final String uniEquipName;
  final String uniEquipIcon;
  final String uniEquipDesc;
  final String typeIcon;
  final String charId;
  final String unlockEvolvePhase;
  final int unlockLevel;
  final List<String> missionList;
  final Map<String, int>? unlockFavors;

  /// null when upstream sends null or `{}` (Tauri
  /// `deserialize_optional_item_cost`).
  final Map<String, List<RawCost>>? itemCost;
  final bool isSpecialEquip;
  final String? specialEquipDesc;
  final int charEquipOrder;

  factory RawEquipEntry.fromJson(Map<String, Object?> json) {
    final unlockFavors = json['unlockFavors'];
    final itemCost = json['itemCost'];
    return RawEquipEntry(
      uniEquipId: rawString(json, 'uniEquipId'),
      uniEquipName: rawString(json, 'uniEquipName'),
      uniEquipIcon: rawString(json, 'uniEquipIcon'),
      uniEquipDesc: rawString(json, 'uniEquipDesc'),
      typeIcon: rawString(json, 'typeIcon'),
      charId: rawString(json, 'charId'),
      unlockEvolvePhase: rawString(json, 'unlockEvolvePhase'),
      unlockLevel: rawInt(json, 'unlockLevel'),
      missionList: rawStringList(json['missionList']),
      unlockFavors: unlockFavors is Map
          ? rawMap(unlockFavors)
              .map((key, _) => MapEntry(key, rawInt(rawMap(unlockFavors), key)))
          : null,
      itemCost: itemCost is Map && itemCost.isNotEmpty
          ? rawMap(itemCost).map(
              (key, value) => MapEntry(key, rawListOf(value, RawCost.fromJson)),
            )
          : null,
      isSpecialEquip: rawBool(json, 'isSpecialEquip'),
      specialEquipDesc: rawOptString(json, 'specialEquipDesc'),
      charEquipOrder: rawInt(json, 'charEquipOrder'),
    );
  }
}
