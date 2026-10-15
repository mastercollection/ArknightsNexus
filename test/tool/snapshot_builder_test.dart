import 'dart:io';

import 'package:arknight_nexus/data_sources/arknights_data_source.dart';
import 'package:arknight_nexus/data_sources/published_data.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/region_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/snapshot_builder.dart';
import '../support/fake_http_client.dart';
import '../support/raw_fixtures.dart';

final _previousBase = Uri.parse('https://pages.test/data/');
final _previousManifest = _previousBase.resolve('manifest.json');

void main() {
  late Directory tempRoot;
  late FakeHttpClient http;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('snapshot-builder-test-');
    http = FakeHttpClient();
    await registerRawFixtures(http, RegionCode.kr);
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<SnapshotBuildResult> build(String name, {String? fingerprint}) {
    return SnapshotBuilder(
      httpClient: http,
      outDir: Directory('${tempRoot.path}/$name'),
      fingerprint: fingerprint,
      log: (_) {},
    ).build(regions: [RegionCode.kr], previousManifestUri: _previousManifest);
  }

  /// Serves the output of [name] as the previously published site.
  Future<void> serveAsPrevious(String name) async {
    final out = Directory('${tempRoot.path}/$name');
    await for (final entity in out.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final relative = entity.uri.path.substring(out.uri.path.length);
      if (relative == PublishedData.manifestFile) {
        http.registerText(
          _previousBase.resolve(relative),
          await entity.readAsString(),
        );
      } else {
        http.registerBytes(
          _previousBase.resolve(relative),
          await entity.readAsBytes(),
        );
      }
    }
  }

  bool requestedTables() => http.requestedUris.contains(
        RegionCode.kr.descriptor.tableUri(
          ArknightsDataSource.characterTableFile,
        ),
      );

  test('generates every region without a previous manifest', () async {
    final result = await build('first', fingerprint: 'f1');

    expect(result.regions.single.outcome, RegionBuildOutcome.generated);
    expect(result.manifest.fingerprint, 'f1');
    final manifest = File('${tempRoot.path}/first/manifest.json');
    expect(await manifest.exists(), isTrue);
    final snapshot = File(
      '${tempRoot.path}/first/'
      '${PublishedData.snapshotPath(RegionSnapshot.schemaVersion, RegionCode.kr)}',
    );
    expect(
      await snapshot.length(),
      result.manifest.regions[RegionCode.kr]!.snapshot.bytes,
    );
  });

  test('copies an unchanged region from the previous site', () async {
    final snapshotPath =
        PublishedData.snapshotPath(RegionSnapshot.schemaVersion, RegionCode.kr);
    final first = await build('first', fingerprint: 'f1');
    await serveAsPrevious('first');
    http.requestedUris.clear();

    final second = await build('second', fingerprint: 'f1');

    expect(second.regions.single.outcome, RegionBuildOutcome.reused);
    expect(requestedTables(), isFalse);
    expect(
      second.manifest.regions[RegionCode.kr]!.toJson(),
      first.manifest.regions[RegionCode.kr]!.toJson(),
    );
    expect(
      await File('${tempRoot.path}/second/$snapshotPath').readAsBytes(),
      await File('${tempRoot.path}/first/$snapshotPath').readAsBytes(),
    );
  });

  test('regenerates when the generator fingerprint changed', () async {
    await build('first', fingerprint: 'f1');
    await serveAsPrevious('first');
    http.requestedUris.clear();

    final second = await build('second', fingerprint: 'f2');

    expect(second.regions.single.outcome, RegionBuildOutcome.generated);
    expect(requestedTables(), isTrue);
  });

  test('regenerates when the upstream version changed', () async {
    await build('first', fingerprint: 'f1');
    await serveAsPrevious('first');
    http.registerText(
      RegionCode.kr.descriptor.dataVersionUri,
      'VersionControl:68.3.0\n',
    );

    final second = await build('second', fingerprint: 'f1');

    expect(second.regions.single.outcome, RegionBuildOutcome.generated);
    expect(second.manifest.regions[RegionCode.kr]!.versionControl, '68.3.0');
  });

  test('keeps the previous copy when generation fails', () async {
    await build('first', fingerprint: 'f1');
    await serveAsPrevious('first');
    http
      ..registerText(
        RegionCode.kr.descriptor.dataVersionUri,
        'VersionControl:68.3.0\n',
      )
      ..registerText(
        RegionCode.kr.descriptor.tableUri(ArknightsDataSource.itemTableFile),
        'not json',
      );

    final second = await build('second', fingerprint: 'f1');

    expect(second.regions.single.outcome, RegionBuildOutcome.keptPrevious);
    expect(second.hasFailures, isFalse);
    expect(second.manifest.regions[RegionCode.kr]!.versionControl, '68.2.0');
  });

  test('reports a failure without a previous copy', () async {
    http.registerText(
      RegionCode.kr.descriptor.tableUri(ArknightsDataSource.itemTableFile),
      'not json',
    );

    final result = await build('first', fingerprint: 'f1');

    expect(result.regions.single.outcome, RegionBuildOutcome.failed);
    expect(result.hasFailures, isTrue);
    expect(result.manifest.regions, isEmpty);
  });
}
