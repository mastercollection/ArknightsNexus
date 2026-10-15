import 'dart:convert';

import '../core/errors/app_failure.dart';
import '../core/storage/key_value_store.dart';
import '../domain/user_data.dart';
import 'user_data_repository.dart';

/// User data as the same `user_data.json` document, stored under one key of
/// a [KeyValueStore] (the browser's `localStorage` on the web build).
///
/// Every [read] parses the stored text again instead of keeping a copy: it
/// is a few kilobytes, and another browser tab of the app may have written
/// it in the meantime. [UserDataService] serializes the writes of this tab.
class KeyValueUserDataRepository implements UserDataRepository {
  KeyValueUserDataRepository(this._store);

  static const dataKey = 'arknights_nexus.user_data';

  /// Where [backup] keeps the previous document before an import.
  static const backupKey = 'arknights_nexus.user_data.bak';

  final KeyValueStore _store;

  @override
  Future<UserData> read() async {
    final String? raw;
    try {
      raw = _store.read(dataKey);
    } catch (error) {
      throw CacheFailure('Failed to read the stored user data: $error');
    }
    if (raw == null) {
      return const UserData();
    }
    try {
      return UserData.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (error) {
      throw CacheFailure('Failed to read the stored user data: $error');
    }
  }

  @override
  Future<void> write(UserData data) async {
    const encoder = JsonEncoder.withIndent('  ');
    try {
      _store.write(dataKey, encoder.convert(data.toJson()));
    } catch (error) {
      throw CacheFailure('Failed to store the user data: $error');
    }
  }

  @override
  Future<void> backup() async {
    try {
      final raw = _store.read(dataKey);
      if (raw != null) {
        _store.write(backupKey, raw);
      }
    } catch (error) {
      throw CacheFailure('Failed to back up the stored user data: $error');
    }
  }
}
