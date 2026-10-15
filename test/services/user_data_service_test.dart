import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/core/errors/app_failure.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/repositories/json_user_data_repository.dart';
import 'package:arknight_nexus/repositories/user_data_repository.dart';
import 'package:arknight_nexus/services/user_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_directories.dart';

void main() {
  group('UserDataService', () {
    late Directory tempRoot;
    late JsonUserDataRepository repository;
    late UserDataService service;

    setUp(() async {
      tempRoot =
          await Directory.systemTemp.createTemp('nexus-user-service-test-');
      repository = JsonUserDataRepository(FakeAppDirectories(tempRoot));
      service = UserDataService(repository);
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('toggles favorites with trim, sort, and dedup behavior', () async {
      await repository.write(
        const UserData(favorites: [' char_003_kalts ', '', 'char_002_amiya']),
      );

      expect(
        await service.getFavorites(),
        ['char_002_amiya', 'char_003_kalts'],
      );
      expect(await service.toggleOperatorFavorite(' char_001_doctor '), isTrue);
      expect(await service.getFavorites(), [
        'char_001_doctor',
        'char_002_amiya',
        'char_003_kalts',
      ]);
      expect(await service.toggleOperatorFavorite('char_002_amiya'), isFalse);
      expect(
        await service.getFavorites(),
        ['char_001_doctor', 'char_003_kalts'],
      );
    });

    test('saves plan selection and removes stale operator plans', () async {
      await service.saveUserPlanOperator(_plan('char_002_amiya'));
      await service.saveUserPlanOperator(_plan('char_003_kalts'));

      final selected =
          await service.saveUserPlanSelection([' char_003_kalts ', '']);
      final plan = await service.getUserPlan();

      expect(selected, ['char_003_kalts']);
      expect(plan.selectedOperatorIds, ['char_003_kalts']);
      expect(plan.operators.single.operatorId, 'char_003_kalts');
    });

    test('saves operator plan with default skill levels and selection append',
        () async {
      final saved = await service.saveUserPlanOperator(
        _plan(
          ' char_002_amiya ',
          current: const UserPlanOperatorState(elite: 0, level: 1),
          target: const UserPlanOperatorState(
            elite: 2,
            level: 90,
            skillLevels: [7, 10, 10],
            modules: [
              UserPlanModule(
                moduleId: 'uniequip_002_amiya',
                currentStage: 0,
                targetStage: 3,
              ),
            ],
          ),
        ),
      );

      final plan = await service.getUserPlan();

      expect(saved.operatorId, 'char_002_amiya');
      expect(saved.current.skillLevels, [1, 1, 1]);
      expect(saved.target.modules.single.targetStage, 3);
      expect(plan.selectedOperatorIds, ['char_002_amiya']);
      expect(plan.operators.single.target.skillLevels, [7, 10, 10]);
    });

    test('rejects invalid plan state values', () async {
      await expectLater(
        service.saveUserPlanOperator(
          _plan(
            'char_002_amiya',
            target: const UserPlanOperatorState(elite: 3, level: 90),
          ),
        ),
        throwsA(isA<InvalidInputFailure>()),
      );
      await expectLater(
        service.saveUserPlanOperator(
          _plan(
            'char_002_amiya',
            target: const UserPlanOperatorState(elite: 2, level: 0),
          ),
        ),
        throwsA(isA<InvalidInputFailure>()),
      );
      await expectLater(
        service.saveUserPlanOperator(
          _plan(
            'char_002_amiya',
            target: const UserPlanOperatorState(
              elite: 2,
              level: 90,
              skillLevels: [11],
            ),
          ),
        ),
        throwsA(isA<InvalidInputFailure>()),
      );
      await expectLater(
        service.saveUserPlanOperator(
          _plan(
            'char_002_amiya',
            target: const UserPlanOperatorState(
              elite: 2,
              level: 90,
              modules: [
                UserPlanModule(
                  moduleId: 'uniequip_002_amiya',
                  currentStage: 0,
                  targetStage: 4,
                ),
              ],
            ),
          ),
        ),
        throwsA(isA<InvalidInputFailure>()),
      );
    });

    test('removes operator plan and selection together', () async {
      await service.saveUserPlanOperator(_plan('char_002_amiya'));

      expect(await service.removeUserPlanOperator('char_002_amiya'), isTrue);
      expect(await service.removeUserPlanOperator('char_002_amiya'), isFalse);
      expect((await service.getUserPlan()).operators, isEmpty);
    });

    test('saves item count and removes zero counts', () async {
      expect(await service.saveUserItemCount(' 30012 ', 4), 4);
      expect((await repository.read()).itemCounts, {'30012': 4});

      expect(await service.saveUserItemCount('30012', 0), 0);
      expect((await repository.read()).itemCounts, isEmpty);

      await expectLater(
        service.saveUserItemCount(' ', 1),
        throwsA(isA<InvalidInputFailure>()),
      );
    });

    test('imports item counts by merging non-zero sanitized entries', () async {
      await service.saveUserItemCount('30012', 1);

      final imported = await service.importUserItemCounts(
        jsonEncode({' 30012 ': 5, '4001': 0, '32001': 2}),
      );

      expect(imported, 2);
      expect((await repository.read()).itemCounts, {'30012': 5, '32001': 2});
      await expectLater(
        service.importUserItemCounts(jsonEncode({'30012': 0})),
        throwsA(isA<InvalidInputFailure>()),
      );
    });

    test('exports and imports normalized user data with backup', () async {
      await repository.write(
        const UserData(
          favorites: [' char_003_kalts ', 'char_002_amiya', 'char_002_amiya'],
          selectedOperatorIds: ['char_002_amiya'],
          operatorPlans: [_rawPlanWithMissingSkillLevels],
          itemCounts: {'': 1, '30012': 0, '32001': 8},
        ),
      );

      final exported = await service.exportUserData();
      final exportedJson = jsonDecode(exported) as Map<String, Object?>;

      expect(exportedJson['schemaVersion'], UserData.schemaVersionValue);
      expect(exportedJson['favorites'], ['char_002_amiya', 'char_003_kalts']);
      expect(exportedJson['itemCounts'], {'32001': 8});

      await service.importUserData(
        jsonEncode({
          'schemaVersion': 1,
          'favorites': [' char_001_doctor '],
          'selectedOperatorIds': ['char_001_doctor'],
          'operatorPlans': [_plan('char_001_doctor').toJson()],
          'itemCounts': {'30012': 6},
        }),
      );

      final imported = await repository.read();
      expect(imported.schemaVersion, UserData.schemaVersionValue);
      expect(imported.favorites, ['char_001_doctor']);
      expect(imported.itemCounts, {'30012': 6});

      final backup = File.fromUri(
        tempRoot.uri.resolve('user-data/user/user_data.json.bak'),
      );
      expect(await backup.exists(), isTrue);
    });

    test('rejects empty and oversized imports', () async {
      await expectLater(
        service.importUserData('   '),
        throwsA(isA<InvalidInputFailure>()),
      );
      await expectLater(
        service.importUserData('x'.padRight(1024 * 1024 + 1, 'x')),
        throwsA(isA<InvalidInputFailure>()),
      );
    });
  });

  group('UserDataService concurrency', () {
    test('overlapping saves keep every update', () async {
      final repository = _SlowMemoryRepository();
      final service = UserDataService(repository);

      await Future.wait<Object?>([
        for (var i = 1; i <= 10; i++) service.saveUserItemCount('item_$i', i),
        service.toggleOperatorFavorite('char_002_amiya'),
        service.saveUserPlanOperator(_plan('char_003_kalts')),
        service.saveUserPlanSelection(['char_003_kalts', 'char_017_huang']),
        service.toggleOperatorFavorite('char_017_huang'),
      ]);

      final stored = repository.data;
      expect(stored.itemCounts, {for (var i = 1; i <= 10; i++) 'item_$i': i});
      expect(stored.favorites, ['char_002_amiya', 'char_017_huang']);
      expect(stored.selectedOperatorIds, ['char_003_kalts', 'char_017_huang']);
      expect(stored.operatorPlans.single.operatorId, 'char_003_kalts');
      expect(repository.maxConcurrentWrites, 1);
    });

    test('a failed save does not block later ones', () async {
      final repository = _SlowMemoryRepository()..failNextWrite = true;
      final service = UserDataService(repository);

      final failing = service.saveUserItemCount('item_1', 1);
      final next = service.saveUserItemCount('item_2', 2);

      await expectLater(failing, throwsA(isA<CacheFailure>()));
      expect(await next, 2);
      expect(repository.data.itemCounts, {'item_2': 2});
    });
  });
}

/// In-memory repository whose reads and writes take a few event-loop turns,
/// so unserialized read-modify-write cycles would interleave.
class _SlowMemoryRepository implements UserDataRepository {
  UserData data = const UserData();
  bool failNextWrite = false;
  int _activeWrites = 0;
  int maxConcurrentWrites = 0;

  @override
  Future<UserData> read() async {
    await Future<void>.delayed(const Duration(milliseconds: 2));
    return data;
  }

  @override
  Future<void> write(UserData value) async {
    _activeWrites++;
    if (_activeWrites > maxConcurrentWrites) {
      maxConcurrentWrites = _activeWrites;
    }
    try {
      await Future<void>.delayed(const Duration(milliseconds: 2));
      if (failNextWrite) {
        failNextWrite = false;
        throw const CacheFailure('disk full');
      }
      data = value;
    } finally {
      _activeWrites--;
    }
  }

  @override
  Future<void> backup() async {}
}

const _rawPlanWithMissingSkillLevels = UserPlanOperator(
  operatorId: 'char_002_amiya',
  current: UserPlanOperatorState(elite: 0, level: 1),
  target: UserPlanOperatorState(elite: 2, level: 90),
);

UserPlanOperator _plan(
  String operatorId, {
  UserPlanOperatorState current =
      const UserPlanOperatorState(elite: 0, level: 1),
  UserPlanOperatorState target =
      const UserPlanOperatorState(elite: 1, level: 50),
}) {
  return UserPlanOperator(
    operatorId: operatorId,
    current: current,
    target: target,
  );
}
