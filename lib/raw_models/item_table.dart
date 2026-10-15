import 'raw_helpers.dart';

class RawItemTable {
  const RawItemTable({this.items = const {}});

  final Map<String, RawItemEntry> items;

  factory RawItemTable.fromJson(Map<String, Object?> json) {
    return RawItemTable(
      items: rawMapOf(json['items'], RawItemEntry.fromJson),
    );
  }
}

class RawItemEntry {
  const RawItemEntry({
    required this.itemId,
    required this.name,
    this.description,
    required this.rarity,
    required this.iconId,
    required this.sortId,
    this.usage,
    this.obtainApproach,
    required this.classifyType,
    required this.itemType,
    this.stageDropList = const [],
    this.buildingProductList = const [],
  });

  final String itemId;
  final String name;
  final String? description;
  final String rarity;
  final String iconId;
  final int sortId;
  final String? usage;
  final String? obtainApproach;
  final String classifyType;
  final String itemType;
  final List<RawItemStageDrop> stageDropList;
  final List<RawItemBuildingProduct> buildingProductList;

  factory RawItemEntry.fromJson(Map<String, Object?> json) {
    return RawItemEntry(
      itemId: rawString(json, 'itemId'),
      name: rawString(json, 'name'),
      description: json['description'] as String?,
      rarity: rawString(json, 'rarity'),
      iconId: rawString(json, 'iconId'),
      sortId: rawInt(json, 'sortId'),
      usage: json['usage'] as String?,
      obtainApproach: json['obtainApproach'] as String?,
      classifyType: rawString(json, 'classifyType'),
      itemType: rawString(json, 'itemType'),
      stageDropList:
          rawListOf(json['stageDropList'], RawItemStageDrop.fromJson),
      buildingProductList: rawListOf(
        json['buildingProductList'],
        RawItemBuildingProduct.fromJson,
      ),
    );
  }
}

class RawItemStageDrop {
  const RawItemStageDrop({required this.stageId, required this.occPer});

  final String stageId;
  final String occPer;

  factory RawItemStageDrop.fromJson(Map<String, Object?> json) {
    return RawItemStageDrop(
      stageId: rawString(json, 'stageId'),
      occPer: rawString(json, 'occPer'),
    );
  }
}

class RawItemBuildingProduct {
  const RawItemBuildingProduct({
    required this.roomType,
    required this.formulaId,
  });

  final String roomType;
  final String formulaId;

  factory RawItemBuildingProduct.fromJson(Map<String, Object?> json) {
    return RawItemBuildingProduct(
      roomType: rawString(json, 'roomType'),
      formulaId: rawString(json, 'formulaId'),
    );
  }
}
