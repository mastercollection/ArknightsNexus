import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Native save/open dialogs for `user_data.json`, matching the Tauri app's
/// `exportUserDataFile` / `importUserDataFile` (dialog + fs plugins).
abstract interface class UserDataFileService {
  /// Asks for a destination and writes [content]. Returns false when the
  /// user cancels the dialog.
  Future<bool> saveJson(String content, {String fileName = 'user_data.json'});

  /// Asks for a JSON file and returns its text, or null when cancelled.
  Future<String?> openJson();
}

class FilePickerUserDataFileService implements UserDataFileService {
  const FilePickerUserDataFileService();

  @override
  Future<bool> saveJson(
    String content, {
    String fileName = 'user_data.json',
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    final destination = await FilePicker.platform.saveFile(
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      // Android/iOS write the bytes themselves; desktop only returns a path.
      bytes: Platform.isAndroid || Platform.isIOS ? bytes : null,
    );
    if (destination == null) {
      return false;
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      final path = destination.toLowerCase().endsWith('.json')
          ? destination
          : '$destination.json';
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return true;
  }

  @override
  Future<String?> openJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) {
      return null;
    }
    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    return bytes == null ? null : utf8.decode(bytes);
  }
}
