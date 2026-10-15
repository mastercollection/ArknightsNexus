import 'package:intl/intl.dart';

/// Number formats of the plan figures.
///
/// The plan pages keep up to three decimals (`Intl.NumberFormat('ko-KR')`);
/// the home summary rounds up to whole numbers, since it only shows totals.
final _decimalFormat = NumberFormat('#,##0.###', 'en_US');
final _wholeFormat = NumberFormat('#,##0', 'en_US');

/// `1,234.5` (up to three decimals).
String formatPlanNumber(num value) => _decimalFormat.format(value);

/// `1,235`: rounded up to a whole number.
String formatWholeNumber(num value) => _wholeFormat.format(value.ceil());
