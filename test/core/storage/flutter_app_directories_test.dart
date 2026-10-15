import 'package:arknight_nexus/core/storage/app_directories.dart';
import 'package:arknight_nexus/core/storage/flutter_app_directories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlutterAppDirectories', () {
    test('implements app directory boundary', () {
      expect(FlutterAppDirectories(), isA<AppDirectories>());
    });
  });
}
