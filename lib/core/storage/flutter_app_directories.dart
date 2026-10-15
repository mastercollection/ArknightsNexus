import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_directories.dart';

class FlutterAppDirectories implements AppDirectories {
  @override
  Future<Directory> cacheRoot() async {
    return _ensure(await getApplicationCacheDirectory());
  }

  @override
  Future<Directory> userDataRoot() async {
    return _ensure(await getApplicationSupportDirectory());
  }

  @override
  Future<Directory> logRoot() async {
    final supportRoot = await getApplicationSupportDirectory();
    return _ensure(Directory(p.join(supportRoot.path, 'logs')));
  }

  Future<Directory> _ensure(Directory directory) {
    return directory.create(recursive: true);
  }
}
