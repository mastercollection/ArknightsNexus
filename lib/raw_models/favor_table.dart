import 'raw_helpers.dart';

/// Upstream `favor_table.json`: `{ maxFavor, favorFrames: [{ level, data:
/// { favorPoint, percent, battlePhase } }] }`.
class RawFavorTable {
  const RawFavorTable({this.maxFavor = 0, this.favorFrames = const []});

  final int maxFavor;
  final List<RawFavorFrame> favorFrames;

  factory RawFavorTable.fromJson(Map<String, Object?> json) {
    return RawFavorTable(
      maxFavor: rawInt(json, 'maxFavor'),
      favorFrames: rawListOf(json['favorFrames'], RawFavorFrame.fromJson),
    );
  }
}

class RawFavorFrame {
  const RawFavorFrame({required this.level, required this.data});

  final int level;
  final RawFavorFrameData data;

  factory RawFavorFrame.fromJson(Map<String, Object?> json) {
    return RawFavorFrame(
      level: rawInt(json, 'level'),
      data: RawFavorFrameData.fromJson(rawMap(json['data'])),
    );
  }
}

class RawFavorFrameData {
  const RawFavorFrameData({
    required this.favorPoint,
    required this.percent,
    required this.battlePhase,
  });

  final int favorPoint;
  final int percent;
  final int battlePhase;

  factory RawFavorFrameData.fromJson(Map<String, Object?> json) {
    return RawFavorFrameData(
      favorPoint: rawInt(json, 'favorPoint'),
      percent: rawInt(json, 'percent'),
      battlePhase: rawInt(json, 'battlePhase'),
    );
  }
}
