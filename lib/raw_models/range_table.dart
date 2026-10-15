import 'raw_helpers.dart';

class RawRangeTable {
  const RawRangeTable({this.ranges = const {}});

  final Map<String, RawRangeEntry> ranges;

  factory RawRangeTable.fromJson(Map<String, Object?> json) {
    return RawRangeTable(
      ranges: json.map(
        (key, value) => MapEntry(key, RawRangeEntry.fromJson(rawMap(value))),
      ),
    );
  }
}

class RawRangeEntry {
  const RawRangeEntry({
    required this.id,
    required this.direction,
    this.grids = const [],
  });

  final String id;
  final int direction;
  final List<RawRangeGrid> grids;

  factory RawRangeEntry.fromJson(Map<String, Object?> json) {
    return RawRangeEntry(
      id: rawString(json, 'id'),
      direction: rawInt(json, 'direction'),
      grids: rawListOf(json['grids'], RawRangeGrid.fromJson),
    );
  }
}

class RawRangeGrid {
  const RawRangeGrid({required this.row, required this.col});

  final int row;
  final int col;

  factory RawRangeGrid.fromJson(Map<String, Object?> json) {
    return RawRangeGrid(row: rawInt(json, 'row'), col: rawInt(json, 'col'));
  }
}
