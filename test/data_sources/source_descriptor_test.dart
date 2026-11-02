import 'package:arknight_nexus/data_sources/arknights_data_source.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceDescriptor', () {
    test('builds data version URLs for every supported region', () {
      for (final region in RegionCode.values) {
        expect(
          region.descriptor.dataVersionUri.toString(),
          'https://raw.githubusercontent.com/'
          'ArknightsAssets/ArknightsGamedata/'
          'refs/heads/master/${region.value}/gamedata/excel/data_version.txt',
        );
      }
    });

    test('builds table URLs for every required source file', () {
      final descriptor = RegionCode.kr.descriptor;

      for (final fileName in ArknightsDataSource.requiredTableFiles) {
        final folder = fileName == ArknightsDataSource.enemyDatabaseFile
            ? 'levels/enemydata'
            : 'excel';
        expect(
          descriptor.tableUri(fileName).toString(),
          'https://raw.githubusercontent.com/'
          'ArknightsAssets/ArknightsGamedata/'
          'refs/heads/master/kr/gamedata/$folder/$fileName',
        );
      }
    });

    test('builds level file URLs from level ids', () {
      expect(
        RegionCode.kr.descriptor
            .levelUri('Obt/Main/level_main_01-07')
            .toString(),
        'https://raw.githubusercontent.com/'
        'ArknightsAssets/ArknightsGamedata/'
        'refs/heads/master/kr/gamedata/levels/obt/main/level_main_01-07.json',
      );
    });

    test('uses the current upstream repository and branch', () {
      final descriptor = RegionCode.en.descriptor;

      expect(
        descriptor.repositoryUri.toString(),
        'https://github.com/ArknightsAssets/ArknightsGamedata',
      );
      expect(descriptor.branch, 'master');
    });
  });
}
