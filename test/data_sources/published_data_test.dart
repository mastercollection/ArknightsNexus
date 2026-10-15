import 'package:arknight_nexus/core/errors/app_failure.dart';
import 'package:arknight_nexus/data_sources/published_data.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> manifestJson({Object? formatVersion = 1}) => {
        'formatVersion': formatVersion,
        'generatedAt': '2026-10-15T00:00:00.000Z',
        'fingerprint': 'abc',
        'regions': {
          'kr': {
            'schemaVersion': 2,
            'versionControl': '52.0.0',
            'sourceRevision': '"etag"',
            'fetchedAt': '2026-10-14T23:59:00.000Z',
            'operatorCount': 3,
            'files': {
              'snapshot': {
                'path': 'v2/kr/snapshot.json',
                'sha256': 'ABCDEF',
                'bytes': 10,
              },
            },
          },
          'xx': {'ignored': true},
        },
      };

  test('parses a manifest and skips regions this app does not know', () {
    final manifest = PublishedManifest.fromJson(manifestJson());

    expect(manifest.fingerprint, 'abc');
    expect(manifest.regions.keys, [RegionCode.kr]);
    final kr = manifest.regions[RegionCode.kr]!;
    expect(kr.schemaVersion, 2);
    expect(kr.versionControl, '52.0.0');
    expect(kr.operatorCount, 3);
    expect(kr.fetchedAt, DateTime.utc(2026, 10, 14, 23, 59));
    expect(kr.snapshot.path, 'v2/kr/snapshot.json');
    expect(kr.snapshot.sha256, 'abcdef');
    expect(kr.snapshot.bytes, 10);
  });

  test('round-trips through JSON', () {
    final manifest = PublishedManifest.fromJson(manifestJson());
    final again = PublishedManifest.fromJson(manifest.toJson());

    expect(again.toJson(), manifest.toJson());
  });

  test('rejects an unsupported format version', () {
    expect(
      () => PublishedManifest.fromJson(manifestJson(formatVersion: 2)),
      throwsA(isA<ParseFailure>()),
    );
  });

  test('rejects file paths that leave the data directory', () {
    for (final path in ['../x.json', '/v2/kr/snapshot.json', 'https://x/y']) {
      expect(
        () => PublishedFile.fromJson({'path': path, 'sha256': '', 'bytes': 0}),
        throwsA(isA<ParseFailure>()),
        reason: path,
      );
    }
  });

  test('resolves files relative to the base URL', () {
    final withSlash = Uri.parse('https://example.test/site/data/');
    final withoutSlash = Uri.parse('https://example.test/site/data');

    for (final base in [withSlash, withoutSlash]) {
      expect(
        PublishedData.manifestUri(base).toString(),
        'https://example.test/site/data/manifest.json',
      );
      expect(
        PublishedData.fileUri(base, 'v2/kr/snapshot.json').toString(),
        'https://example.test/site/data/v2/kr/snapshot.json',
      );
    }
    expect(
      PublishedData.snapshotPath(2, RegionCode.en),
      'v2/en/snapshot.json',
    );
  });
}
