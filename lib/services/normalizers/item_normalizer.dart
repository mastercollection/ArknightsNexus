import '../../domain/item.dart';
import '../../raw_models/building_data.dart';
import '../../raw_models/item_table.dart';
import '../../raw_models/raw_helpers.dart';
import '../../raw_models/stage_table.dart';

class ItemNormalizer {
  const ItemNormalizer();

  List<ItemEntry> normalize(
    RawItemTable itemTable,
    RawStageTable stageTable,
    RawBuildingData _,
  ) {
    final stageCodes = stageCodeMap(stageTable);

    final items = itemTable.items.values.map((raw) {
      return ItemEntry(
        itemId: raw.itemId,
        name: raw.name,
        description: raw.description ?? '',
        rarity: raw.rarity,
        iconId: raw.iconId,
        sortId: raw.sortId,
        usage: raw.usage ?? '',
        obtainApproach: raw.obtainApproach ?? '',
        classifyType: raw.classifyType,
        itemType: raw.itemType,
        stageDropList: raw.stageDropList
            .map(
              (entry) => ItemStageDrop(
                stageId: entry.stageId,
                stageCode: stageCodes[entry.stageId],
                occPer: entry.occPer,
              ),
            )
            .toList(),
        buildingProductList: [
          ...raw.buildingProductList.map(
            (entry) => ItemBuildingProduct(
              roomType: entry.roomType,
              formulaId: entry.formulaId,
            ),
          ),
        ],
      );
    }).toList();

    items.sort(_compareItems);
    return items;
  }

  int _compareItems(ItemEntry left, ItemEntry right) {
    final sortIdComparison = left.sortId.compareTo(right.sortId);
    if (sortIdComparison != 0) {
      return sortIdComparison;
    }

    final nameComparison = compareRustStrings(left.name, right.name);
    if (nameComparison != 0) {
      return nameComparison;
    }

    return compareRustStrings(left.itemId, right.itemId);
  }

  /// Port of the Tauri `stage_codes_by_id` map: trimmed stage id → trimmed
  /// code, entries with a blank id or code dropped.
  Map<String, String> stageCodeMap(RawStageTable stageTable) {
    final result = <String, String>{};
    for (final stage in stageTable.stages.values) {
      final stageId = stage.stageId.trim();
      final code = (stage.code ?? '').trim();
      if (stageId.isEmpty || code.isEmpty) {
        continue;
      }
      result[stageId] = code;
    }
    return result;
  }
}
