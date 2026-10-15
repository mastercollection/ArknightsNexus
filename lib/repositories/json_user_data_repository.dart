import 'dart:convert';
import 'dart:io';

import '../core/errors/app_failure.dart';
import '../core/storage/app_directories.dart';
import '../core/storage/atomic_file.dart';
import '../domain/user_data.dart';
import 'user_data_repository.dart';

/// `user/user_data.json` with an in-memory copy: the file is parsed once and
/// every successful [write] replaces the copy, so the app does not re-read
/// the file for each operation. This repository must be the only writer of
/// the file while the app runs.
class JsonUserDataRepository implements UserDataRepository {
  JsonUserDataRepository(
    this._directories, {
    Future<List<File>> Function()? legacyUserDataFiles,
  }) : _legacyUserDataFiles = legacyUserDataFiles;

  final AppDirectories _directories;

  /// `user_data.json` locations of the Tauri app (same schema). The first one
  /// that exists is copied over once, so existing users keep their data.
  final Future<List<File>> Function()? _legacyUserDataFiles;

  UserData? _current;
  Future<UserData>? _loading;

  @override
  Future<UserData> read() async {
    final current = _current;
    if (current != null) {
      return current;
    }
    final loading = _loading ??= _load();
    try {
      final data = await loading;
      // A write that finished meanwhile is newer than what was loaded.
      return _current ??= data;
    } finally {
      if (identical(_loading, loading)) {
        _loading = null;
      }
    }
  }

  Future<UserData> _load() async {
    final file = await _userDataFile();
    // A crashed fallback write may have left only `user_data.json.prev`;
    // restoring it keeps the legacy import below from overwriting real data.
    if (!await recoverAtomicFile(file) && !await _importLegacy(file)) {
      return const UserData();
    }

    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      return UserData.fromJson(json);
    } catch (error) {
      throw CacheFailure('Failed to read ${file.path}: $error');
    }
  }

  @override
  Future<void> write(UserData data) async {
    final file = await _userDataFile();
    try {
      const encoder = JsonEncoder.withIndent('  ');
      await writeFileAtomically(file, encoder.convert(data.toJson()));
    } catch (error) {
      throw CacheFailure('Failed to write ${file.path}: $error');
    }
    _current = data;
  }

  @override
  Future<void> backup() async {
    final file = await _userDataFile();
    if (!await file.exists()) {
      return;
    }
    final backup = File('${file.path}.bak');
    try {
      await backup.parent.create(recursive: true);
      await file.copy(backup.path);
    } catch (error) {
      throw CacheFailure('Failed to back up ${file.path}: $error');
    }
  }

  Future<bool> _importLegacy(File target) async {
    final candidates = await _legacyUserDataFiles?.call() ?? const <File>[];
    for (final legacy in candidates) {
      if (legacy.path == target.path || !await legacy.exists()) {
        continue;
      }
      try {
        await target.parent.create(recursive: true);
        await legacy.copy(target.path);
        return true;
      } catch (_) {
        // Unreadable legacy data: start fresh rather than failing reads.
      }
    }
    return false;
  }

  Future<File> _userDataFile() async {
    final root = await _directories.userDataRoot();
    return File.fromUri(root.uri.resolve('user/user_data.json'));
  }
}
