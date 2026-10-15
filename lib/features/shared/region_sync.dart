import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/sync_status.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/nexus_ui.dart' show NexusMessageType, showNexusMessage;

/// Makes sure the selected region has data, downloading it on first use.
///
/// Watched by the shell so the download starts with the app instead of with
/// the first data screen; the web build starts every visit without data.
/// It shares [RegionReadiness]' once-per-session check with the data
/// services, so whichever starts first, the other waits for the same work.
final regionEnsureProvider = FutureProvider<void>((ref) {
  final region = ref.watch(regionProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(regionReadinessProvider).ensure(region);
});

/// Sync status of the selected region, read once [regionEnsureProvider] is
/// done (a failed ensure still shows the cached status). Reloads on region
/// change and after a manual sync.
final regionSyncStatusProvider =
    FutureProvider.autoDispose<RegionSyncStatus?>((ref) async {
  final region = ref.watch(regionProvider);
  ref.watch(dataRevisionProvider);
  try {
    await ref.watch(regionEnsureProvider.future);
  } catch (_) {
    // Logged by RegionReadiness; the status below says what is cached.
  }
  return ref.watch(regionSyncServiceProvider).getRegionSyncStatus(region);
});

/// Manual sync of the selected region (`forceSync` in `index.vue`). Shared
/// by the home sidebar, the home page controls and the settings page so all
/// of them show the same busy state. The state is `true` while a sync runs.
class RegionSyncController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Syncs the selected region; returns the error, or `null` on success (or
  /// when a sync is already running).
  Future<Object?> sync() async {
    if (state) {
      return null;
    }
    state = true;
    final region = ref.read(regionProvider);
    try {
      await ref
          .read(regionSyncServiceProvider)
          .syncRegion(region)
          .drain<void>();
      ref.read(dataRevisionProvider.notifier).state++;
      return null;
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('manual region sync failed', error, stackTrace);
      return error;
    } finally {
      state = false;
    }
  }
}

final regionSyncControllerProvider =
    NotifierProvider<RegionSyncController, bool>(RegionSyncController.new);

/// Runs [RegionSyncController.sync] and shows its error as a toast.
Future<void> runRegionSync(BuildContext context, WidgetRef ref) async {
  final error = await ref.read(regionSyncControllerProvider.notifier).sync();
  if (error != null && context.mounted) {
    showNexusMessage(context, '$error', type: NexusMessageType.error);
  }
}
