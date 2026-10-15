import '../../domain/building_formula.dart';
import '../../raw_models/building_data.dart';
import '../../raw_models/raw_helpers.dart';

class BuildingFormulaNormalizer {
  const BuildingFormulaNormalizer();

  BuildingFormulaBundle normalize(RawBuildingData data) {
    // Sort orders mirror Tauri `normalize_building_data`.
    return BuildingFormulaBundle(
      manufactFormulas:
          data.manufactFormulas.values.map(_manufacturing).toList()
            ..sort((left, right) {
              final item = compareRustStrings(left.itemId, right.itemId);
              return item != 0
                  ? item
                  : compareRustStrings(left.formulaId, right.formulaId);
            }),
      workshopFormulas: data.workshopFormulas.values.map(_workshop).toList()
        ..sort((left, right) {
          final sortId = left.sortId.compareTo(right.sortId);
          if (sortId != 0) {
            return sortId;
          }
          final item = compareRustStrings(left.itemId, right.itemId);
          return item != 0
              ? item
              : compareRustStrings(left.formulaId, right.formulaId);
        }),
    );
  }

  ManufacturingFormula _manufacturing(RawManufactFormula raw) {
    return ManufacturingFormula(
      formulaId: raw.formulaId,
      itemId: raw.itemId,
      count: raw.count,
      weight: raw.weight,
      costPoint: raw.costPoint,
      formulaType: raw.formulaType,
      buffType: raw.buffType,
      costs: raw.costs.map(_cost).toList(),
      requireRooms: raw.requireRooms.map(_room).toList(),
    );
  }

  WorkshopFormula _workshop(RawWorkshopFormula raw) {
    return WorkshopFormula(
      sortId: raw.sortId,
      formulaId: raw.formulaId,
      rarity: raw.rarity,
      itemId: raw.itemId,
      count: raw.count,
      goldCost: raw.goldCost,
      apCost: raw.apCost,
      formulaType: raw.formulaType,
      buffType: raw.buffType,
      extraOutcomeRate: raw.extraOutcomeRate,
      extraOutcomeGroup: raw.extraOutcomeGroup
          .map(
            (entry) => FormulaExtraOutcome(
              weight: entry.weight,
              itemId: entry.itemId,
              itemCount: entry.itemCount,
            ),
          )
          .toList(),
      costs: raw.costs.map(_cost).toList(),
      requireRooms: raw.requireRooms.map(_room).toList(),
    );
  }

  FormulaCost _cost(RawCost raw) {
    return FormulaCost(id: raw.id, count: raw.count, type: raw.type);
  }

  FormulaRoomRequirement _room(RawBuildingRequireRoom raw) {
    return FormulaRoomRequirement(
      roomId: raw.roomId,
      roomLevel: raw.roomLevel,
      roomCount: raw.roomCount,
    );
  }
}
