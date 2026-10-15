import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/sync_status.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/nexus_ui.dart' show NexusMessageType, showNexusMessage;

/// Sync status of the selected region (Vue `index.vue` loads it next to the
/// featured operators). Reloads on region change and after a manual sync.
final regionSyncStatusProvider =
    FutureProvider.autoDispose<RegionSyncStatus?>((ref) {
  final region = ref.watch(regionProvider);
  ref.watch(dataRevisionProvider);
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
