import 'dart:convert';

import 'package:arknight_nexus/core/errors/app_failure.dart';
import 'package:arknight_nexus/core/storage/key_value_store.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/repositories/key_value_user_data_repository.dart';
import 'package:arknight_nexus/services/user_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _dataKey = KeyValueUserDataRepository.dataKey;
const _backupKey = KeyValueUserDataRepository.backupKey;

void main() {
  group('KeyValueUserDataRepository', () {
    late MemoryKeyValueStore store;
    late KeyValueUserDataRepository repository;

    setUp(() {
      store = MemoryKeyValueStore();
      repository = KeyValueUserDataRepository(store);
    });

    test('returns the default data when nothing is stored', () async {
      final data = await repository.read();

      expect(data.schemaVersion, UserData.schemaVersionValue);
      expect(data.favorites, isEmpty);
      expect(data.operatorPlans, isEmpty);
      expect(data.itemCounts, isEmpty);
    });

    test('stores the same user_data.json document as the file repository',
        () async {
      await repository.write(
        const UserData(favorites: ['char_002_amiya'], itemCounts: {'30012': 5}),
      );

      final json = jsonDecode(store.values[_dataKey]!) as Map<String, Object?>;
      expect(json['schemaVersion'], UserData.schemaVersionValue);
      expect(json['favorites'], ['char_002_amiya']);
      expect(json['itemCounts'], {'30012': 5});

      final read = await repository.read();
      expect(read.favorites, ['char_002_amiya']);
      expect(read.itemCounts, {'30012': 5});
    });

    test('reads what another tab stored in the meantime', () async {
      await repository.read();
      store.values[_dataKey] = jsonEncode(
        const UserData(favorites: ['char_003_kalts']).toJson(),
      );

      expect((await repository.read()).favorites, ['char_003_kalts']);
    });

    test('backup keeps the previous document', () async {
      await repository.backup();
      expect(store.values.containsKey(_backupKey), isFalse);

      await repository.write(const UserData(favorites: ['a']));
      await repository.backup();
      await repository.write(const UserData(favorites: ['b']));

      final backup =
          jsonDecode(store.values[_backupKey]!) as Map<String, Object?>;
      expect(backup['favorites'], ['a']);
      expect((await repository.read()).favorites, ['b']);
    });

    test('unreadable stored data is a CacheFailure', () async {
      store.values[_dataKey] = '{not json';

      await expectLater(repository.read(), throwsA(isA<CacheFailure>()));
    });

    test('a refused write (full quota) is a CacheFailure', () async {
      final refusing = KeyValueUserDataRepository(_RefusingStore());

      await expectLater(
        refusing.write(const UserData(favorites: ['a'])),
        throwsA(isA<CacheFailure>()),
      );
    });

    test('works behind UserDataService, including import and export', () async {
      final service = UserDataService(repository);

      await Future.wait([
        service.toggleOperatorFavorite('char_002_amiya'),
        service.saveUserItemCount('30012', 7),
        service.saveUserPlanSelection(['char_002_amiya']),
      ]);

      final exported = await service.exportUserData();
      final fresh = UserDataService(
        KeyValueUserDataRepository(MemoryKeyValueStore()),
      );
      await fresh.importUserData(exported);

      expect(await fresh.getFavorites(), ['char_002_amiya']);
      expect(
        (await fresh.getUserPlan()).selectedOperatorIds,
        ['char_002_amiya'],
      );
      final stored = await repository.read();
      expect(stored.itemCounts, {'30012': 7});
    });
  });
}

class _RefusingStore implements KeyValueStore {
  @override
  String? read(String key) => null;

  @override
  void write(String key, String value) {
    throw StateError('QuotaExceededError');
  }
}
