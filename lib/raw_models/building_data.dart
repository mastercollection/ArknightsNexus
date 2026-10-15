import 'raw_helpers.dart';

class RawBuildingData {
  const RawBuildingData({
    this.manufactFormulas = const {},
    this.workshopFormulas = const {},
  });

  final Map<String, RawManufactFormula> manufactFormulas;
  final Map<String, RawWorkshopFormula> workshopFormulas;

  factory RawBuildingData.fromJson(Map<String, Object?> json) {
    return RawBuildingData(
      manufactFormulas:
          rawMapOf(json['manufactFormulas'], RawManufactFormula.fromJson),
      workshopFormulas:
          rawMapOf(json['workshopFormulas'], RawWorkshopFormula.fromJson),
    );
  }
}

class RawManufactFormula {
  const RawManufactFormula({
    required this.formulaId,
    required this.itemId,
    required this.count,
    required this.weight,
    required this.costPoint,
    required this.formulaType,
    required this.buffType,
    this.costs = const [],
    this.requireRooms = const [],
  });

  final String formulaId;
  final String itemId;
  final int count;
  final int weight;
  final int costPoint;
  final String formulaType;
  final String buffType;
  final List<RawCost> costs;
  final List<RawBuildingRequireRoom> requireRooms;

  factory RawManufactFormula.fromJson(Map<String, Object?> json) {
    return RawManufactFormula(
      formulaId: rawString(json, 'formulaId'),
      itemId: rawString(json, 'itemId'),
      count: rawInt(json, 'count'),
      weight: rawInt(json, 'weight'),
      costPoint: rawInt(json, 'costPoint'),
      formulaType: rawString(json, 'formulaType'),
      buffType: rawString(json, 'buffType'),
      costs: rawListOf(json['costs'], RawCost.fromJson),
      requireRooms:
          rawListOf(json['requireRooms'], RawBuildingRequireRoom.fromJson),
    );
  }
}

class RawWorkshopFormula {
  const RawWorkshopFormula({
    required this.sortId,
    required this.formulaId,
    required this.rarity,
    required this.itemId,
    required this.count,
    required this.goldCost,
    required this.apCost,
    required this.formulaType,
    required this.buffType,
    required this.extraOutcomeRate,
    this.extraOutcomeGroup = const [],
    this.costs = const [],
    this.requireRooms = const [],
  });

  final int sortId;
  final String formulaId;
  final int rarity;
  final String itemId;
  final int count;
  final int goldCost;
  final int apCost;
  final String formulaType;
  final String buffType;
  final double extraOutcomeRate;
  final List<RawWorkshopExtraOutcome> extraOutcomeGroup;
  final List<RawCost> costs;
  final List<RawBuildingRequireRoom> requireRooms;

  factory RawWorkshopFormula.fromJson(Map<String, Object?> json) {
    return RawWorkshopFormula(
      sortId: rawInt(json, 'sortId'),
      formulaId: rawString(json, 'formulaId'),
      rarity: rawInt(json, 'rarity'),
      itemId: rawString(json, 'itemId'),
      count: rawInt(json, 'count'),
      goldCost: rawInt(json, 'goldCost'),
      apCost: rawInt(json, 'apCost'),
      formulaType: rawString(json, 'formulaType'),
      buffType: rawString(json, 'buffType'),
      extraOutcomeRate: rawDouble(json, 'extraOutcomeRate'),
      extraOutcomeGroup: rawListOf(
        json['extraOutcomeGroup'],
        RawWorkshopExtraOutcome.fromJson,
      ),
      costs: rawListOf(json['costs'], RawCost.fromJson),
      requireRooms:
          rawListOf(json['requireRooms'], RawBuildingRequireRoom.fromJson),
    );
  }
}

class RawWorkshopExtraOutcome {
  const RawWorkshopExtraOutcome({
    required this.weight,
    required this.itemId,
    required this.itemCount,
  });

  final int weight;
  final String itemId;
  final int itemCount;

  factory RawWorkshopExtraOutcome.fromJson(Map<String, Object?> json) {
    return RawWorkshopExtraOutcome(
      weight: rawInt(json, 'weight'),
      itemId: rawString(json, 'itemId'),
      itemCount: rawInt(json, 'itemCount'),
    );
  }
}

class RawBuildingRequireRoom {
  const RawBuildingRequireRoom({
    required this.roomId,
    required this.roomLevel,
    required this.roomCount,
  });

  final String roomId;
  final int roomLevel;
  final int roomCount;

  factory RawBuildingRequireRoom.fromJson(Map<String, Object?> json) {
    return RawBuildingRequireRoom(
      roomId: rawString(json, 'roomId'),
      roomLevel: rawInt(json, 'roomLevel'),
      roomCount: rawInt(json, 'roomCount'),
    );
  }
}
