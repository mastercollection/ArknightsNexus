import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../core/http/http_client.dart';
import '../core/logging/app_logger.dart';
import '../core/logging/console_app_logger.dart';
import '../core/storage/local_storage_key_value_store.dart';
import '../data_sources/published_data.dart';
import '../repositories/key_value_user_data_repository.dart';
import '../repositories/memory_region_cache_repository.dart';
import '../repositories/region_cache_repository.dart';
import '../repositories/user_data_repository.dart';
import '../services/browser_user_data_file_service.dart';
import '../services/diagnostics_service.dart';
import '../services/image_cache_service.dart';
import '../services/network_image_service.dart';
import '../services/region_sync_service.dart';
import '../services/user_data_file_service.dart';

// Web implementations behind the providers in `providers.dart`: the console
// log, user data in localStorage, region data in memory from the published
// snapshot of the same site, and images straight from their URLs.

AppLogger createAppLogger(Ref ref) => const ConsoleAppLogger();

RegionCacheRepository createRegionCacheRepository(Ref ref) {
  return MemoryRegionCacheRepository();
}

UserDataRepository createUserDataRepository(Ref ref) {
  return KeyValueUserDataRepository(const LocalStorageKeyValueStore());
}

/// The site's own `data/` directory, next to the app (resolved against the
/// page's `<base href>`), unless `NEXUS_DATA_BASE_URL` names another one.
Uri publishedDataBaseUri() {
  if (const bool.hasEnvironment('NEXUS_DATA_BASE_URL')) {
    return PublishedData.baseUri;
  }
  return Uri.parse(web.document.baseURI).resolve('data/');
}

/// None: the raw upstream tables are about 80 MB, too much for a browser.
RegionSyncService? createRawRegionSync(
  NexusHttpClient httpClient,
  RegionCacheRepository cache,
) {
  return null;
}

ImageCacheService createImageCacheService(
  Ref ref,
  NexusHttpClient httpClient,
  AppLogger logger,
) {
  return NetworkImageService(httpClient: httpClient, logger: logger);
}

DiagnosticsService createDiagnosticsService(Ref ref) {
  return const BrowserDiagnosticsService();
}

UserDataFileService createUserDataFileService() {
  return const BrowserUserDataFileService();
}
