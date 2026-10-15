import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/raw_models/gamedata_const.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RawGameDataConst.termDescriptions', () {
    test('extracts trimmed term descriptions and drops blank ones', () async {
      final constants =
          RawGameDataConst.fromJson(await _fixture('gamedata_const.json'));

      expect(constants.termDescriptions(), {
        'atk': 'Attack',
        'ba.stun': 'Cannot act',
        'ba.sluggish': 'Movement speed reduced',
      });
    });
  });
}

Future<Map<String, Object?>> _fixture(String name) async {
  final content = await File('test/support/fixtures/raw/$name').readAsString();
  return jsonDecode(content) as Map<String, Object?>;
}
