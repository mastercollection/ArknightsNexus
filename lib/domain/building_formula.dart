class BuildingFormulaBundle {
  const BuildingFormulaBundle({
    this.manufactFormulas = const [],
    this.workshopFormulas = const [],
  });

  final List<ManufacturingFormula> manufactFormulas;
  final List<WorkshopFormula> workshopFormulas;

  factory BuildingFormulaBundle.fromJson(Map<String, Object?> json) {
    return BuildingFormulaBundle(
      manufactFormulas: _list(
        json['manufactFormulas'],
        (value) => ManufacturingFormula.fromJson(_map(value)),
      ),
      workshopFormulas: _list(
        json['workshopFormulas'],
        (value) => WorkshopFormula.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'manufactFormulas':
          manufactFormulas.map((entry) => entry.toJson()).toList(),
      'workshopFormulas':
          workshopFormulas.map((entry) => entry.toJson()).toList(),
    };
  }
}

class ManufacturingFormula {
  const ManufacturingFormula({
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
  final List<FormulaCost> costs;
  final List<FormulaRoomRequirement> requireRooms;

  factory ManufacturingFormula.fromJson(Map<String, Object?> json) {
    return ManufacturingFormula(
      formulaId: json['formulaId'] as String,
      itemId: json['itemId'] as String,
      count: (json['count'] as num).toInt(),
      weight: (json['weight'] as num).toInt(),
      costPoint: (json['costPoint'] as num).toInt(),
      formulaType: json['formulaType'] as String,
      buffType: json['buffType'] as String,
      costs: _list(json['costs'], (value) => FormulaCost.fromJson(_map(value))),
      requireRooms: _list(
        json['requireRooms'],
        (value) => FormulaRoomRequirement.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'formulaId': formulaId,
      'itemId': itemId,
      'count': count,
      'weight': weight,
      'costPoint': costPoint,
      'formulaType': formulaType,
      'buffType': buffType,
      'costs': costs.map((entry) => entry.toJson()).toList(),
      'requireRooms': requireRooms.map((entry) => entry.toJson()).toList(),
    };
  }
}

class WorkshopFormula {
  const WorkshopFormula({
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
  final List<FormulaExtraOutcome> extraOutcomeGroup;
  final List<FormulaCost> costs;
  final List<FormulaRoomRequirement> requireRooms;

  factory WorkshopFormula.fromJson(Map<String, Object?> json) {
    return WorkshopFormula(
      sortId: (json['sortId'] as num).toInt(),
      formulaId: json['formulaId'] as String,
      rarity: (json['rarity'] as num).toInt(),
      itemId: json['itemId'] as String,
      count: (json['count'] as num).toInt(),
      goldCost: (json['goldCost'] as num).toInt(),
      apCost: (json['apCost'] as num).toInt(),
      formulaType: json['formulaType'] as String,
      buffType: json['buffType'] as String,
      extraOutcomeRate: (json['extraOutcomeRate'] as num).toDouble(),
      extraOutcomeGroup: _list(
        json['extraOutcomeGroup'],
        (value) => FormulaExtraOutcome.fromJson(_map(value)),
      ),
      costs: _list(json['costs'], (value) => FormulaCost.fromJson(_map(value))),
      requireRooms: _list(
        json['requireRooms'],
        (value) => FormulaRoomRequirement.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'sortId': sortId,
      'formulaId': formulaId,
      'rarity': rarity,
      'itemId': itemId,
      'count': count,
      'goldCost': goldCost,
      'apCost': apCost,
      'formulaType': formulaType,
      'buffType': buffType,
      'extraOutcomeRate': extraOutcomeRate,
      'extraOutcomeGroup':
          extraOutcomeGroup.map((entry) => entry.toJson()).toList(),
      'costs': costs.map((entry) => entry.toJson()).toList(),
      'requireRooms': requireRooms.map((entry) => entry.toJson()).toList(),
    };
  }
}

class FormulaCost {
  const FormulaCost({
    required this.id,
    required this.count,
    required this.type,
  });

  final String id;
  final double count;
  final String type;

  factory FormulaCost.fromJson(Map<String, Object?> json) {
    return FormulaCost(
      id: json['id'] as String,
      count: (json['count'] as num).toDouble(),
      type: json['type'] as String,
    );
  }

  Map<String, Object?> toJson() => {'id': id, 'count': count, 'type': type};
}

class FormulaRoomRequirement {
  const FormulaRoomRequirement({
    required this.roomId,
    required this.roomLevel,
    required this.roomCount,
  });

  final String roomId;
  final int roomLevel;
  final int roomCount;

  factory FormulaRoomRequirement.fromJson(Map<String, Object?> json) {
    return FormulaRoomRequirement(
      roomId: json['roomId'] as String,
      roomLevel: (json['roomLevel'] as num).toInt(),
      roomCount: (json['roomCount'] as num).toInt(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'roomId': roomId,
      'roomLevel': roomLevel,
      'roomCount': roomCount,
    };
  }
}

class FormulaExtraOutcome {
  const FormulaExtraOutcome({
    required this.weight,
    required this.itemId,
    required this.itemCount,
  });

  final int weight;
  final String itemId;
  final int itemCount;

  factory FormulaExtraOutcome.fromJson(Map<String, Object?> json) {
    return FormulaExtraOutcome(
      weight: (json['weight'] as num).toInt(),
      itemId: json['itemId'] as String,
      itemCount: (json['itemCount'] as num).toInt(),
    );
  }

  Map<String, Object?> toJson() {
    return {'weight': weight, 'itemId': itemId, 'itemCount': itemCount};
  }
}

Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value! as Map);

List<T> _list<T>(Object? value, T Function(Object?) convert) {
  return (value as List? ?? const []).map(convert).toList();
}
