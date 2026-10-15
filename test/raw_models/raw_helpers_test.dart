import 'package:arknight_nexus/raw_models/character.dart';
import 'package:arknight_nexus/raw_models/raw_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('raw_helpers tolerate upstream type quirks', () {
    test('rawMap treats an empty array as an empty map', () {
      // Upstream serializes empty maps as `[]`.
      expect(rawMap(const []), isEmpty);
      expect(rawMap(null), isEmpty);
      expect(rawMap({'a': 1}), {'a': 1});
    });

    test('rawListOf treats an empty object as an empty list', () {
      // Upstream serializes empty arrays as `{}`.
      expect(rawListOf(const {}, (json) => json), isEmpty);
      expect(rawListOf(null, (json) => json), isEmpty);
      final parsed = rawListOf(
        [
          {'k': 'v'},
        ],
        (json) => json['k'],
      );
      expect(parsed, ['v']);
    });

    test('rawStringList treats a non-list as empty', () {
      expect(rawStringList(const {}), isEmpty);
      expect(rawStringList(['a', 'b']), ['a', 'b']);
    });

    test('rawInt/rawDouble accept numbers and numeric strings', () {
      expect(rawInt({'n': 5}, 'n'), 5);
      expect(rawInt({'n': '7'}, 'n'), 7);
      expect(rawInt({'n': 'x'}, 'n', defaultValue: -1), -1);
      expect(rawInt(const {}, 'missing'), 0);
      expect(rawDouble({'n': 1.5}, 'n'), 1.5);
      expect(rawDouble({'n': '2.5'}, 'n'), 2.5);
    });

    test('rawEnumInt strips TIER_/PHASE_ prefixes', () {
      expect(rawEnumInt({'r': 'TIER_5'}, 'r', prefix: 'TIER_'), 5);
      expect(rawEnumInt({'r': 6}, 'r', prefix: 'TIER_'), 6);
      expect(rawEnumInt({'p': 'PHASE_2'}, 'p', prefix: 'PHASE_'), 2);
      expect(rawEnumInt(const {}, 'p', prefix: 'PHASE_'), 0);
    });
  });

  group('RawCharacterEntry parses modern data shapes', () {
    test('parses TIER rarity and empty-object skills/phases', () {
      final entry = RawCharacterEntry.fromJson(const {
        'name': 'Test',
        'profession': 'CASTER',
        'subProfessionId': 'core',
        'rarity': 'TIER_6',
        'position': 'RANGED',
        'tagList': <String>[],
        // Empty list serialized as empty object.
        'phases': <String, Object?>{},
        'skills': <String, Object?>{},
      });

      expect(entry.rarity, 6);
      expect(entry.phases, isEmpty);
      expect(entry.skills, isEmpty);
    });
  });
}
