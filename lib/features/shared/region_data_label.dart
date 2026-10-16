import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data_sources/region_code.dart';
import '../../domain/sync_status.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'region_operator_counts.dart';

/// "KR 52.0.0": the region code and the game data version of its cached
/// snapshot, or the code alone while the region has none.
String regionDataLabel(RegionCode region, RegionSyncStatus? status) {
  final code = regionLabels[region] ?? region.value.toUpperCase();
  final version = status?.sourceVersion?.trim() ?? '';
  return version.isEmpty ? code : '$code $version';
}

/// When the cached snapshot was fetched, in local time
/// ("2026-10-17 14:05"); null when unknown or unreadable.
String? formatSyncTime(String? fetchedAt) {
  if (fetchedAt == null || fetchedAt.isEmpty) {
    return null;
  }
  final parsed = DateTime.tryParse(fetchedAt);
  if (parsed == null) {
    return null;
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
}

/// "415명 · 미실장 17명" with the unreleased part in the unreleased violet.
class OperatorCountsText extends StatelessWidget {
  const OperatorCountsText({
    required this.i18n,
    required this.counts,
    this.style,
    this.prefix = '',
    this.maxLines = 1,
    super.key,
  });

  final NexusI18n i18n;
  final RegionOperatorCounts counts;
  final TextStyle? style;

  /// Text in front of the counts in the same style (e.g. "· ").
  final String prefix;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final full = formatOperatorCounts(i18n, counts);
    final native = formatOperatorCounts(
      i18n,
      RegionOperatorCounts(native: counts.native, unreleased: 0),
    );
    // Every locale starts the combined string with the native count.
    final split = counts.unreleased > 0 && full.startsWith(native)
        ? native.length
        : full.length;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$prefix${full.substring(0, split)}'),
          if (split < full.length)
            TextSpan(
              text: full.substring(split),
              style: const TextStyle(color: RdColors.unreleased),
            ),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
