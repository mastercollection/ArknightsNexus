import 'dart:io';

import 'package:arknight_nexus/data_sources/data_version.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/building_formula.dart';
import 'package:arknight_nexus/domain/item.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/domain/region_snapshot.dart';
import 'package:arknight_nexus/repositories/json_region_cache_repository.dart';
import 'package:arknight_nexus/repositories/json_user_data_repository.dart';
import 'package:arknight_nexus/services/item_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_directories.dart';

void main() {
  group('CachedItemService', () {
    late Directory tempRoot;
    late CachedItemService service;
    late JsonUserDataRepository userDataRepository;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('item-service-test-');
      final cache = JsonRegionCacheRepository(FakeAppDirectories(tempRoot));
      await cache.writeSnapshot(_snapshot());
      userDataRepository = JsonUserDataRepository(FakeAppDirectories(tempRoot));
      service = CachedItemService(
        cache,
        userDataRepository: userDataRepository,
      );
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('filters items by classify type and search', () async {
      expect(
        await service.listItems(
          const ItemQuery(region: RegionCode.kr, classifyType: 'material'),
        ),
        hasLength(1),
      );
      expect(
        await service.listItems(
          const ItemQuery(region: RegionCode.kr, search: 'oriron'),
        ),
        hasLength(1),
      );
      expect(
        await service
            .listItems(const ItemQuery(region: RegionCode.kr, search: 'chip')),
        isEmpty,
      );
    });

    test('hides character tokens and vouchers but keeps LMD for materials',
        () async {
      final cache = JsonRegionCacheRepository(FakeAppDirectories(tempRoot));
      final base = _snapshot();
      await cache.writeSnapshot(
        RegionSnapshot(
          schemaVersionValue: RegionSnapshot.schemaVersion,
          region: RegionCode.kr,
          sourceRevision: 'etag',
          sourceVersion: const DataVersion(versionControl: '68.2.0'),
          fetchedAt: DateTime.utc(2026, 5, 17),
          items: [
            ...base.items,
            for (final (id, type) in const [
              ('4001', 'GOLD'),
              ('p_char_002_amiya', 'MATERIAL'),
              ('voucher_full_1', 'MATERIAL'),
            ])
              ItemEntry(
                itemId: id,
                name: id,
                description: '',
                rarity: '1',
                iconId: id,
                sortId: 1,
                usage: '',
                obtainApproach: '',
                classifyType: 'NONE',
                itemType: type,
              ),
          ],
        ),
      );

      final materials = await service.listItems(
        const ItemQuery(region: RegionCode.kr, classifyType: 'MATERIAL'),
      );
      expect(materials.map((item) => item.itemId), ['30012', '4001']);

      final all =
          await service.listItems(const ItemQuery(region: RegionCode.kr));
      expect(all.map((item) => item.itemId), ['30012', '4001']);
    });

    test('loads building formulas from snapshot', () async {
      final formulas = await service.listBuildingFormulas(RegionCode.kr);

      expect(formulas.manufactFormulas.single.itemId, '30012');
    });

    test('attaches owned item counts from user data', () async {
      await userDataRepository.write(
        const UserData(itemCounts: {'30012': 11}),
      );

      final items =
          await service.listItems(const ItemQuery(region: RegionCode.kr));

      expect(items.single.ownedCount, 11);
    });
  });
}

RegionSnapshot _snapshot() {
  return RegionSnapshot(
    schemaVersionValue: RegionSnapshot.schemaVersion,
    region: RegionCode.kr,
    sourceRevision: 'etag',
    sourceVersion: const DataVersion(versionControl: '68.2.0'),
    fetchedAt: DateTime.utc(2026, 5, 17),
    items: const [
      ItemEntry(
        itemId: '30012',
        name: 'Oriron',
        description: 'Material',
        rarity: '3',
        iconId: 'MTL_SL_Orirock',
        sortId: 10,
        usage: 'Upgrade',
        obtainApproach: 'Stage',
        classifyType: 'MATERIAL',
        itemType: 'MATERIAL',
      ),
    ],
    buildingFormulas: const BuildingFormulaBundle(
      manufactFormulas: [
        ManufacturingFormula(
          formulaId: 'manufact_1',
          itemId: '30012',
          count: 1,
          weight: 100,
          costPoint: 60,
          formulaType: 'NORMAL',
          buffType: 'NONE',
        ),
      ],
    ),
  );
}
