import 'raw_helpers.dart';

class RawZoneTable {
  const RawZoneTable({this.zones = const {}});

  final Map<String, RawZoneEntry> zones;

  factory RawZoneTable.fromJson(Map<String, Object?> json) {
    return RawZoneTable(
      zones: rawMapOf(json['zones'], RawZoneEntry.fromJson),
    );
  }
}

class RawZoneEntry {
  const RawZoneEntry({
    required this.zoneId,
    required this.zoneIndex,
    required this.type,
    this.zoneNameFirst,
    this.zoneNameSecond,
  });

  final String zoneId;
  final int zoneIndex;

  /// `MAINLINE`, `ACTIVITY`, `SIDESTORY`, `WEEKLY`, `CAMPAIGN`, ...
  final String type;

  /// Such as `Episode 1`.
  final String? zoneNameFirst;

  /// Such as `Evil Time Part 2`.
  final String? zoneNameSecond;

  factory RawZoneEntry.fromJson(Map<String, Object?> json) {
    return RawZoneEntry(
      zoneId: rawString(json, 'zoneID'),
      zoneIndex: rawInt(json, 'zoneIndex'),
      type: rawString(json, 'type'),
      zoneNameFirst: rawOptString(json, 'zoneNameFirst'),
      zoneNameSecond: rawOptString(json, 'zoneNameSecond'),
    );
  }
}
