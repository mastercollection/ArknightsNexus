import '../core/errors/app_failure.dart';
import '../data_sources/data_version.dart';
import '../data_sources/region_code.dart';
import 'building_formula.dart';
import 'item.dart';
import 'operator.dart';

class RegionSnapshot {
  const RegionSnapshot({
    required this.schemaVersionValue,
    required this.region,
    required this.sourceRevision,
    required this.sourceVersion,
    required this.fetchedAt,
    this.stageCodeMap = const {},
    this.terms = const {},
    this.items = const [],
    this.buildingFormulas = const BuildingFormulaBundle(),
    this.operators = const [],
    this.unreleasedSourceVersions = const {},
  });

  /// Bump whenever the normalizer output changes. A cached snapshot with a
  /// different version is treated as missing, so the next
  /// `ensureRegionFresh` re-downloads and re-normalizes even when the remote
  /// data version is unchanged.
  ///
  /// 2: full Rust-parity operator normalization (traits/talents/potentials,
  /// ba tags, humanized profession/branch, cost item info, etc.).
  /// 3: operators carry `releaseOrder` and are sorted newest release first.
  /// 4: published snapshots add operators (and the items and terms they
  /// need) the region has not released yet, marked `unreleasedSource`.
  static const schemaVersion = 4;

  final int schemaVersionValue;
  final RegionCode region;
  final String sourceRevision;
  final DataVersion sourceVersion;
  final DateTime fetchedAt;
  final Map<String, String> stageCodeMap;
  final Map<String, String> terms;
  final List<ItemEntry> items;
  final BuildingFormulaBundle buildingFormulas;
  final List<OperatorDetail> operators;

  /// `VersionControl` per source region code of the unreleased operators
  /// merged into this snapshot (see [OperatorDetail.unreleasedSource]);
  /// empty for a snapshot normalized from the region's own tables only.
  /// The snapshot is current only while both its own version and these
  /// match the published manifest.
  final Map<String, String> unreleasedSourceVersions;

  factory RegionSnapshot.fromJson(Map<String, Object?> json) {
    final schemaVersionValue = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    if (schemaVersionValue != schemaVersion) {
      throw CacheFailure(
        'Unsupported region snapshot schema: $schemaVersionValue',
      );
    }

    return RegionSnapshot(
      schemaVersionValue: schemaVersionValue,
      region: RegionCode.fromJson(json['region']),
      sourceRevision: json['sourceRevision'] as String,
      sourceVersion: DataVersion.fromJson(_map(json['sourceVersion'])),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      stageCodeMap: _stringMap(json['stageCodeMap']),
      terms: _stringMap(json['terms']),
      items: _list(json['items'], (value) => ItemEntry.fromJson(_map(value))),
      buildingFormulas:
          BuildingFormulaBundle.fromJson(_map(json['buildingFormulas'])),
      operators: _list(
        json['operators'],
        (value) => OperatorDetail.fromJson(_map(value)),
      ),
      unreleasedSourceVersions: _stringMap(json['unreleasedSourceVersions']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersionValue,
      'region': region.toJson(),
      'sourceRevision': sourceRevision,
      'sourceVersion': sourceVersion.toJson(),
      'unreleasedSourceVersions': unreleasedSourceVersions,
      'fetchedAt': fetchedAt.toIso8601String(),
      'stageCodeMap': stageCodeMap,
      'terms': terms,
      'items': items.map((entry) => entry.toJson()).toList(),
      'buildingFormulas': buildingFormulas.toJson(),
      'operators': operators.map((entry) => entry.toJson()).toList(),
    };
  }
}

class RegionSummarySnapshot {
  const RegionSummarySnapshot({
    required this.schemaVersionValue,
    required this.region,
    required this.sourceRevision,
    required this.sourceVersion,
    required this.fetchedAt,
    this.operators = const [],
  });

  final int schemaVersionValue;
  final RegionCode region;
  final String sourceRevision;
  final DataVersion sourceVersion;
  final DateTime fetchedAt;
  final List<OperatorSummary> operators;

  factory RegionSummarySnapshot.fromJson(Map<String, Object?> json) {
    final schemaVersionValue = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    if (schemaVersionValue != RegionSnapshot.schemaVersion) {
      throw CacheFailure(
        'Unsupported region summary schema: $schemaVersionValue',
      );
    }

    return RegionSummarySnapshot(
      schemaVersionValue: schemaVersionValue,
      region: RegionCode.fromJson(json['region']),
      sourceRevision: json['sourceRevision'] as String,
      sourceVersion: DataVersion.fromJson(_map(json['sourceVersion'])),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      operators: _list(
        json['operators'],
        (value) => OperatorSummary.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersionValue,
      'region': region.toJson(),
      'sourceRevision': sourceRevision,
      'sourceVersion': sourceVersion.toJson(),
      'fetchedAt': fetchedAt.toIso8601String(),
      'operators': operators.map((entry) => entry.toJson()).toList(),
    };
  }
}

Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value! as Map);

Map<String, String> _stringMap(Object? value) {
  return Map<String, Object?>.from(value as Map? ?? const {}).map(
    (key, entry) => MapEntry(key, entry as String),
  );
}

List<T> _list<T>(Object? value, T Function(Object?) convert) {
  return (value as List? ?? const []).map(convert).toList();
}
