import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/data_sources/arknights_data_source.dart';
import 'package:arknight_nexus/data_sources/published_data.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/building_formula.dart';
import 'package:arknight_nexus/domain/region_snapshot.dart';
import 'package:arknight_nexus/services/plan_cost_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/region_labels.dart';
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
    await registerRawFixtures(http, RegionCode.en);
    await registerRawFixtures(http, RegionCode.cn);
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<SnapshotBuildResult> build(
    String name, {
    String? fingerprint,
    List<RegionCode> regions = const [RegionCode.kr],
  }) {
    return SnapshotBuilder(
      httpClient: http,
      outDir: Directory('${tempRoot.path}/$name'),
      fingerprint: fingerprint,
      log: (_) {},
    ).build(regions: regions, previousManifestUri: _previousManifest);
  }

  Future<RegionSnapshot> readSnapshot(String name, RegionCode region) async {
    final file = File(
      '${tempRoot.path}/$name/'
      '${PublishedData.snapshotPath(RegionSnapshot.schemaVersion, region)}',
    );
    return RegionSnapshot.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, Object?>,
    );
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

  bool requestedTables([RegionCode region = RegionCode.kr]) =>
      http.requestedUris.contains(
        region.descriptor.tableUri(ArknightsDataSource.characterTableFile),
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

  group('unreleased operators', () {
    setUp(() async {
      // A (older) is out on EN and CN, B (newer) only on CN; KR has neither.
      await registerRawFixtures(
        http,
        RegionCode.cn,
        extraOperators: const [
          ExtraOperator(
            id: 'char_900_a',
            name: 'A-CN',
            itemId: '39001',
            itemName: 'Stone-CN',
          ),
          ExtraOperator(
            id: 'char_901_b',
            name: 'B-CN',
            itemId: '39002',
            itemName: 'Gem-CN',
          ),
        ],
      );
      await registerRawFixtures(
        http,
        RegionCode.en,
        extraOperators: const [
          ExtraOperator(
            id: 'char_900_a',
            name: 'A-EN',
            itemId: '39001',
            itemName: 'Stone-EN',
          ),
        ],
      );
    });

    test('are added from EN before CN, newest first', () async {
      final result = await build(
        'first',
        regions: [RegionCode.cn, RegionCode.kr, RegionCode.en],
      );
      expect(result.hasFailures, isFalse);

      final kr = await readSnapshot('first', RegionCode.kr);
      expect(
        kr.operators.map((o) => '${o.name}:${o.unreleasedSource}'),
        [
          'B-CN:cn',
          'A-EN:en',
          'Bravo:null',
          'Amiya:null',
          'Alpha:null',
        ],
      );
      expect(kr.unreleasedSourceVersions, {'en': '68.2.0', 'cn': '68.2.0'});
      expect(
        result.manifest.regions[RegionCode.kr]!.unreleasedSourceVersions,
        {'en': '68.2.0', 'cn': '68.2.0'},
      );

      // EN borrows only from CN; CN has nothing to borrow.
      final en = await readSnapshot('first', RegionCode.en);
      expect(
        en.operators.map((o) => '${o.name}:${o.unreleasedSource}').take(2),
        ['B-CN:cn', 'A-EN:null'],
      );
      expect(en.unreleasedSourceVersions, {'cn': '68.2.0'});
      final cn = await readSnapshot('first', RegionCode.cn);
      expect(cn.operators.where((o) => o.isUnreleased), isEmpty);
      expect(cn.unreleasedSourceVersions, isEmpty);
      expect(
        [for (final report in result.regions) report.unreleasedCounts],
        [
          <String, int>{},
          {'cn': 1, 'en': 1},
          {'cn': 1},
        ],
      );
    });

    test('bring the items and terms they need', () async {
      await build('first', regions: [RegionCode.kr]);
      final kr = await readSnapshot('first', RegionCode.kr);

      final items = {for (final item in kr.items) item.itemId: item};
      expect(items['39001']!.name, 'Stone-EN');
      expect(items['39001']!.unreleasedSource, 'en');
      expect(items['39002']!.name, 'Gem-CN');
      expect(items['39002']!.unreleasedSource, 'cn');
      for (final id in ['39001', '39002']) {
        expect(items[id]!.stageDropList, isEmpty);
        expect(items[id]!.buildingProductList, isEmpty);
      }
      expect(items['30012']!.unreleasedSource, isNull);
      expect(items['30012']!.stageDropList, isNotEmpty);

      // The trait's term and the term that one links, from the source.
      expect(kr.terms['ba.char_900_a'], 'Like <\$ba.char_900_a.more>more</>');
      expect(kr.terms['ba.char_900_a.more'], 'Even more');
      expect(kr.terms['ba.char_901_b.more'], 'Even more');

      // Plan costs of a borrowed operator resolve the borrowed item.
      const costs = DartPlanCostService();
      final operator = kr.operators.firstWhere((o) => o.id == 'char_900_a');
      final plan = costs.createDefaultPlanOperator(operator);
      final breakdown = costs.calculatePlanCostsWithItems(
        operator,
        plan,
        items,
      );
      expect(breakdown.valid, isTrue);
      final expanded = costs.expandPlanMaterials(
        breakdown.materials,
        const BuildingFormulaBundle(),
        items,
      );
      expect(
        expanded.where((m) => m.id == '39001').map((m) => m.name),
        ['Stone-EN'],
      );
    });

    test("cost their items under the region's names", () async {
      // CN calls the fixture material 30012 differently.
      await registerRawFixtures(
        http,
        RegionCode.cn,
        extraOperators: const [
          ExtraOperator(
            id: 'char_902_c',
            name: 'C-CN',
            itemId: '30012',
            itemName: 'Oriron-CN',
          ),
        ],
      );
      await build('first', regions: [RegionCode.kr]);
      final kr = await readSnapshot('first', RegionCode.kr);

      final operator = kr.operators.first;
      expect(operator.name, 'C-CN');
      final cost = operator.eliteEvolveCosts.expand((costs) => costs).single;
      expect(cost.id, '30012');
      expect(cost.itemName, 'Oriron');
      expect(
        kr.items.where((item) => item.itemId == '30012').single.name,
        'Oriron',
      );
    });

    test("carry the region's names for factions, branches and tags", () async {
      // The same fixtures in three "languages"; B's nation is new on CN.
      await registerRawFixtures(
        http,
        RegionCode.cn,
        labelSuffix: ' (CN)',
        extraOperators: const [
          ExtraOperator(id: 'char_900_a', name: 'A-CN'),
          ExtraOperator(id: 'char_901_b', name: 'B-CN', newFaction: true),
        ],
      );
      await registerRawFixtures(
        http,
        RegionCode.en,
        labelSuffix: ' (EN)',
        extraOperators: const [ExtraOperator(id: 'char_900_a', name: 'A-EN')],
      );
      final result = await build(
        'first',
        regions: [RegionCode.cn, RegionCode.kr, RegionCode.en],
      );
      expect(result.hasFailures, isFalse);

      final kr = await readSnapshot('first', RegionCode.kr);
      final operators = {for (final o in kr.operators) o.id: o};
      final amiya = operators['char_002_amiya']!;
      for (final id in ['char_900_a', 'char_901_b']) {
        final borrowed = operators[id]!;
        expect(borrowed.branch, amiya.branch);
        expect(borrowed.teams, amiya.teams);
        expect(borrowed.tags, amiya.tags);
        expect(borrowed.tags, ['DPS', 'Support']);
      }
      expect(operators['char_900_a']!.nations, amiya.nations);
      expect(operators['char_901_b']!.nations, ['B-CN Nation (CN)']);
      // The borrowed operators' own term is unknown to KR; the rest is not.
      expect(operators['char_900_a']!.baTags, ['A-EN (EN)', 'Slow', 'Stun']);
      expect(operators['char_901_b']!.baTags, ['B-CN (CN)', 'Slow', 'Stun']);
      expect(operators['char_900_a']!.name, 'A-EN');

      // EN borrows B from CN, in English.
      final en = await readSnapshot('first', RegionCode.en);
      final b = en.operators.firstWhere((o) => o.id == 'char_901_b');
      expect(b.branch, 'Core Caster (EN)');
      expect(b.teams, ['Rhodes Island (EN)']);
      expect(b.tags, ['DPS (EN)', 'Support (EN)']);

      final stats = result.regions[1].labelStats!;
      // Unknown Nation is a humanized id no table names.
      expect(stats.kept, {
        'baTags: A-EN (EN)': 1,
        'nations: Unknown Nation': 1,
        'baTags: B-CN (CN)': 1,
        'nations: B-CN Nation (CN)': 1,
      });
      expect(result.regions[0].labelStats, isNull);
    });

    test('regenerate a region when a source changed', () async {
      await build('first', fingerprint: 'f1');
      await serveAsPrevious('first');
      await registerRawFixtures(
        http,
        RegionCode.en,
        versionControl: '68.9.0',
      );
      http.requestedUris.clear();

      final second = await build('second', fingerprint: 'f1');

      expect(second.regions.single.outcome, RegionBuildOutcome.generated);
      final entry = second.manifest.regions[RegionCode.kr]!;
      expect(entry.versionControl, '68.2.0');
      expect(entry.unreleasedSourceVersions, {'en': '68.9.0', 'cn': '68.2.0'});
      // A from CN now: the new EN data does not have it.
      final kr = await readSnapshot('second', RegionCode.kr);
      expect(
        kr.operators.where((o) => o.isUnreleased).map((o) => o.name),
        ['B-CN', 'A-CN'],
      );
    });

    test('read unchanged sources from the previous site', () async {
      await build(
        'first',
        fingerprint: 'f1',
        regions: [RegionCode.cn, RegionCode.kr, RegionCode.en],
      );
      await serveAsPrevious('first');
      http
        ..registerText(
          RegionCode.kr.descriptor.dataVersionUri,
          'VersionControl:68.3.0\n',
        )
        ..requestedUris.clear();

      final second = await build('second', fingerprint: 'f1');

      expect(second.regions.single.outcome, RegionBuildOutcome.generated);
      expect(requestedTables(RegionCode.kr), isTrue);
      expect(requestedTables(RegionCode.en), isFalse);
      expect(requestedTables(RegionCode.cn), isFalse);
      // Of the sources, only the tables naming the labels.
      for (final source in [RegionCode.en, RegionCode.cn]) {
        expect(
          http.requestedUris.where(
            (uri) =>
                uri.path.contains('/${source.value}/gamedata/excel/') &&
                uri.path.endsWith('.json'),
          ),
          unorderedEquals([
            for (final file in RegionLabels.tableFiles)
              source.descriptor.tableUri(file),
          ]),
        );
      }
      final kr = await readSnapshot('second', RegionCode.kr);
      expect(
        kr.operators
            .where((o) => o.isUnreleased)
            .map((o) => '${o.name}:${o.unreleasedSource}'),
        ['B-CN:cn', 'A-EN:en'],
      );
    });
  });
}
