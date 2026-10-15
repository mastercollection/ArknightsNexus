import '../data_sources/region_code.dart';
import '../domain/region_snapshot.dart';
import '../domain/sync_status.dart';
import 'region_cache_repository.dart';

/// Region cache that lives only as long as the app: the web build keeps the
/// decoded snapshot in memory instead of writing it to storage (a region is
/// tens of megabytes of JSON, beyond what browser key-value storage holds).
/// The next visit downloads the published snapshot again, normally from the
/// browser's HTTP cache.
class MemoryRegionCacheRepository implements RegionCacheRepository {
  final _snapshots = <RegionCode, RegionSnapshot>{};
  final _summaries = <RegionCode, RegionSummarySnapshot>{};
  final _statuses = <RegionCode, RegionSyncStatus>{};
  final _terms = <RegionCode, Map<String, String>>{};

  @override
  Future<RegionSnapshot?> readSnapshot(RegionCode region) async =>
      _snapshots[region];

  @override
  Future<RegionSummarySnapshot?> readSummary(RegionCode region) async =>
      _summaries[region];

  @override
  Future<RegionSyncStatus?> readStatus(RegionCode region) async =>
      _statuses[region];

  @override
  Future<Map<String, String>> readTerms(RegionCode region) async {
    // Callers get their own copy, like the file-backed cache.
    return {...?_terms[region]};
  }

  @override
  Future<void> writeSnapshot(RegionSnapshot snapshot) async {
    _snapshots[snapshot.region] = snapshot;
  }

  @override
  Future<void> writeSummary(RegionSummarySnapshot summary) async {
    _summaries[summary.region] = summary;
  }

  @override
  Future<void> writeStatus(RegionSyncStatus status) async {
    _statuses[status.region] = status;
  }

  @override
  Future<void> writeTerms(RegionCode region, Map<String, String> terms) async {
    _terms[region] = {...terms};
  }
}
