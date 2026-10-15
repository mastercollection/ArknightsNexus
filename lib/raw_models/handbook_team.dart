import 'raw_helpers.dart';

class RawHandbookTeamTable {
  const RawHandbookTeamTable({this.powers = const {}});

  final Map<String, RawPowerEntry> powers;

  factory RawHandbookTeamTable.fromJson(Map<String, Object?> json) {
    return RawHandbookTeamTable(
      powers: json.map(
        (key, value) => MapEntry(key, RawPowerEntry.fromJson(rawMap(value))),
      ),
    );
  }

  /// Port of Tauri `into_power_names`: id = `powerId` (or the dict key when
  /// blank), name = trimmed `powerName`; blank ids/names are dropped.
  Map<String, String> powerNames() {
    final result = <String, String>{};
    for (final entry in powers.entries) {
      final id =
          entry.value.powerId.trim().isEmpty ? entry.key : entry.value.powerId;
      final name = entry.value.powerName.trim();
      if (id.trim().isEmpty || name.isEmpty) {
        continue;
      }
      result[id] = name;
    }
    return result;
  }
}

class RawPowerEntry {
  const RawPowerEntry({
    required this.powerId,
    required this.powerName,
  });

  final String powerId;
  final String powerName;

  factory RawPowerEntry.fromJson(Map<String, Object?> json) {
    return RawPowerEntry(
      powerId: rawString(json, 'powerId'),
      powerName: rawString(json, 'powerName'),
    );
  }
}
