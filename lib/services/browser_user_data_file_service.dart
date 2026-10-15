import 'dart:convert';
import 'dart:js_interop';

import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

import 'user_data_file_service.dart';

/// [UserDataFileService] of the web build. Export hands the JSON to the
/// browser as a download (there is no save dialog with a writable path);
/// import uses the browser's file picker and reads the picked file's bytes.
class BrowserUserDataFileService implements UserDataFileService {
  const BrowserUserDataFileService();

  @override
  Future<bool> saveJson(
    String content, {
    String fileName = 'user_data.json',
  }) async {
    final blob = web.Blob(
      <web.BlobPart>[content.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    // The download has started once click() returns, but some browsers read
    // the object URL asynchronously; release it a little later.
    Future<void>.delayed(
      const Duration(seconds: 30),
      () => web.URL.revokeObjectURL(url),
    );
    return true;
  }

  @override
  Future<String?> openJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final bytes = result?.files.singleOrNull?.bytes;
    return bytes == null ? null : utf8.decode(bytes);
  }
}
