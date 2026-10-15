import 'package:arknight_nexus/core/errors/app_failure.dart';
import 'package:arknight_nexus/data_sources/data_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataVersion', () {
    test('parses normal payload', () {
      final parsed = DataVersion.parse(
        'Stream://torappu-data/v068/rel68.0\n'
        'Change:100033 on 2025/12/09\n'
        'VersionControl:68.2.0\n',
      );

      expect(parsed.stream, '//torappu-data/v068/rel68.0');
      expect(parsed.changeValue, '100033');
      expect(parsed.changeDate, '2025/12/09');
      expect(parsed.versionControl, '68.2.0');
    });

    test('parses BOM and extra whitespace', () {
      final parsed = DataVersion.parse(
        '\uFEFF  Stream:  //torappu-data/v068/rel68.0  \n'
        '  Change:  100033   on   2025/12/09  \n'
        '  VersionControl:  68.2.0  \n',
      );

      expect(parsed.stream, '//torappu-data/v068/rel68.0');
      expect(parsed.changeValue, '100033');
      expect(parsed.changeDate, '2025/12/09');
      expect(parsed.versionControl, '68.2.0');
    });

    test('accepts empty optional stream and change fields', () {
      final parsed = DataVersion.parse(
        'Stream:\n'
        'Change:\n'
        'VersionControl:49.0.0\n',
      );

      expect(parsed.stream, isNull);
      expect(parsed.changeValue, isNull);
      expect(parsed.changeDate, isNull);
      expect(parsed.versionControl, '49.0.0');
    });

    test('rejects missing VersionControl', () {
      expect(
        () => DataVersion.parse('Stream:abc\nChange:\n'),
        throwsA(isA<ParseFailure>()),
      );
    });

    test('rejects empty VersionControl', () {
      expect(
        () => DataVersion.parse('VersionControl:   \n'),
        throwsA(isA<ParseFailure>()),
      );
    });

    test('rejects malformed non-empty Change', () {
      expect(
        () => DataVersion.parse(
          'Change:100033 2025/12/09\n'
          'VersionControl:68.2.0\n',
        ),
        throwsA(isA<ParseFailure>()),
      );
    });

    test('round trips through JSON', () {
      const version = DataVersion(
        stream: '//torappu-data/v068/rel68.0',
        changeValue: '100033',
        changeDate: '2025/12/09',
        versionControl: '68.2.0',
      );

      final decoded = DataVersion.fromJson(version.toJson());

      expect(decoded.stream, version.stream);
      expect(decoded.changeValue, version.changeValue);
      expect(decoded.changeDate, version.changeDate);
      expect(decoded.versionControl, version.versionControl);
    });
  });
}
