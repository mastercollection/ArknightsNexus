import 'dart:convert';
import 'dart:io';

import '../core/errors/app_failure.dart';
import '../core/storage/app_directories.dart';
import '../domain/user_data.dart';
import 'user_data_repository.dart';

class JsonUserDataRepository implements UserDataRepository {
  const JsonUserDataRepository(
    this._directories, {
    Future<List<File>> Function()? legacyUserDataFiles,
  }) : _legacyUserDataFiles = legacyUserDataFiles;

  final AppDirectories _directories;

  /// `user_data.json` locations of the Tauri app (same schema). The first one
  /// that exists is copied over once, so existing users keep their data.
  final Future<List<File>> Function()? _legacyUserDataFiles;

  @override
  Future<UserData> read() async {
    final file = await _userDataFile();
    if (!await file.exists() && !await _importLegacy(file)) {
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
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      const encoder = JsonEncoder.withIndent('  ');
      await temp.writeAsString(encoder.convert(data.toJson()));
      if (await file.exists()) {
        await file.delete();
      }
      await temp.rename(file.path);
    } catch (error) {
      throw CacheFailure('Failed to write ${file.path}: $error');
    }
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
