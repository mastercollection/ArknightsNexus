import 'extra/common.dart';
import 'extra/home.dart';
import 'extra/items.dart';
import 'extra/operators.dart';
import 'extra/plan.dart';
import 'extra/settings.dart';
import 'extra/shell.dart';

/// Strings added by the redesign, per area, consulted after the generated
/// `nexusMessages` (so the original copy always wins for shared keys).
const List<Map<String, Map<String, String>>> nexusExtraMessages = [
  commonExtraMessages,
  shellExtraMessages,
  homeExtraMessages,
  operatorsExtraMessages,
  itemsExtraMessages,
  planExtraMessages,
  settingsExtraMessages,
];
