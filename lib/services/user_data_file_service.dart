/// Save/open dialogs for `user_data.json`, matching the Tauri app's
/// `exportUserDataFile` / `importUserDataFile` (dialog + fs plugins).
abstract interface class UserDataFileService {
  /// Asks for a destination and writes [content]. Returns false when the
  /// user cancels the dialog.
  Future<bool> saveJson(String content, {String fileName = 'user_data.json'});

  /// Asks for a JSON file and returns its text, or null when cancelled.
  Future<String?> openJson();
}
