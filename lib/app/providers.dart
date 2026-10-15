import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/http/package_http_client.dart';
import '../core/logging/app_logger.dart';
import '../repositories/region_cache_repository.dart';
import '../repositories/user_data_repository.dart';
import '../services/image_cache_service.dart';
import '../services/diagnostics_service.dart';
import '../services/item_service.dart';
import '../services/operator_service.dart';
import '../services/penguin_stats_service.dart';
import '../services/plan_cost_service.dart';
import '../services/published_snapshot_sync_service.dart';
import '../services/region_readiness.dart';
import '../services/region_sync_service.dart';
import '../services/user_data_file_service.dart';
import '../services/user_data_service.dart';
import 'platform_providers_web.dart'
    if (dart.library.io) 'platform_providers_io.dart' as platform;

final appLoggerProvider = Provider<AppLogger>(platform.createAppLogger);

final regionCacheRepositoryProvider = Provider<RegionCacheRepository>(
  platform.createRegionCacheRepository,
);

final userDataRepositoryProvider = Provider<UserDataRepository>(
  platform.createUserDataRepository,
);

final regionReadinessProvider = Provider<RegionReadiness>((ref) {
  return RegionReadiness(
    ref.watch(regionSyncServiceProvider),
    ref.watch(appLoggerProvider),
    cache: ref.watch(regionCacheRepositoryProvider),
  );
});

final operatorServiceProvider = Provider<OperatorService>((ref) {
  return EnsuringOperatorService(
    CachedOperatorService(ref.watch(regionCacheRepositoryProvider)),
    ref.watch(regionReadinessProvider),
  );
});

final itemServiceProvider = Provider<ItemService>((ref) {
  return EnsuringItemService(
    CachedItemService(
      ref.watch(regionCacheRepositoryProvider),
      userDataRepository: ref.watch(userDataRepositoryProvider),
    ),
    ref.watch(regionReadinessProvider),
  );
});

final regionSyncServiceProvider = Provider<RegionSyncService>((ref) {
  final httpClient = PackageHttpClient();
  ref.onDispose(httpClient.close);
  final cache = ref.watch(regionCacheRepositoryProvider);
  return PublishedSnapshotSyncService(
    httpClient: httpClient,
    cache: cache,
    logger: ref.watch(appLoggerProvider),
    baseUri: platform.publishedDataBaseUri(),
    fallback: platform.createRawRegionSync(httpClient, cache),
  );
});

final planCostServiceProvider = Provider<PlanCostService>((ref) {
  return const DartPlanCostService();
});

final userDataServiceProvider = Provider<UserDataService>((ref) {
  return UserDataService(ref.watch(userDataRepositoryProvider));
});

final imageCacheServiceProvider = Provider<ImageCacheService>((ref) {
  final httpClient = PackageHttpClient();
  ref.onDispose(httpClient.close);
  return platform.createImageCacheService(
    ref,
    httpClient,
    ref.watch(appLoggerProvider),
  );
});

final penguinStatsServiceProvider = Provider<PenguinStatsService>((ref) {
  final httpClient = PackageHttpClient();
  ref.onDispose(httpClient.close);
  return DartPenguinStatsService(httpClient: httpClient);
});

final diagnosticsServiceProvider = Provider<DiagnosticsService>(
  platform.createDiagnosticsService,
);

/// Bumped after a manual region sync so screens reload their cached data.
final dataRevisionProvider = StateProvider<int>((ref) => 0);

final userDataFileServiceProvider = Provider<UserDataFileService>((ref) {
  return platform.createUserDataFileService();
});
