import '../data_sources/region_code.dart';
import '../domain/operator.dart';
import '../repositories/region_cache_repository.dart';

class OperatorQuery {
  const OperatorQuery({
    required this.region,
    this.search,
    this.rarity,
    this.profession,
  });

  final RegionCode region;
  final String? search;
  final int? rarity;
  final String? profession;
}

abstract interface class OperatorService {
  Future<List<OperatorSummary>> listOperators(OperatorQuery query);

  Future<OperatorDetail?> getOperatorDetail(
    RegionCode region,
    String operatorId,
  );
}

class CachedOperatorService implements OperatorService {
  const CachedOperatorService(this._cache);

  final RegionCacheRepository _cache;

  @override
  Future<List<OperatorSummary>> listOperators(OperatorQuery query) async {
    final summary = await _cache.readSummary(query.region);
    final operators = summary?.operators ?? const <OperatorSummary>[];
    final search = query.search?.trim().toLowerCase() ?? '';
    final profession = query.profession?.trim().toLowerCase();

    return operators.where((operator) {
      final matchesSearch = search.isEmpty ||
          [
            operator.name,
            operator.profession,
            operator.branch,
            ...operator.teams,
            ...operator.nations,
            ...operator.groups,
          ].any((value) => value.toLowerCase().contains(search));
      final matchesRarity =
          query.rarity == null || operator.rarity == query.rarity;
      final matchesProfession =
          profession == null || operator.profession.toLowerCase() == profession;

      return matchesSearch && matchesRarity && matchesProfession;
    }).toList();
  }

  @override
  Future<OperatorDetail?> getOperatorDetail(
    RegionCode region,
    String operatorId,
  ) async {
    final snapshot = await _cache.readSnapshot(region);
    final normalizedId = operatorId.trim();
    for (final operator in snapshot?.operators ?? const <OperatorDetail>[]) {
      if (operator.id == normalizedId) {
        return operator;
      }
    }
    return null;
  }
}
