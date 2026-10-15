import '../core/errors/app_failure.dart';
import 'region_code.dart';

/// Pre-normalized region snapshots published on GitHub Pages by
/// `.github/workflows/pages.yml` (`tool/build_snapshots.dart`).
///
/// Layout under [baseUri]: `manifest.json` lists every published region;
/// each region's snapshot lives at the manifest's relative `path`,
/// `v{schemaVersion}/{region}/snapshot.json`.
class PublishedData {
  const PublishedData._();

  /// The published `data/` directory. Override for a local or forked site
  /// with `--dart-define=NEXUS_DATA_BASE_URL=http://127.0.0.1:8080/data/`.
  static const baseUrl = String.fromEnvironment(
    'NEXUS_DATA_BASE_URL',
    defaultValue: 'https://mastercollection.github.io/ArknightsNexus/data/',
  );

  static Uri get baseUri => Uri.parse(baseUrl);

  static const manifestFile = 'manifest.json';

  /// [PublishedManifest.formatVersion] this app reads.
  static const manifestFormatVersion = 1;

  static Uri manifestUri(Uri base) => _directory(base).resolve(manifestFile);

  /// Resolves a manifest-relative [path] against [base].
  static Uri fileUri(Uri base, String path) => _directory(base).resolve(path);

  /// Where the generator writes a region's snapshot, relative to `data/`.
  static String snapshotPath(int schemaVersion, RegionCode region) =>
      'v$schemaVersion/${region.value}/snapshot.json';

  static Uri _directory(Uri base) =>
      base.path.endsWith('/') ? base : base.replace(path: '${base.path}/');
}

/// `manifest.json`.
class PublishedManifest {
  const PublishedManifest({
    required this.formatVersion,
    required this.generatedAt,
    this.fingerprint,
    required this.regions,
  });

  final int formatVersion;
  final DateTime generatedAt;

  /// Hash of the generator inputs (generator, normalizers, models, site) of
  /// the build that wrote this manifest. Unchanged regions are copied from
  /// the previous site only while it matches.
  final String? fingerprint;

  final Map<RegionCode, PublishedRegion> regions;

  factory PublishedManifest.fromJson(Map<String, Object?> json) {
    final formatVersion = json['formatVersion'];
    if (formatVersion is! int) {
      throw const ParseFailure(
        'Manifest requires an integer formatVersion',
        source: 'formatVersion',
      );
    }
    if (formatVersion != PublishedData.manifestFormatVersion) {
      throw ParseFailure(
        'Unsupported manifest format: $formatVersion',
        source: 'formatVersion',
      );
    }
    final regions = <RegionCode, PublishedRegion>{};
    final rawRegions = json['regions'];
    if (rawRegions is! Map) {
      throw const ParseFailure(
        'Manifest requires a regions object',
        source: 'regions',
      );
    }
    for (final MapEntry(:key, :value) in rawRegions.entries) {
      final RegionCode region;
      try {
        region = RegionCode.parse(key as String);
      } on FormatException {
        // A region a newer generator publishes; this app cannot use it.
        continue;
      }
      regions[region] = PublishedRegion.fromJson(
        Map<String, Object?>.from(value as Map),
      );
    }
    return PublishedManifest(
      formatVersion: formatVersion,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      fingerprint: json['fingerprint'] as String?,
      regions: regions,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'formatVersion': formatVersion,
      'generatedAt': generatedAt.toIso8601String(),
      'fingerprint': fingerprint,
      'regions': {
        for (final region in RegionCode.values)
          if (regions[region] != null) region.value: regions[region]!.toJson(),
      },
    };
  }
}

/// One region of the manifest.
class PublishedRegion {
  const PublishedRegion({
    required this.schemaVersion,
    required this.versionControl,
    required this.sourceRevision,
    required this.fetchedAt,
    required this.operatorCount,
    required this.snapshot,
    this.unreleasedSourceVersions = const {},
  });

  /// `RegionSnapshot.schemaVersion` of the published snapshot.
  final int schemaVersion;

  /// Upstream `VersionControl` the snapshot was built from.
  final String versionControl;
  final String sourceRevision;

  /// The snapshot's own `fetchedAt`: when the generator normalized it.
  final DateTime fetchedAt;
  final int operatorCount;
  final PublishedFile snapshot;

  /// `VersionControl` per region code whose unreleased operators the
  /// snapshot includes (`RegionSnapshot.unreleasedSourceVersions`). The
  /// snapshot changes when any of them does, even if [versionControl]
  /// does not.
  final Map<String, String> unreleasedSourceVersions;

  /// Whether a snapshot built from [versionControl] plus [sourceVersions]
  /// is this entry's content.
  bool matchesVersions(
    String versionControl,
    Map<String, String> sourceVersions,
  ) {
    if (versionControl != this.versionControl ||
        sourceVersions.length != unreleasedSourceVersions.length) {
      return false;
    }
    return sourceVersions.entries.every(
      (entry) => unreleasedSourceVersions[entry.key] == entry.value,
    );
  }

  factory PublishedRegion.fromJson(Map<String, Object?> json) {
    final files = Map<String, Object?>.from(json['files'] as Map);
    final sources = json['unreleasedSourceVersions'];
    return PublishedRegion(
      schemaVersion: (json['schemaVersion'] as num).toInt(),
      versionControl: json['versionControl'] as String,
      sourceRevision: json['sourceRevision'] as String,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      operatorCount: (json['operatorCount'] as num).toInt(),
      snapshot: PublishedFile.fromJson(
        Map<String, Object?>.from(files['snapshot'] as Map),
      ),
      unreleasedSourceVersions: sources is Map
          ? {
              for (final MapEntry(:key, :value) in sources.entries)
                key as String: value as String,
            }
          : const {},
    );
  }

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'versionControl': versionControl,
      'sourceRevision': sourceRevision,
      'fetchedAt': fetchedAt.toIso8601String(),
      'operatorCount': operatorCount,
      'unreleasedSourceVersions': unreleasedSourceVersions,
      'files': {'snapshot': snapshot.toJson()},
    };
  }
}

/// A published file: path relative to the manifest, SHA-256 and size of
/// the bytes as written (before any transport compression).
class PublishedFile {
  const PublishedFile({
    required this.path,
    required this.sha256,
    required this.bytes,
  });

  final String path;
  final String sha256;
  final int bytes;

  factory PublishedFile.fromJson(Map<String, Object?> json) {
    final path = json['path'] as String;
    // Paths are generator-written and relative; refuse anything that could
    // point outside the published data directory.
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.contains('..') ||
        path.contains('://')) {
      throw ParseFailure('Invalid published file path: $path', source: 'path');
    }
    return PublishedFile(
      path: path,
      sha256: (json['sha256'] as String).toLowerCase(),
      bytes: (json['bytes'] as num).toInt(),
    );
  }

  Map<String, Object?> toJson() {
    return {'path': path, 'sha256': sha256, 'bytes': bytes};
  }
}
