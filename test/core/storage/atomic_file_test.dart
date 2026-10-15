import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/core/storage/atomic_file.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/repositories/json_user_data_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_directories.dart';

void main() {
  late Directory tempRoot;
  late File target;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('nexus-atomic-test-');
    target = File('${tempRoot.path}/data/file.json');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<List<String>> siblings() async => [
        for (final entity in await target.parent.list().toList())
          entity.uri.pathSegments.last,
      ];

  test('creates and replaces the target without leftovers', () async {
    await writeFileAtomically(target, 'old');
    await writeFileAtomically(target, 'new');

    expect(await target.readAsString(), 'new');
    expect(await siblings(), ['file.json']);
  });

  test('a crash before the rename keeps the old content', () async {
    await writeFileAtomically(target, 'old');

    await expectLater(
      writeFileAtomically(
        target,
        'new',
        hooks: AtomicWriteHooks(
          onStep: (step) async {
            if (step == AtomicWriteStep.tempWritten) {
              throw const FileSystemException('simulated crash');
            }
          },
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(await target.readAsString(), 'old');
  });

  test('a crash in the fallback swap is recovered on the next read', () async {
    await writeFileAtomically(target, 'old');

    // The target looks locked, so the writer falls back to moving the old
    // file aside, and "crashes" right after that.
    await expectLater(
      writeFileAtomically(
        target,
        'new',
        hooks: AtomicWriteHooks(
          rename: (source, newPath) async {
            if (source.path.endsWith('.tmp')) {
              throw FileSystemException('locked', newPath);
            }
            return source.rename(newPath);
          },
          onStep: (step) async {
            if (step == AtomicWriteStep.previousMovedAside) {
              throw const FileSystemException('simulated crash');
            }
          },
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await target.exists(), isFalse);
    expect(await previousFileFor(target).exists(), isTrue);

    expect(await recoverAtomicFile(target), isTrue);
    expect(await target.readAsString(), 'old');
  });

  test('a failed fallback swap puts the old file back', () async {
    await writeFileAtomically(target, 'old');

    await expectLater(
      writeFileAtomically(
        target,
        'new',
        hooks: AtomicWriteHooks(
          rename: (source, newPath) async {
            if (source.path.endsWith('.tmp')) {
              throw FileSystemException('locked', newPath);
            }
            return source.rename(newPath);
          },
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(await target.readAsString(), 'old');
    expect(await siblings(), ['file.json']);
  });

  test('concurrent writers use separate temp files', () async {
    await Future.wait([
      for (var i = 0; i < 20; i++) writeFileAtomically(target, '{"n":$i}'),
    ]);

    final value = jsonDecode(await target.readAsString()) as Map;
    expect(value['n'], inInclusiveRange(0, 19));
    expect(await siblings(), ['file.json']);
  });

  group('JsonUserDataRepository', () {
    test(
        'restores user data a crashed write left aside instead of '
        'starting empty or re-importing legacy data', () async {
      final legacy = File('${tempRoot.path}/tauri/user/user_data.json');
      await legacy.parent.create(recursive: true);
      await legacy.writeAsString(
        jsonEncode(const UserData(favorites: ['legacy']).toJson()),
      );
      Future<List<File>> legacyFiles() async => [legacy];

      final directories = FakeAppDirectories(tempRoot);
      await JsonUserDataRepository(
        directories,
        legacyUserDataFiles: legacyFiles,
      ).write(const UserData(favorites: ['char_002_amiya']));

      // State after a crash between "old file moved aside" and "new file in
      // place".
      final file = File.fromUri(
        tempRoot.uri.resolve('user-data/user/user_data.json'),
      );
      await file.rename(previousFileFor(file).path);

      final restarted = JsonUserDataRepository(
        directories,
        legacyUserDataFiles: legacyFiles,
      );
      expect((await restarted.read()).favorites, ['char_002_amiya']);
      expect(await file.exists(), isTrue);
    });
  });
}
