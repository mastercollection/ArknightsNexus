import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/domain/account_profile.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/repositories/json_user_data_repository.dart';
import 'package:arknight_nexus/services/account/account_sync_parser.dart';
import 'package:arknight_nexus/services/account/yostar_account_client.dart';
import 'package:arknight_nexus/services/user_data_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_directories.dart';

/// A trimmed `account/syncData` response: an E2 operator with a mastery
/// and a module, an E0 one, and Amiya with two class templates.
Map<String, Object?> _syncData() => {
      'result': 0,
      'user': {
        'status': {
          'uid': '12345678',
          'nickName': 'Doctor',
          'nickNumber': '0042',
          'level': 120,
          'registerTs': 1694908800,
          'ap': 100,
          'maxAp': 135,
          'lastApAddTime': 1760000000,
          'gold': 3820000,
          'diamondShard': 28150,
          'androidDiamond': 35,
          'iosDiamond': 35,
        },
        'inventory': {'30012': 120, '30013': 0, '2004': 50},
        'troop': {
          'chars': {
            '1': {
              'charId': 'char_017_huang',
              'level': 90,
              'evolvePhase': 2,
              'potentialRank': 5,
              'mainSkillLvl': 7,
              'skills': [
                {'skillId': 'a', 'specializeLevel': 3},
                {'skillId': 'b', 'specializeLevel': 0},
              ],
              'equip': {
                'uniequip_001_huang': {'level': 1, 'locked': 0},
                'uniequip_002_huang': {'level': 2, 'locked': 0},
                'uniequip_003_huang': {'level': 1, 'locked': 1},
              },
            },
            '2': {
              'charId': 'char_285_medic2',
              'level': 30,
              'evolvePhase': 0,
              'potentialRank': 0,
              'mainSkillLvl': 1,
              'skills': <Object?>[],
            },
            '3': {
              'charId': 'char_002_amiya',
              'level': 50,
              'evolvePhase': 1,
              'potentialRank': 2,
              'mainSkillLvl': 4,
              'tmpl': {
                'char_002_amiya': {
                  'skills': [
                    {'skillId': 'x', 'specializeLevel': 0},
                  ],
                  'equip': <String, Object?>{},
                },
                'char_1001_amiya2': {
                  'skills': [
                    {'skillId': 'y', 'specializeLevel': 0},
                  ],
                  'equip': <String, Object?>{},
                },
              },
            },
          },
        },
      },
    };

void main() {
  group('parseAccountSync', () {
    final sync = parseAccountSync(
      _syncData(),
      region: 'kr',
      syncedAt: DateTime(2026, 10, 17),
    );

    test('reads the profile and currencies', () {
      final profile = sync.profile;
      expect(profile.nickName, 'Doctor');
      expect(profile.nickNumber, '0042');
      expect(profile.level, 120);
      expect(profile.gold, 3820000);
      expect(profile.originium, 35);
      expect(sync.itemCounts, {
        '30012': 120,
        '2004': 50,
        '4001': 3820000,
        '4003': 28150,
        '4002': 35,
      });
    });

    test('maps training to plan terms', () {
      final huang = sync.profile.operator('char_017_huang')!;
      expect(huang.elite, 2);
      expect(huang.potential, 5);
      expect(huang.skillLevels, [10, 7]);
      expect(huang.maxMastery, 3);
      // The basic branch and locked modules are left out.
      expect(huang.modules, {'uniequip_002_huang': 2});
    });

    test('lists each Amiya template as its own operator', () {
      expect(sync.profile.operator('char_002_amiya')?.skillLevels, [4]);
      expect(sync.profile.operator('char_1001_amiya2')?.elite, 1);
      expect(sync.profile.operators, hasLength(4));
    });

    test('survives a JSON round trip', () {
      final json = jsonDecode(jsonEncode(sync.profile.toJson()));
      final restored = AccountProfile.fromJson(json as Map<String, Object?>);
      expect(restored.toJson(), sync.profile.toJson());
    });
  });

  group('applyAccountOperator', () {
    const plan = UserPlanOperator(
      operatorId: 'char_017_huang',
      current: UserPlanOperatorState(
        elite: 0,
        level: 1,
        skillLevels: [1, 1, 1],
        modules: [
          UserPlanModule(
            moduleId: 'uniequip_002_huang',
            currentStage: 0,
            targetStage: 3,
          ),
        ],
      ),
      target: UserPlanOperatorState(
        elite: 2,
        level: 60,
        skillLevels: [8, 7, 7],
        modules: [
          UserPlanModule(
            moduleId: 'uniequip_002_huang',
            currentStage: 0,
            targetStage: 3,
          ),
        ],
      ),
    );

    test('takes the current state and raises the target to it', () {
      const owned = AccountOperator(
        operatorId: 'char_017_huang',
        elite: 2,
        level: 90,
        skillLevels: [10, 7, 7],
        modules: {'uniequip_002_huang': 2},
      );
      final applied = applyAccountOperator(plan, owned);
      expect(applied.current.elite, 2);
      expect(applied.current.level, 90);
      expect(applied.current.skillLevels, [10, 7, 7]);
      expect(applied.current.modules.single.currentStage, 2);
      expect(applied.target.level, 90);
      expect(applied.target.skillLevels, [10, 7, 7]);
      expect(applied.target.modules.single.targetStage, 3);
    });

    test('keeps a target that is still ahead', () {
      const owned = AccountOperator(
        operatorId: 'char_017_huang',
        elite: 1,
        level: 40,
        skillLevels: [5, 5],
      );
      final applied = applyAccountOperator(plan, owned);
      expect(applied.target.elite, 2);
      expect(applied.target.level, 60);
      expect(applied.current.skillLevels, [5, 5, 5]);
      expect(applied.target.skillLevels, [8, 7, 7]);
    });
  });

  group('UserDataService.saveAccount', () {
    late Directory tempRoot;
    late JsonUserDataRepository repository;
    late UserDataService service;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('nexus-account-test-');
      repository = JsonUserDataRepository(FakeAppDirectories(tempRoot));
      service = UserDataService(repository);
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('replaces item counts, updates owned plans and keeps the rest',
        () async {
      await repository.write(
        const UserData(
          favorites: ['char_017_huang'],
          itemCounts: {'30012': 3, '30061': 9},
          operatorPlans: [
            UserPlanOperator(
              operatorId: 'char_017_huang',
              current: UserPlanOperatorState(elite: 0, level: 1),
              target: UserPlanOperatorState(elite: 2, level: 90),
            ),
            UserPlanOperator(
              operatorId: 'char_9999_unowned',
              current: UserPlanOperatorState(elite: 0, level: 1),
              target: UserPlanOperatorState(elite: 1, level: 50),
            ),
          ],
        ),
      );
      final sync = parseAccountSync(
        _syncData(),
        region: 'kr',
        syncedAt: DateTime(2026, 10, 17),
      );

      final result = await service.saveAccount(sync.profile, sync.itemCounts);

      expect(result.updatedPlans, 1);
      final data = await repository.read();
      expect(data.schemaVersion, UserData.schemaVersionValue);
      expect(data.itemCounts.containsKey('30061'), isFalse);
      expect(data.itemCounts['30012'], 120);
      expect(data.favorites, ['char_017_huang']);
      expect(data.operatorPlans.first.current.elite, 2);
      expect(data.operatorPlans.last.current.elite, 0);
      expect((await service.getAccount())?.uid, '12345678');

      // Exported user data carries the account through a re-import.
      await service.importUserData(await service.exportUserData());
      expect((await service.getAccount())?.operators, hasLength(4));

      await service.clearAccount();
      expect(await service.getAccount(), isNull);
      expect((await repository.read()).itemCounts['30012'], 120);
    });
  });

  group('YostarAccountClient signing', () {
    final client = YostarAccountClient(
      YostarServer.kr,
      deviceIds: const YostarDeviceIds('device', '860000000000000', 'device3'),
      now: () => DateTime.fromMillisecondsSinceEpoch(1760000000000),
    );

    test('signs the SDK head with the body', () {
      const body = '{"Account":"a@b.c"}';
      final header =
          jsonDecode(client.sdkAuthorization(body)) as Map<String, Object?>;
      final head = header['Head'] as Map<String, Object?>;
      expect(head['PID'], 'KR-ARKNIGHTS');
      expect(head['Lang'], 'ko');
      expect(head['Time'], 1760000000);
      final expected = md5
          .convert(
            utf8.encode(
              '${jsonEncode(head)}$body'
              '886c085e4a8d30a703367b120dd8353948405ec2',
            ),
          )
          .toString()
          .toUpperCase();
      expect(header['Sign'], expected);
    });

    test('signs u8 bodies over the sorted form encoding', () {
      final sign = YostarAccountClient.u8Sign({'b': 2, 'a': 'x y'});
      final expected = Hmac(
        sha1,
        utf8.encode('91240f70c09a08a6bc72af1a5c8d4670'),
      ).convert(utf8.encode('a=x+y&b=2')).toString();
      expect(sign, expected);
    });
  });
}
