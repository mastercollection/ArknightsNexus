import 'dart:io';

import 'package:arknight_nexus/core/errors/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release Android manifest declares INTERNET like the Tauri app', () {
    // Flutter only adds INTERNET to the debug/profile manifests; without it
    // every sync fails in release builds.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android:label="ArknightsNexus"'));
  });

  test('Android release keeps the Tauri application id and signing env', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();
    expect(gradle, contains('applicationId = "com.nexus.arknights"'));
    for (final name in [
      'ANDROID_KEYSTORE_PATH',
      'ANDROID_KEYSTORE_PASSWORD',
      'ANDROID_KEY_ALIAS',
      'ANDROID_KEY_PASSWORD',
    ]) {
      expect(gradle, contains(name));
    }
  });

  test('failures render their message in error states', () {
    expect(
      '${const NetworkFailure('GET x failed with HTTP 404')}',
      'GET x failed with HTTP 404',
    );
  });
}
