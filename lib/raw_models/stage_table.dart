import 'raw_helpers.dart';

class RawStageTable {
  const RawStageTable({this.stages = const {}});

  final Map<String, RawStageEntry> stages;

  factory RawStageTable.fromJson(Map<String, Object?> json) {
    return RawStageTable(
      stages: rawMapOf(json['stages'], RawStageEntry.fromJson),
    );
  }
}

class RawStageEntry {
  const RawStageEntry({required this.stageId, this.code});

  final String stageId;
  final String? code;

  factory RawStageEntry.fromJson(Map<String, Object?> json) {
    return RawStageEntry(
      stageId: rawString(json, 'stageId'),
      code: json['code'] as String?,
    );
  }
}
