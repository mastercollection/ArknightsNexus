/// The only part of `handbook_info_table.json` the app reads: the key order
/// of `handbookDict`. Upstream appends an operator's entry when the operator
/// is added to the game, so the key order is the region's release order,
/// oldest first. The entries themselves (profile texts, about 8 MB) are
/// dropped as soon as the keys are read.
class RawHandbookInfoTable {
  const RawHandbookInfoTable({this.charIds = const []});

  /// Character ids in `handbookDict` key order, oldest first.
  final List<String> charIds;

  factory RawHandbookInfoTable.fromJson(Map<String, Object?> json) {
    final dict = json['handbookDict'];
    return RawHandbookInfoTable(
      charIds: dict is Map ? List.unmodifiable(dict.keys.cast<String>()) : [],
    );
  }

  /// Release position per character id, counted from 1 so that higher is
  /// newer and 0 can stand for "not in the handbook".
  Map<String, int> releaseOrder() {
    return {
      for (var index = 0; index < charIds.length; index++)
        charIds[index]: index + 1,
    };
  }
}
