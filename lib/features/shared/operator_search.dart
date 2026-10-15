import '../../domain/operator.dart';
import '../../i18n/nexus_i18n.dart';

/// Normalizes a search box value for [operatorMatchesQuery].
String operatorSearchNeedle(String query) => query.trim().toLowerCase();

/// Operator search of the list and the plan picker: [needle] (see
/// [operatorSearchNeedle]) matches the name, the raw and the translated
/// profession (e.g. "메딕"), teams, nations and groups. An empty needle
/// matches everything.
bool operatorMatchesQuery(
  OperatorSummary operator,
  String needle,
  NexusI18n i18n,
) {
  if (needle.isEmpty) {
    return true;
  }
  return [
    operator.name,
    operator.profession,
    i18n.profession(operator.profession),
    ...operator.teams,
    ...operator.nations,
    ...operator.groups,
  ].any((value) => value.toLowerCase().contains(needle));
}
