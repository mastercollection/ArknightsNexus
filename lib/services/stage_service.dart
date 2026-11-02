import 'dart:convert';

import '../core/concurrency/background.dart';
import '../core/errors/app_failure.dart';
import '../core/http/http_client.dart';
import '../data_sources/region_code.dart';
import '../domain/stage.dart';
import '../raw_models/level_data.dart';
import '../repositories/region_cache_repository.dart';
import 'normalizers/stage_normalizer.dart';

abstract interface class StageService {
  /// Every stage of [region] with a code, in stage table order.
  Future<List<StageSummary>> listStages(RegionCode region);

  /// The battle of [stageId]: its level file, fetched from the upstream
  /// repository on first use, with the region's enemies. Throws
  /// [MissingLevelFailure] for a stage without one.
  Future<StageDetail> stageDetail(RegionCode region, String stageId);
}

/// Stage list and enemies from the cached region snapshot; level files on
/// demand, kept for the session (the most recent [maxCachedDetails]).
class CachedStageService implements StageService {
  CachedStageService(
    this._cache,
    this._httpClient, {
    StageNormalizer normalizer = const StageNormalizer(),
  }) : _normalizer = normalizer;

  static const maxCachedDetails = 12;

  final RegionCacheRepository _cache;
  final NexusHttpClient _httpClient;
  final StageNormalizer _normalizer;

  /// Keyed by region, data version and stage, most recent last.
  final _details = <String, StageDetail>{};
  final _inFlight = <String, Future<StageDetail>>{};

  /// The enemies of the last snapshot read, by id.
  String? _enemiesKey;
  Map<String, EnemyEntry> _enemies = const {};

  @override
  Future<List<StageSummary>> listStages(RegionCode region) async {
    return (await _cache.readSnapshot(region))?.stages ?? const [];
  }

  @override
  Future<StageDetail> stageDetail(RegionCode region, String stageId) async {
    final snapshot = await _cache.readSnapshot(region);
    if (snapshot == null) {
      throw MissingCacheFailure('No data for ${region.value}');
    }
    final stage = snapshot.stages.where((stage) => stage.stageId == stageId);
    if (stage.isEmpty) {
      throw InvalidInputFailure('Unknown stage $stageId');
    }
    final levelId = stage.first.levelId;
    if (levelId == null || levelId.isEmpty) {
      throw MissingLevelFailure('$stageId has no level');
    }

    final version = snapshot.sourceVersion.versionControl;
    final key = '${region.value}|$version|$stageId';
    final cached = _details.remove(key);
    if (cached != null) {
      _details[key] = cached;
      return cached;
    }

    final enemiesKey = '${region.value}|$version';
    if (_enemiesKey != enemiesKey) {
      _enemies = {for (final enemy in snapshot.enemies) enemy.enemyId: enemy};
      _enemiesKey = enemiesKey;
    }
    final enemies = _enemies;

    return _inFlight.putIfAbsent(key, () async {
      try {
        final String text;
        try {
          text = await _httpClient.getText(region.descriptor.levelUri(levelId));
        } on NetworkFailure catch (error) {
          if (error.statusCode == 404) {
            throw MissingLevelFailure('$stageId: no level file ($levelId)');
          }
          rethrow;
        }
        final detail = await _runDetailJob(
          _DetailJob(
            normalizer: _normalizer,
            stageId: stageId,
            levelText: text,
            enemies: enemies,
          ),
        );
        _details[key] = detail;
        while (_details.length > maxCachedDetails) {
          _details.remove(_details.keys.first);
        }
        return detail;
      } finally {
        _inFlight.remove(key);
      }
    });
  }
}

/// Everything the background isolate needs; all of it is plain data.
class _DetailJob {
  const _DetailJob({
    required this.normalizer,
    required this.stageId,
    required this.levelText,
    required this.enemies,
  });

  final StageNormalizer normalizer;
  final String stageId;
  final String levelText;
  final Map<String, EnemyEntry> enemies;
}

// Top-level so the closure handed to [runInBackground] captures only the job.
Future<StageDetail> _runDetailJob(_DetailJob job) =>
    runInBackground(() => _buildDetail(job));

StageDetail _buildDetail(_DetailJob job) {
  return job.normalizer.detail(
    job.stageId,
    RawLevelData.fromJson(jsonDecode(job.levelText) as Map<String, Object?>),
    job.enemies,
  );
}
