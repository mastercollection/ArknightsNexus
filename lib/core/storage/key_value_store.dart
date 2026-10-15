/// Synchronous string storage, the shape of the browser's `localStorage`.
/// The web build keeps user data here; tests use [MemoryKeyValueStore].
abstract interface class KeyValueStore {
  String? read(String key);

  /// Stores [value] under [key]. Throws when the storage refuses the write
  /// (for example a full quota or storage disabled by the browser).
  void write(String key, String value);
}

/// [KeyValueStore] that forgets everything when the app closes.
class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;
}
