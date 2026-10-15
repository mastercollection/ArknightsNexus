import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/raw_models/building_data.dart';
import 'package:arknight_nexus/services/normalizers/building_formula_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BuildingFormulaNormalizer', () {
    test('normalizes manufacturing and workshop formulas', () async {
      final raw =
          RawBuildingData.fromJson(await _fixture('building_data.json'));
      final bundle = const BuildingFormulaNormalizer().normalize(raw);

      expect(bundle.manufactFormulas.single.itemId, '30012');
      expect(bundle.manufactFormulas.single.costs.single.type, 'GOLD');
      expect(
        bundle.workshopFormulas.single.extraOutcomeGroup.single.itemId,
        '30012',
      );
    });

    test('sorts like Rust normalize_building_data', () {
      Map<String, Object?> manufact(String formulaId, String itemId) => {
            'formulaId': formulaId,
            'itemId': itemId,
            'count': 1,
            'weight': 1,
            'costPoint': 1,
            'formulaType': 'F',
            'buffType': 'B',
          };
      Map<String, Object?> workshop(
        String formulaId,
        String itemId,
        int sortId,
      ) =>
          {
            'sortId': sortId,
            'formulaId': formulaId,
            'rarity': 1,
            'itemId': itemId,
            'count': 1,
            'goldCost': 1,
            'apCost': 1,
            'formulaType': 'F',
            'buffType': 'B',
            'extraOutcomeRate': 0,
          };

      final raw = RawBuildingData.fromJson({
        'manufactFormulas': {
          'a': manufact('1', '3003'),
          'b': manufact('3', '2001'),
          'c': manufact('2', '2001'),
        },
        'workshopFormulas': {
          'a': workshop('9', 'b', 2),
          'b': workshop('8', 'b', 1),
          'c': workshop('7', 'a', 1),
          'd': workshop('6', 'a', 1),
        },
      });
      final bundle = const BuildingFormulaNormalizer().normalize(raw);

      // manufact: itemId, then formulaId.
      expect(bundle.manufactFormulas.map((f) => f.formulaId), ['2', '3', '1']);
      // workshop: sortId, then itemId, then formulaId.
      expect(
        bundle.workshopFormulas.map((f) => f.formulaId),
        ['6', '7', '8', '9'],
      );
    });
  });
}

Future<Map<String, Object?>> _fixture(String name) async {
  final content = await File('test/support/fixtures/raw/$name').readAsString();
  return jsonDecode(content) as Map<String, Object?>;
}
