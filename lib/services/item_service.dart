import '../data_sources/region_code.dart';
import '../domain/building_formula.dart';
import '../domain/item.dart';
import '../repositories/region_cache_repository.dart';
import '../repositories/user_data_repository.dart';

class ItemQuery {
  const ItemQuery({
    required this.region,
    this.classifyType,
    this.search,
  });

  final RegionCode region;
  final String? classifyType;
  final String? search;
}

abstract interface class ItemService {
  Future<List<ItemEntry>> listItems(ItemQuery query);

  Future<BuildingFormulaBundle> listBuildingFormulas(RegionCode region);
}

class CachedItemService implements ItemService {
  const CachedItemService(
    this._cache, {
    UserDataRepository? userDataRepository,
  }) : _userDataRepository = userDataRepository;

  final RegionCacheRepository _cache;
  final UserDataRepository? _userDataRepository;

  @override
  Future<List<ItemEntry>> listItems(ItemQuery query) async {
    final snapshot = await _cache.readSnapshot(query.region);
    final items = snapshot?.items ?? const <ItemEntry>[];
    final classifyType = query.classifyType?.trim().toLowerCase();
    final search = query.search?.trim().toLowerCase() ?? '';

    final itemCounts = await _loadItemCounts();

    return items.where((item) {
      // Rust `list_items`: character tokens and vouchers are never listed,
      // and LMD (itemType GOLD) is kept whenever a classify type is given.
      if (item.itemId.contains('p_char') || item.itemId.contains('voucher')) {
        return false;
      }
      final matchesClassifyType = classifyType == null ||
          item.classifyType.toLowerCase() == classifyType ||
          item.itemType.toUpperCase() == 'GOLD';
      final matchesSearch = search.isEmpty ||
          item.name.toLowerCase().contains(search) ||
          item.itemId.toLowerCase().contains(search);

      return matchesClassifyType && matchesSearch;
    }).map((item) {
      return item.copyWith(ownedCount: itemCounts[item.itemId] ?? 0);
    }).toList();
  }

  @override
  Future<BuildingFormulaBundle> listBuildingFormulas(RegionCode region) async {
    final snapshot = await _cache.readSnapshot(region);
    return snapshot?.buildingFormulas ?? const BuildingFormulaBundle();
  }

  Future<Map<String, int>> _loadItemCounts() async {
    final repository = _userDataRepository;
    if (repository == null) {
      return const {};
    }
    return (await repository.read()).itemCounts;
  }
}
