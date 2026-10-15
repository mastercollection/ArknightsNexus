import '../data_sources/region_code.dart';
import '../domain/region_snapshot.dart';
import '../domain/sync_status.dart';

abstract interface class RegionCacheRepository {
  Future<RegionSnapshot?> readSnapshot(RegionCode region);

  Future<RegionSummarySnapshot?> readSummary(RegionCode region);

  Future<RegionSyncStatus?> readStatus(RegionCode region);

  Future<Map<String, String>> readTerms(RegionCode region);

  Future<void> writeSnapshot(RegionSnapshot snapshot);

  Future<void> writeSummary(RegionSummarySnapshot summary);

  Future<void> writeStatus(RegionSyncStatus status);

  Future<void> writeTerms(RegionCode region, Map<String, String> terms);
}
