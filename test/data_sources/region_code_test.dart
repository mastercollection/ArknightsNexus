import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegionCode', () {
    test('parses supported region codes', () {
      expect(RegionCode.parse('cn'), RegionCode.cn);
      expect(RegionCode.parse('kr'), RegionCode.kr);
      expect(RegionCode.parse('jp'), RegionCode.jp);
      expect(RegionCode.parse('tw'), RegionCode.tw);
      expect(RegionCode.parse('en'), RegionCode.en);
    });

    test('rejects unsupported region codes', () {
      expect(
        () => RegionCode.parse('global'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
