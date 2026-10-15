class ItemEntry {
  const ItemEntry({
    required this.itemId,
    required this.name,
    required this.description,
    required this.rarity,
    required this.iconId,
    required this.sortId,
    required this.usage,
    required this.obtainApproach,
    required this.classifyType,
    required this.itemType,
    this.ownedCount = 0,
    this.stageDropList = const [],
    this.buildingProductList = const [],
  });

  final String itemId;
  final String name;
  final String description;
  final String rarity;
  final String iconId;
  final int sortId;
  final String usage;
  final String obtainApproach;
  final String classifyType;
  final String itemType;
  final int ownedCount;
  final List<ItemStageDrop> stageDropList;
  final List<ItemBuildingProduct> buildingProductList;

  factory ItemEntry.fromJson(Map<String, Object?> json) {
    return ItemEntry(
      itemId: json['itemId'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      rarity: json['rarity'] as String,
      iconId: json['iconId'] as String,
      sortId: (json['sortId'] as num).toInt(),
      usage: json['usage'] as String,
      obtainApproach: json['obtainApproach'] as String,
      classifyType: json['classifyType'] as String,
      itemType: json['itemType'] as String,
      ownedCount: (json['ownedCount'] as num?)?.toInt() ?? 0,
      stageDropList: _list(
        json['stageDropList'],
        (value) => ItemStageDrop.fromJson(_map(value)),
      ),
      buildingProductList: _list(
        json['buildingProductList'],
        (value) => ItemBuildingProduct.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'description': description,
      'rarity': rarity,
      'iconId': iconId,
      'sortId': sortId,
      'usage': usage,
      'obtainApproach': obtainApproach,
      'classifyType': classifyType,
      'itemType': itemType,
      'ownedCount': ownedCount,
      'stageDropList': stageDropList.map((entry) => entry.toJson()).toList(),
      'buildingProductList':
          buildingProductList.map((entry) => entry.toJson()).toList(),
    };
  }

  ItemEntry copyWith({int? ownedCount}) {
    return ItemEntry(
      itemId: itemId,
      name: name,
      description: description,
      rarity: rarity,
      iconId: iconId,
      sortId: sortId,
      usage: usage,
      obtainApproach: obtainApproach,
      classifyType: classifyType,
      itemType: itemType,
      ownedCount: ownedCount ?? this.ownedCount,
      stageDropList: stageDropList,
      buildingProductList: buildingProductList,
    );
  }
}

class ItemStageDrop {
  const ItemStageDrop({
    required this.stageId,
    this.stageCode,
    required this.occPer,
  });

  final String stageId;
  final String? stageCode;
  final String occPer;

  factory ItemStageDrop.fromJson(Map<String, Object?> json) {
    return ItemStageDrop(
      stageId: json['stageId'] as String,
      stageCode: json['stageCode'] as String?,
      occPer: json['occPer'] as String,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'stageId': stageId,
      'stageCode': stageCode,
      'occPer': occPer,
    };
  }
}

class ItemBuildingProduct {
  const ItemBuildingProduct({
    required this.roomType,
    required this.formulaId,
  });

  final String roomType;
  final String formulaId;

  factory ItemBuildingProduct.fromJson(Map<String, Object?> json) {
    return ItemBuildingProduct(
      roomType: json['roomType'] as String,
      formulaId: json['formulaId'] as String,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'roomType': roomType,
      'formulaId': formulaId,
    };
  }
}

Map<String, Object?> _map(Object? value) {
  return Map<String, Object?>.from(value! as Map);
}

List<T> _list<T>(Object? value, T Function(Object?) convert) {
  return (value as List? ?? const []).map(convert).toList();
}
