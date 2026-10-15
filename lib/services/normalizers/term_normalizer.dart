import '../../raw_models/gamedata_const.dart';

class TermNormalizer {
  const TermNormalizer();

  /// Port of Tauri `into_term_descriptions`: trimmed descriptions keyed by
  /// the dictionary key, blank descriptions dropped.
  Map<String, String> normalize(RawGameDataConst constants) {
    return constants.termDescriptions();
  }
}
