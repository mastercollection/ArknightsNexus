import '../data_sources/region_code.dart';

enum SyncPhase {
  checkingVersion,
  downloading,
  normalizing,
  writingSnapshot,
  complete,
}

class SyncStatus {
  const SyncStatus({
    required this.region,
    required this.phase,
    this.remoteVersion,
  });

  final RegionCode region;
  final SyncPhase phase;
  final String? remoteVersion;
}

class RegionSyncStatus {
  const RegionSyncStatus({
    required this.region,
    this.sourceRevision,
    this.sourceVersion,
    this.fetchedAt,
    required this.operatorCount,
    required this.isReady,
    this.publishedSha256,
  });

  final RegionCode region;
  final String? sourceRevision;
  final String? sourceVersion;
  final String? fetchedAt;
  final int operatorCount;
  final bool isReady;

  /// SHA-256 of the published snapshot file the cache was written from;
  /// null after a raw upstream sync. The published copy can change while the
  /// game versions stay the same (a better normalizer), so this is what
  /// tells that the cache holds the current copy.
  final String? publishedSha256;

  factory RegionSyncStatus.fromJson(Map<String, Object?> json) {
    return RegionSyncStatus(
      region: RegionCode.fromJson(json['region']),
      sourceRevision: json['sourceRevision'] as String?,
      sourceVersion: json['sourceVersion'] as String?,
      fetchedAt: json['fetchedAt'] as String?,
      operatorCount: (json['operatorCount'] as num).toInt(),
      isReady: json['isReady'] as bool,
      publishedSha256: json['publishedSha256'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'region': region.toJson(),
      'sourceRevision': sourceRevision,
      'sourceVersion': sourceVersion,
      'fetchedAt': fetchedAt,
      'operatorCount': operatorCount,
      'isReady': isReady,
      if (publishedSha256 != null) 'publishedSha256': publishedSha256,
    };
  }
}

class SyncResult {
  const SyncResult({
    required this.region,
    required this.sourceRevision,
    required this.sourceVersion,
    required this.updatedAt,
    required this.operatorCount,
    required this.status,
  });

  final RegionCode region;
  final String sourceRevision;
  final String sourceVersion;
  final String updatedAt;
  final int operatorCount;
  final String status;

  factory SyncResult.fromJson(Map<String, Object?> json) {
    return SyncResult(
      region: RegionCode.fromJson(json['region']),
      sourceRevision: json['sourceRevision'] as String,
      sourceVersion: json['sourceVersion'] as String,
      updatedAt: json['updatedAt'] as String,
      operatorCount: (json['operatorCount'] as num).toInt(),
      status: json['status'] as String,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'region': region.toJson(),
      'sourceRevision': sourceRevision,
      'sourceVersion': sourceVersion,
      'updatedAt': updatedAt,
      'operatorCount': operatorCount,
      'status': status,
    };
  }
}
