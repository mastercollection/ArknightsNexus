import 'dart:convert';

import '../core/concurrency/background.dart';
import '../core/http/http_client.dart';
import '../data_sources/arknights_data_source.dart';
import '../data_sources/data_version.dart';
import '../data_sources/region_code.dart';
import '../domain/operator.dart';
import '../domain/region_snapshot.dart';
import '../domain/sync_status.dart';
import '../raw_models/battle_equip.dart';
import '../raw_models/building_data.dart';
import '../raw_models/character.dart';
import '../raw_models/favor_table.dart';
import '../raw_models/gamedata_const.dart';
import '../raw_models/handbook_info.dart';
import '../raw_models/handbook_team.dart';
import '../raw_models/item_table.dart';
import '../raw_models/range_table.dart';
import '../raw_models/skill.dart';
import '../raw_models/stage_table.dart';
import '../raw_models/uniequip.dart';
import 'normalizers/building_formula_normalizer.dart';
import 'normalizers/item_normalizer.dart';
import 'normalizers/operator_normalizer.dart';

/// Fetches a region's raw upstream tables and normalizes them into a
/// [RegionSnapshot], without touching any cache.
///
/// Shared by the app's raw sync path and `tool/build_snapshots.dart`, which
/// publishes the same snapshots on GitHub Pages; this file and its imports
/// must stay free of Flutter so the tool runs on the plain Dart VM.
class RegionSource {
  const RegionSource({
    required NexusHttpClient httpClient,
    ItemNormalizer itemNormalizer = const ItemNormalizer(),
    BuildingFormulaNormalizer buildingFormulaNormalizer =
        const BuildingFormulaNormalizer(),
    OperatorNormalizer operatorNormalizer = const OperatorNormalizer(),
  })  : _httpClient = httpClient,
        _itemNormalizer = itemNormalizer,
        _buildingFormulaNormalizer = buildingFormulaNormalizer,
        _operatorNormalizer = operatorNormalizer;

  final NexusHttpClient _httpClient;
  final ItemNormalizer _itemNormalizer;
  final BuildingFormulaNormalizer _buildingFormulaNormalizer;
  final OperatorNormalizer _operatorNormalizer;

  Future<DataVersion> fetchDataVersion(RegionCode region) async {
    final body = await _httpClient.getText(region.descriptor.dataVersionUri);
    return DataVersion.parse(body);
  }

  /// Downloads every required table, a few at a time.
  Future<DownloadedTables> downloadTables(RegionCode region) async {
    final descriptor = region.descriptor;
    final bodies = <String, String>{};
    final revisions = <String, String>{};
    final pending = List.of(ArknightsDataSource.requiredTableFiles);

    Future<void> worker() async {
      while (pending.isNotEmpty) {
        final file = pending.removeAt(0);
        final HttpTextResponse response;
        try {
          response =
              await _httpClient.getTextWithRevision(descriptor.tableUri(file));
        } catch (_) {
          // The sync fails anyway; do not start the remaining downloads.
          pending.clear();
          rethrow;
        }
        bodies[file] = response.body;
        final revision = response.revision;
        if (revision != null) {
          revisions[file] = revision;
        }
      }
    }

    await Future.wait(
      [for (var i = 0; i < _maxConcurrentDownloads; i++) worker()],
    );
    return DownloadedTables(bodies: bodies, revisions: revisions);
  }

  /// Decodes and normalizes on a background isolate: the tables are about
  /// 80 MB of JSON, which would otherwise freeze the UI for seconds.
  Future<NormalizedRegion> normalizeInBackground(
    RegionCode region,
    DataVersion version,
    DownloadedTables downloaded,
  ) {
    return _runNormalizeJob(
      _NormalizeJob(
        region: region,
        version: version,
        downloaded: downloaded,
        normalizers: _Normalizers(
          item: _itemNormalizer,
          buildingFormula: _buildingFormulaNormalizer,
          operator: _operatorNormalizer,
        ),
      ),
    );
  }

  /// [fetchDataVersion], [downloadTables] and [normalizeInBackground] in one.
  Future<NormalizedRegion> fetchNormalized(RegionCode region) async {
    final version = await fetchDataVersion(region);
    final downloaded = await downloadTables(region);
    return normalizeInBackground(region, version, downloaded);
  }
}

const _maxConcurrentDownloads = 4;

class DownloadedTables {
  const DownloadedTables({required this.bodies, required this.revisions});

  /// Response body per table file.
  final Map<String, String> bodies;

  /// Response revision per table file.
  final Map<String, String> revisions;
}

/// A region snapshot plus the cache files derived from it.
class NormalizedRegion {
  const NormalizedRegion({
    required this.snapshot,
    required this.summary,
    required this.status,
    required this.terms,
    required this.result,
  });

  /// Derives the summary, status, terms and sync result from [snapshot].
  /// Both the raw path and the published-snapshot path use this, so the
  /// cache looks the same whichever way the snapshot arrived.
  factory NormalizedRegion.fromSnapshot(RegionSnapshot snapshot) {
    final fetchedAt = snapshot.fetchedAt.toIso8601String();
    final versionControl = snapshot.sourceVersion.versionControl;
    return NormalizedRegion(
      snapshot: snapshot,
      summary: RegionSummarySnapshot(
        schemaVersionValue: snapshot.schemaVersionValue,
        region: snapshot.region,
        sourceRevision: snapshot.sourceRevision,
        sourceVersion: snapshot.sourceVersion,
        fetchedAt: snapshot.fetchedAt,
        operators: snapshot.operators.map(_summary).toList(),
      ),
      status: RegionSyncStatus(
        region: snapshot.region,
        sourceRevision: snapshot.sourceRevision,
        sourceVersion: versionControl,
        fetchedAt: fetchedAt,
        operatorCount: snapshot.operators.length,
        isReady: true,
      ),
      terms: snapshot.terms,
      result: SyncResult(
        region: snapshot.region,
        sourceRevision: snapshot.sourceRevision,
        sourceVersion: versionControl,
        updatedAt: fetchedAt,
        operatorCount: snapshot.operators.length,
        status: 'success',
      ),
    );
  }

  final RegionSnapshot snapshot;
  final RegionSummarySnapshot summary;
  final RegionSyncStatus status;
  final Map<String, String> terms;
  final SyncResult result;
}

/// Everything the background isolate needs; all of it is plain data.
class _NormalizeJob {
  const _NormalizeJob({
    required this.region,
    required this.version,
    required this.downloaded,
    required this.normalizers,
  });

  final RegionCode region;
  final DataVersion version;
  final DownloadedTables downloaded;
  final _Normalizers normalizers;
}

class _Normalizers {
  const _Normalizers({
    required this.item,
    required this.buildingFormula,
    required this.operator,
  });

  final ItemNormalizer item;
  final BuildingFormulaNormalizer buildingFormula;
  final OperatorNormalizer operator;
}

// Top-level so the closure handed to [runInBackground] captures only the job,
// not the source and its HTTP client.
Future<NormalizedRegion> _runNormalizeJob(_NormalizeJob job) =>
    runInBackground(() => _decodeAndNormalize(job));

NormalizedRegion _decodeAndNormalize(_NormalizeJob job) {
  final raw = _RawTables.decode(job.downloaded);
  return _normalize(job.region, job.version, raw, job.normalizers);
}

NormalizedRegion _normalize(
  RegionCode region,
  DataVersion version,
  _RawTables raw,
  _Normalizers normalizers,
) {
  final stageCodes = normalizers.item.stageCodeMap(raw.stages);
  final buildingFormulas = normalizers.buildingFormula.normalize(raw.building);
  final items = normalizers.item.normalize(
    raw.items,
    raw.stages,
    raw.building,
    stageCodes: stageCodes,
  );
  final terms = raw.constants.termDescriptions();
  final operators = normalizers.operator.normalize(
    region: region,
    characters: raw.characters,
    skills: raw.skills,
    constants: raw.constants,
    ranges: raw.ranges,
    uniequip: raw.uniequip,
    battleEquip: raw.battleEquip,
    favor: raw.favor,
    items: raw.items,
    handbook: raw.handbook,
    handbookInfo: raw.handbookInfo,
  );

  return NormalizedRegion.fromSnapshot(
    RegionSnapshot(
      schemaVersionValue: RegionSnapshot.schemaVersion,
      region: region,
      sourceRevision: _sourceRevision(region, raw.revisions),
      sourceVersion: version,
      fetchedAt: DateTime.now().toUtc(),
      stageCodeMap: stageCodes,
      terms: terms,
      items: items,
      buildingFormulas: buildingFormulas,
      operators: operators,
    ),
  );
}

OperatorSummary _summary(OperatorDetail detail) {
  return OperatorSummary(
    id: detail.id,
    name: detail.name,
    rarity: detail.rarity,
    profession: detail.profession,
    branch: detail.branch,
    teams: detail.teams,
    nations: detail.nations,
    groups: detail.groups,
    baTags: detail.baTags,
    thumbnailHue: detail.thumbnailHue,
    releaseOrder: detail.releaseOrder,
  );
}

/// Rust `sync_region_data`: table revisions joined in this order (game data
/// constants are not part of it), or the branch when none were reported.
final _revisionTableOrder = [
  for (final file in ArknightsDataSource.requiredTableFiles)
    if (file != ArknightsDataSource.gamedataConstFile) file,
];

String _sourceRevision(RegionCode region, Map<String, String> revisions) {
  final joined = [
    for (final file in _revisionTableOrder)
      if (revisions[file] != null) revisions[file]!,
  ].join(' | ');
  return joined.isEmpty ? region.descriptor.branch : joined;
}

class _RawTables {
  const _RawTables({
    required this.revisions,
    required this.characters,
    required this.skills,
    required this.constants,
    required this.uniequip,
    required this.handbook,
    required this.ranges,
    required this.items,
    required this.stages,
    required this.building,
    required this.battleEquip,
    required this.favor,
    required this.handbookInfo,
  });

  factory _RawTables.decode(DownloadedTables downloaded) {
    Map<String, Object?> table(String file) =>
        jsonDecode(downloaded.bodies[file]!) as Map<String, Object?>;

    return _RawTables(
      revisions: downloaded.revisions,
      characters: RawCharacterTable.fromJson(
        table(ArknightsDataSource.characterTableFile),
      ),
      skills: RawSkillTable.fromJson(table(ArknightsDataSource.skillTableFile)),
      constants: RawGameDataConst.fromJson(
        table(ArknightsDataSource.gamedataConstFile),
      ),
      uniequip: RawUniequipTable.fromJson(
        table(ArknightsDataSource.uniequipTableFile),
      ),
      handbook: RawHandbookTeamTable.fromJson(
        table(ArknightsDataSource.handbookTeamTableFile),
      ),
      ranges: RawRangeTable.fromJson(table(ArknightsDataSource.rangeTableFile)),
      items: RawItemTable.fromJson(table(ArknightsDataSource.itemTableFile)),
      stages: RawStageTable.fromJson(table(ArknightsDataSource.stageTableFile)),
      building: RawBuildingData.fromJson(
        table(ArknightsDataSource.buildingDataFile),
      ),
      battleEquip: RawBattleEquipTable.fromJson(
        table(ArknightsDataSource.battleEquipTableFile),
      ),
      favor: RawFavorTable.fromJson(table(ArknightsDataSource.favorTableFile)),
      handbookInfo: RawHandbookInfoTable.fromJson(
        table(ArknightsDataSource.handbookInfoTableFile),
      ),
    );
  }

  /// Response revision per table file.
  final Map<String, String> revisions;
  final RawCharacterTable characters;
  final RawSkillTable skills;
  final RawGameDataConst constants;
  final RawUniequipTable uniequip;
  final RawHandbookTeamTable handbook;
  final RawRangeTable ranges;
  final RawItemTable items;
  final RawStageTable stages;
  final RawBuildingData building;
  final RawBattleEquipTable battleEquip;
  final RawFavorTable favor;
  final RawHandbookInfoTable handbookInfo;
}
