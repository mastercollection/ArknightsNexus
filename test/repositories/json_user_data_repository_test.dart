import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/repositories/json_user_data_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_directories.dart';

void main() {
  group('JsonUserDataRepository', () {
    late Directory tempRoot;
    late JsonUserDataRepository repository;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('nexus-user-test-');
      repository = JsonUserDataRepository(FakeAppDirectories(tempRoot));
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('returns schema version 3 default data when file is missing',
        () async {
      final data = await repository.read();

      expect(data.schemaVersion, UserData.schemaVersionValue);
      expect(data.favorites, isEmpty);
      expect(data.selectedOperatorIds, isEmpty);
      expect(data.operatorPlans, isEmpty);
      expect(data.itemCounts, isEmpty);
    });

    test('imports the Tauri user_data.json once when none exists', () async {
      final legacy = File('${tempRoot.path}/tauri/user/user_data.json');
      await legacy.parent.create(recursive: true);
      await legacy.writeAsString(
        jsonEncode({
          'schemaVersion': 3,
          'favorites': ['char_002_amiya'],
          'selectedOperatorIds': [],
          'operatorPlans': [],
          'itemCounts': {'4001': 1200},
        }),
      );
      final migrating = JsonUserDataRepository(
        FakeAppDirectories(tempRoot),
        legacyUserDataFiles: () async => [
          File('${tempRoot.path}/missing/user/user_data.json'),
          legacy,
        ],
      );

      final imported = await migrating.read();
      expect(imported.favorites, ['char_002_amiya']);
      expect(imported.itemCounts, {'4001': 1200});

      // Later edits win; the legacy file is not read again.
      await migrating.write(const UserData(favorites: ['char_003_kalts']));
      expect((await migrating.read()).favorites, ['char_003_kalts']);
    });

    test('writes user data to the same user/user_data.json location', () async {
      const data = UserData(
        favorites: ['char_002_amiya'],
        selectedOperatorIds: ['char_002_amiya'],
        operatorPlans: [
          UserPlanOperator(
            operatorId: 'char_002_amiya',
            current: UserPlanOperatorState(elite: 0, level: 1),
            target: UserPlanOperatorState(elite: 2, level: 90),
          ),
        ],
        itemCounts: {'30012': 4},
      );

      await repository.write(data);

      final file = File.fromUri(
        tempRoot.uri.resolve('user-data/user/user_data.json'),
      );
      expect(await file.exists(), isTrue);
      expect(
        (await repository.read()).operatorPlans.single.operatorId,
        'char_002_amiya',
      );

      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      expect(json['schemaVersion'], UserData.schemaVersionValue);
      expect(json['selectedOperatorIds'], ['char_002_amiya']);
    });

    test('backs up existing user data next to the source file', () async {
      await repository.write(const UserData(favorites: ['char_002_amiya']));

      await repository.backup();

      final backup = File.fromUri(
        tempRoot.uri.resolve('user-data/user/user_data.json.bak'),
      );
      expect(await backup.exists(), isTrue);
      expect(
        UserData.fromJson(
          jsonDecode(await backup.readAsString()) as Map<String, Object?>,
        ).favorites,
        ['char_002_amiya'],
      );
    });

    test('stores item counts independent of cached game data', () async {
      await repository.write(
        const UserData(
          itemCounts: {'30012': 7},
        ),
      );

      final data = await repository.read();

      expect(data.itemCounts, {'30012': 7});
    });
  });
}
