import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/http/http_client.dart';
import '../core/logging/app_logger.dart';
import '../core/logging/file_app_logger.dart';
import '../core/storage/app_directories.dart';
import '../core/storage/flutter_app_directories.dart';
import '../core/storage/legacy_tauri_paths.dart';
import '../data_sources/published_data.dart';
import '../repositories/file_image_cache_repository.dart';
import '../repositories/json_region_cache_repository.dart';
import '../repositories/json_user_data_repository.dart';
import '../repositories/region_cache_repository.dart';
import '../repositories/user_data_repository.dart';
import '../services/diagnostics_service.dart';
import '../services/file_picker_user_data_file_service.dart';
import '../services/file_diagnostics_service.dart';
import '../services/image_cache_service.dart';
import '../services/region_sync_service.dart';
import '../services/user_data_file_service.dart';

// Native (Windows, Android) implementations behind the providers in
// `providers.dart`: files under the app directories, a file log, the file
// image cache and the raw upstream sync as fallback.

final appDirectoriesProvider = Provider<AppDirectories>((ref) {
  return FlutterAppDirectories();
});

final fileAppLoggerProvider = Provider<FileAppLogger>((ref) {
  return FileAppLogger(ref.watch(appDirectoriesProvider));
});

AppLogger createAppLogger(Ref ref) => ref.watch(fileAppLoggerProvider);

RegionCacheRepository createRegionCacheRepository(Ref ref) {
  return JsonRegionCacheRepository(ref.watch(appDirectoriesProvider));
}

UserDataRepository createUserDataRepository(Ref ref) {
  return JsonUserDataRepository(
    ref.watch(appDirectoriesProvider),
    legacyUserDataFiles: legacyTauriUserDataFiles,
  );
}

Uri publishedDataBaseUri() => PublishedData.baseUri;

RegionSyncService? createRawRegionSync(
  NexusHttpClient httpClient,
  RegionCacheRepository cache,
) {
  return DartRegionSyncService(httpClient: httpClient, cache: cache);
}

ImageCacheService createImageCacheService(
  Ref ref,
  NexusHttpClient httpClient,
  AppLogger logger,
) {
  return DartImageCacheService(
    httpClient: httpClient,
    repository: FileImageCacheRepository(ref.watch(appDirectoriesProvider)),
    logger: logger,
  );
}

DiagnosticsService createDiagnosticsService(Ref ref) {
  return DartDiagnosticsService(
    directories: ref.watch(appDirectoriesProvider),
    logger: ref.watch(fileAppLoggerProvider),
  );
}

UserDataFileService createUserDataFileService() {
  return const FilePickerUserDataFileService();
}
