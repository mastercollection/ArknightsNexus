import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/raw_models/building_data.dart';
import 'package:arknight_nexus/raw_models/item_table.dart';
import 'package:arknight_nexus/raw_models/stage_table.dart';
import 'package:arknight_nexus/services/normalizers/item_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ItemNormalizer', () {
    test('normalizes items with stage code mapping and building products',
        () async {
      final items = RawItemTable.fromJson(await _fixture('item_table.json'));
      final stages = RawStageTable.fromJson(await _fixture('stage_table.json'));
      final building =
          RawBuildingData.fromJson(await _fixture('building_data.json'));
      final normalizer = const ItemNormalizer();

      final normalized = normalizer.normalize(items, stages, building);

      // Rust order: sortId, then name, then itemId.
      expect(normalized.map((item) => item.itemId), [
        'mod_unlock_token',
        '30012',
      ]);
      final oriron = normalized[1];
      expect(oriron.rarity, 'TIER_3');
      expect(oriron.stageDropList.single.stageCode, '1-7');
      expect(oriron.buildingProductList.single.formulaId, 'workshop_1');

      final token = normalized[0];
      // Rust `RawStringLikeValue::as_string` for numeric rarity/itemType.
      expect(token.rarity, '4');
      expect(token.itemType, '7');
      expect(token.description, '');
      expect(token.usage, '');
      expect(token.obtainApproach, '');
      expect(token.stageDropList, isEmpty);
      expect(token.buildingProductList, isEmpty);
    });

    test('stage code map trims ids/codes and drops blank entries', () async {
      final stages = RawStageTable.fromJson(await _fixture('stage_table.json'));

      expect(const ItemNormalizer().stageCodeMap(stages), {
        'main_01-07': '1-7',
      });
    });
  });
}

Future<Map<String, Object?>> _fixture(String name) async {
  final content = await File('test/support/fixtures/raw/$name').readAsString();
  return jsonDecode(content) as Map<String, Object?>;
}
