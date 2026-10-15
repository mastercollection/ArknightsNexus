import 'package:web/web.dart' as web;

import 'key_value_store.dart';

/// [KeyValueStore] backed by `window.localStorage`, which keeps its content
/// across visits until the user clears the site's data.
class LocalStorageKeyValueStore implements KeyValueStore {
  const LocalStorageKeyValueStore();

  @override
  String? read(String key) => web.window.localStorage.getItem(key);

  @override
  void write(String key, String value) {
    web.window.localStorage.setItem(key, value);
  }
}
