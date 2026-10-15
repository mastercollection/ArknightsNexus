import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/repositories/memory_region_cache_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemoryRegionCacheRepository', () {
    test('starts empty', () async {
      final cache = MemoryRegionCacheRepository();

      expect(await cache.readSnapshot(RegionCode.kr), isNull);
      expect(await cache.readSummary(RegionCode.kr), isNull);
      expect(await cache.readStatus(RegionCode.kr), isNull);
      expect(await cache.readTerms(RegionCode.kr), isEmpty);
    });

    test('keeps terms per region and hands out copies', () async {
      final cache = MemoryRegionCacheRepository();
      final terms = {'ba.a': 'A'};
      await cache.writeTerms(RegionCode.kr, terms);
      terms['ba.b'] = 'B';

      final read = await cache.readTerms(RegionCode.kr);
      read['ba.c'] = 'C';

      expect(await cache.readTerms(RegionCode.kr), {'ba.a': 'A'});
      expect(await cache.readTerms(RegionCode.en), isEmpty);
    });
  });
}
