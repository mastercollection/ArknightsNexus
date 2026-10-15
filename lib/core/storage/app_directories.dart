import 'dart:io';

abstract interface class AppDirectories {
  Future<Directory> cacheRoot();

  Future<Directory> userDataRoot();

  Future<Directory> logRoot();
}
