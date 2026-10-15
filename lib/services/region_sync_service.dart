import 'dart:convert';

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
import '../raw_models/handbook_team.dart';
import '../raw_models/item_table.dart';
import '../raw_models/range_table.dart';
import '../raw_models/skill.dart';
import '../raw_models/stage_table.dart';
import '../raw_models/uniequip.dart';
import '../repositories/region_cache_repository.dart';
import 'normalizers/building_formula_normalizer.dart';
import 'normalizers/item_normalizer.dart';
import 'normalizers/operator_normalizer.dart';

abstract interface class RegionSyncService {
  Stream<SyncStatus> syncRegion(RegionCode region);

  Future<SyncResult> ensureRegionFresh(RegionCode region);

  Future<RegionSyncStatus?> getRegionSyncStatus(RegionCode region);

  Future<Map<String, String>> getRegionTerms(RegionCode region);

  Future<Map<String, String>> getRegionStageCodes(RegionCode region);
}

class DartRegionSyncService implements RegionSyncService {
  const DartRegionSyncService({
    required NexusHttpClient httpClient,
    required RegionCacheRepository cache,
    ItemNormalizer itemNormalizer = const ItemNormalizer(),
    BuildingFormulaNormalizer buildingFormulaNormalizer =
        const BuildingFormulaNormalizer(),
    OperatorNormalizer operatorNormalizer = const OperatorNormalizer(),
  })  : _httpClient = httpClient,
        _cache = cache,
        _itemNormalizer = itemNormalizer,
        _buildingFormulaNormalizer = buildingFormulaNormalizer,
        _operatorNormalizer = operatorNormalizer;

  final NexusHttpClient _httpClient;
  final RegionCacheRepository _cache;
  final ItemNormalizer _itemNormalizer;
  final BuildingFormulaNormalizer _buildingFormulaNormalizer;
  final OperatorNormalizer _operatorNormalizer;

  @override
  Stream<SyncStatus> syncRegion(RegionCode region) async* {
    yield SyncStatus(region: region, phase: SyncPhase.checkingVersion);
    final version = await _fetchDataVersion(region);

    yield SyncStatus(
      region: region,
      phase: SyncPhase.downloading,
      remoteVersion: version.versionControl,
    );
    final raw = await _fetchRawTables(region);

    yield SyncStatus(
      region: region,
      phase: SyncPhase.normalizing,
      remoteVersion: version.versionControl,
    );
    final normalized = _normalize(region, version, raw);

    yield SyncStatus(
      region: region,
      phase: SyncPhase.writingSnapshot,
      remoteVersion: version.versionControl,
    );
    await _write(region, normalized);

    yield SyncStatus(
      region: region,
      phase: SyncPhase.complete,
      remoteVersion: version.versionControl,
    );
  }

  @override
  Future<SyncResult> ensureRegionFresh(RegionCode region) async {
    final snapshot = await _cache.readSnapshot(region);
    final remoteVersion = await _fetchDataVersion(region);

    if (snapshot != null &&
        snapshot.sourceVersion.versionControl == remoteVersion.versionControl) {
      return SyncResult(
        region: region,
        sourceRevision: snapshot.sourceRevision,
        sourceVersion: snapshot.sourceVersion.versionControl,
        updatedAt: snapshot.fetchedAt.toIso8601String(),
        operatorCount: snapshot.operators.length,
        status: 'ready',
      );
    }

    final raw = await _fetchRawTables(region);
    final normalized = _normalize(region, remoteVersion, raw);
    await _write(region, normalized);
    return normalized.result;
  }

  @override
  Future<RegionSyncStatus?> getRegionSyncStatus(RegionCode region) {
    return _cache.readStatus(region);
  }

  @override
  Future<Map<String, String>> getRegionTerms(RegionCode region) {
    return _cache.readTerms(region);
  }

  @override
  Future<Map<String, String>> getRegionStageCodes(RegionCode region) async {
    return (await _cache.readSnapshot(region))?.stageCodeMap ?? {};
  }

  Future<DataVersion> _fetchDataVersion(RegionCode region) async {
    final body = await _httpClient.getText(region.descriptor.dataVersionUri);
    return DataVersion.parse(body);
  }

  Future<_RawTables> _fetchRawTables(RegionCode region) async {
    final descriptor = region.descriptor;
    final payloads = <String, Map<String, Object?>>{};
    final revisions = <String, String>{};
    for (final file in ArknightsDataSource.requiredTableFiles) {
      final response =
          await _httpClient.getTextWithRevision(descriptor.tableUri(file));
      payloads[file] = jsonDecode(response.body) as Map<String, Object?>;
      final revision = response.revision;
      if (revision != null) {
        revisions[file] = revision;
      }
    }

    return _RawTables(
      revisions: revisions,
      characters: RawCharacterTable.fromJson(
        payloads[ArknightsDataSource.characterTableFile]!,
      ),
      skills:
          RawSkillTable.fromJson(payloads[ArknightsDataSource.skillTableFile]!),
      constants: RawGameDataConst.fromJson(
        payloads[ArknightsDataSource.gamedataConstFile]!,
      ),
      uniequip: RawUniequipTable.fromJson(
        payloads[ArknightsDataSource.uniequipTableFile]!,
      ),
      handbook: RawHandbookTeamTable.fromJson(
        payloads[ArknightsDataSource.handbookTeamTableFile]!,
      ),
      ranges:
          RawRangeTable.fromJson(payloads[ArknightsDataSource.rangeTableFile]!),
      items:
          RawItemTable.fromJson(payloads[ArknightsDataSource.itemTableFile]!),
      stages:
          RawStageTable.fromJson(payloads[ArknightsDataSource.stageTableFile]!),
      building: RawBuildingData.fromJson(
        payloads[ArknightsDataSource.buildingDataFile]!,
      ),
      battleEquip: RawBattleEquipTable.fromJson(
        payloads[ArknightsDataSource.battleEquipTableFile]!,
      ),
      favor:
          RawFavorTable.fromJson(payloads[ArknightsDataSource.favorTableFile]!),
    );
  }

  _NormalizedRegion _normalize(
    RegionCode region,
    DataVersion version,
    _RawTables raw,
  ) {
    final stageCodes = _itemNormalizer.stageCodeMap(raw.stages);
    final buildingFormulas = _buildingFormulaNormalizer.normalize(raw.building);
    final items =
        _itemNormalizer.normalize(raw.items, raw.stages, raw.building);
    final terms = raw.constants.termDescriptions();
    final operators = _operatorNormalizer.normalize(
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
    );
    final fetchedAt = DateTime.now().toUtc();
    final sourceRevision = _sourceRevision(region, raw.revisions);
    final summaryOperators = operators.map(_summary).toList();

    final snapshot = RegionSnapshot(
      schemaVersionValue: RegionSnapshot.schemaVersion,
      region: region,
      sourceRevision: sourceRevision,
      sourceVersion: version,
      fetchedAt: fetchedAt,
      stageCodeMap: stageCodes,
      terms: terms,
      items: items,
      buildingFormulas: buildingFormulas,
      operators: operators,
    );
    final summary = RegionSummarySnapshot(
      schemaVersionValue: RegionSnapshot.schemaVersion,
      region: region,
      sourceRevision: sourceRevision,
      sourceVersion: version,
      fetchedAt: fetchedAt,
      operators: summaryOperators,
    );
    final status = RegionSyncStatus(
      region: region,
      sourceRevision: sourceRevision,
      sourceVersion: version.versionControl,
      fetchedAt: fetchedAt.toIso8601String(),
      operatorCount: operators.length,
      isReady: true,
    );
    final result = SyncResult(
      region: region,
      sourceRevision: sourceRevision,
      sourceVersion: version.versionControl,
      updatedAt: fetchedAt.toIso8601String(),
      operatorCount: operators.length,
      status: 'success',
    );

    return _NormalizedRegion(
      snapshot: snapshot,
      summary: summary,
      status: status,
      terms: terms,
      result: result,
    );
  }

  Future<void> _write(RegionCode region, _NormalizedRegion normalized) async {
    await _cache.writeSnapshot(normalized.snapshot);
    await _cache.writeSummary(normalized.summary);
    await _cache.writeStatus(normalized.status);
    await _cache.writeTerms(region, normalized.terms);
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
    );
  }
}

/// Rust `sync_region_data`: table revisions joined in this order (game data
/// constants are not part of it), or the branch when none were reported.
const _revisionTableOrder = [
  ArknightsDataSource.characterTableFile,
  ArknightsDataSource.skillTableFile,
  ArknightsDataSource.uniequipTableFile,
  ArknightsDataSource.handbookTeamTableFile,
  ArknightsDataSource.rangeTableFile,
  ArknightsDataSource.itemTableFile,
  ArknightsDataSource.stageTableFile,
  ArknightsDataSource.buildingDataFile,
  ArknightsDataSource.battleEquipTableFile,
  ArknightsDataSource.favorTableFile,
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
  });

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
}

class _NormalizedRegion {
  const _NormalizedRegion({
    required this.snapshot,
    required this.summary,
    required this.status,
    required this.terms,
    required this.result,
  });

  final RegionSnapshot snapshot;
  final RegionSummarySnapshot summary;
  final RegionSyncStatus status;
  final Map<String, String> terms;
  final SyncResult result;
}
