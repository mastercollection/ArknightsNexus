import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Tauri bundle identifier from `src-tauri/tauri.conf.json`.
const tauriIdentifier = 'com.nexus.arknights';

/// Where the Tauri app kept `user/user_data.json` (its `app_data_dir`).
Future<List<File>> legacyTauriUserDataFiles() async {
  final candidates = <String>[];
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      candidates.add(p.join(appData, tauriIdentifier));
    }
  } else if (Platform.isAndroid) {
    // Same application id, so after an in-place update the Tauri data dir
    // is this app's data dir (the parent of Flutter's `files` dir).
    final support = await getApplicationSupportDirectory();
    candidates
      ..add(support.parent.path)
      ..add(p.join(support.parent.path, 'files'));
  }
  return [
    for (final base in candidates) File(p.join(base, 'user', 'user_data.json')),
  ];
}
