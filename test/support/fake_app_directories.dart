import 'dart:io';

import 'package:arknight_nexus/core/storage/app_directories.dart';

class FakeAppDirectories implements AppDirectories {
  FakeAppDirectories(this.root);

  final Directory root;

  @override
  Future<Directory> cacheRoot() => _createChild('cache');

  @override
  Future<Directory> userDataRoot() => _createChild('user-data');

  @override
  Future<Directory> logRoot() => _createChild('logs');

  Future<Directory> _createChild(String name) {
    return Directory.fromUri(root.uri.resolve('$name/'))
        .create(recursive: true);
  }
}
