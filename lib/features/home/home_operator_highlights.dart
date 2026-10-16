import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/operator.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/operator_service.dart';
import '../../ui/redesign/rd_widgets.dart';
import '../operators/operators_common.dart'
    show UnreleasedBadge, unreleasedLabel;
import '../shared/number_format.dart';
import '../shared/region_sync.dart';

/// How many operators each home strip keeps (the phone scrollers show all of
/// them, PC rows as many as fit).
const _highlightCount = 12;

/// Newest operators of the selected region and the first unreleased ones it
/// shows from another region's data.
class HomeOperatorHighlights {
  const HomeOperatorHighlights({
    this.newest = const [],
    this.unreleased = const [],
    this.unreleasedCount = 0,
  });

  /// The region's own operators, newest first.
  final List<OperatorSummary> newest;

  /// The first unreleased operators, in list order.
  final List<OperatorSummary> unreleased;

  /// All unreleased operators of the region.
  final int unreleasedCount;
}

/// Reads [HomeOperatorHighlights] from the region's operator summaries,
/// which the snapshot keeps newest first. Empty until the region has data;
/// reloads on region change and after a sync.
final homeOperatorHighlightsProvider =
    FutureProvider.autoDispose<HomeOperatorHighlights>((ref) async {
  final region = ref.watch(regionProvider);
  final status = await ref.watch(regionSyncStatusProvider.future);
  if (status?.isReady != true) {
    return const HomeOperatorHighlights();
  }
  final operators = await ref
      .watch(operatorServiceProvider)
      .listOperators(OperatorQuery(region: region));
  final newest = <OperatorSummary>[];
  final unreleased = <OperatorSummary>[];
  var unreleasedCount = 0;
  for (final operator in operators) {
    if (operator.isUnreleased) {
      unreleasedCount += 1;
      if (unreleased.length < _highlightCount) {
        unreleased.add(operator);
      }
    } else if (newest.length < _highlightCount) {
      newest.add(operator);
    }
  }
  return HomeOperatorHighlights(
    newest: newest,
    unreleased: unreleased,
    unreleasedCount: unreleasedCount,
  );
});

void _openOperator(BuildContext context, OperatorSummary operator) =>
    context.push('/operators/${Uri.encodeComponent(operator.id)}');

/// Section heading row: title, optional muted caption, trailing link.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.linkLabel,
    required this.linkKey,
    this.caption,
  });

  final String title;
  final String? caption;
  final String linkLabel;
  final Key linkKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RdText.sectionTitle,
                  ),
                ),
              ),
              if (caption != null) ...[
                const SizedBox(width: 10),
                Text(caption!, style: RdText.small),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          link: true,
          child: InkWell(
            key: linkKey,
            borderRadius: BorderRadius.circular(RdRadii.chip),
            onTap: () => context.push('/operators'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Align(
                  widthFactor: 1,
                  child: Text(
                    linkLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: RdColors.accentHover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Lays [count] tiles of at least [minTileWidth] in one row (PC) or, when
/// [compact], in a horizontal scroller of [tileWidth]-wide tiles that bleeds
/// into the page padding (phones).
class _HighlightStrip extends StatelessWidget {
  const _HighlightStrip({
    required this.compact,
    required this.count,
    required this.itemBuilder,
    required this.minTileWidth,
    required this.maxColumns,
    required this.tileWidth,
    required this.gap,
  });

  final bool compact;
  final int count;
  final Widget Function(int index) itemBuilder;
  final double minTileWidth;
  final int maxColumns;
  final double tileWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) SizedBox(width: gap),
              SizedBox(width: tileWidth, child: itemBuilder(i)),
            ],
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          1,
          math.min(
            maxColumns,
            ((constraints.maxWidth + gap) / (minTileWidth + gap)).floor(),
          ),
        );
        final shown = math.min(columns, count);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                child: i < shown ? itemBuilder(i) : const SizedBox.shrink(),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Card on PC, bare section on phones (`MHome.dc.html`).
Widget _sectionFrame({required bool compact, required Widget child}) {
  if (compact) {
    return child;
  }
  return RdCard(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
    child: child,
  );
}

/// "새로 실장": the newest operators of the region; each opens its detail.
class HomeNewReleasesSection extends ConsumerWidget {
  const HomeNewReleasesSection({required this.compact, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final newest =
        ref.watch(homeOperatorHighlightsProvider).valueOrNull?.newest ??
            const <OperatorSummary>[];
    if (newest.isEmpty) {
      return const SizedBox.shrink();
    }
    return Semantics(
      container: true,
      child: _sectionFrame(
        compact: compact,
        child: Column(
          key: const Key('home-new-releases'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              title: i18n.t('rd.home.newReleases.title'),
              linkLabel: i18n.t('rd.home.newReleases.all'),
              linkKey: const Key('home-new-releases-all'),
            ),
            SizedBox(height: compact ? 4 : 6),
            _HighlightStrip(
              compact: compact,
              count: newest.length,
              minTileWidth: 104,
              maxColumns: 8,
              tileWidth: 84,
              gap: compact ? 10 : 12,
              itemBuilder: (index) => _NewOperatorTile(
                operator: newest[index],
                i18n: i18n,
                compact: compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewOperatorTile extends StatelessWidget {
  const _NewOperatorTile({
    required this.operator,
    required this.i18n,
    required this.compact,
  });

  final OperatorSummary operator;
  final NexusI18n i18n;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final profession = i18n.profession(operator.profession);
    return Semantics(
      button: true,
      label: '${operator.name}, ★${operator.rarity}, $profession',
      excludeSemantics: true,
      child: InkWell(
        key: Key('home-new-${operator.id}'),
        borderRadius: BorderRadius.circular(RdRadii.control),
        onTap: () => _openOperator(context, operator),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 2 : 8),
          child: Column(
            children: [
              RdPortrait(
                charId: operator.id,
                name: operator.name,
                size: 72,
                radius: RdRadii.control,
              ),
              const SizedBox(height: 6),
              Text(
                operator.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: RdColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '★' * operator.rarity.clamp(0, 6),
                maxLines: 1,
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  letterSpacing: 1,
                  color: RdColors.rarity,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                profession,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  color: RdColors.text3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "미실장 미리보기": the first operators the region shows from another
/// region's data, with their violet badge. Nothing when there are none
/// (e.g. CN, whose data has every operator).
class HomeUnreleasedPreviewSection extends ConsumerWidget {
  const HomeUnreleasedPreviewSection({required this.compact, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final highlights = ref.watch(homeOperatorHighlightsProvider).valueOrNull;
    if (highlights == null || highlights.unreleased.isEmpty) {
      return const SizedBox.shrink();
    }
    final unreleased = highlights.unreleased;
    final count = formatWholeNumber(highlights.unreleasedCount);
    return Semantics(
      container: true,
      child: _sectionFrame(
        compact: compact,
        child: Column(
          key: const Key('home-unreleased-preview'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              title: i18n.t('rd.home.unreleased.title'),
              caption: i18n.t('common.operatorCount', {'count': count}),
              linkLabel: compact
                  ? i18n.t('rd.home.unreleased.allShort')
                  : i18n.t('rd.home.unreleased.all', {'count': count}),
              linkKey: const Key('home-unreleased-all'),
            ),
            SizedBox(height: compact ? 4 : 6),
            _HighlightStrip(
              compact: compact,
              count: unreleased.length,
              minTileWidth: 160,
              maxColumns: 6,
              tileWidth: 96,
              gap: compact ? 10 : 12,
              itemBuilder: (index) => _UnreleasedTile(
                operator: unreleased[index],
                i18n: i18n,
                compact: compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreleasedTile extends StatelessWidget {
  const _UnreleasedTile({
    required this.operator,
    required this.i18n,
    required this.compact,
  });

  final OperatorSummary operator;
  final NexusI18n i18n;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badge = unreleasedLabel(i18n, operator.unreleasedSource!);
    final profession = i18n.profession(operator.profession);
    final name = Text(
      operator.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 12 : 13,
        fontWeight: FontWeight.w600,
        color: RdColors.text,
      ),
    );
    final Widget content;
    if (compact) {
      content = Column(
        children: [
          RdPortrait(
            charId: operator.id,
            name: operator.name,
            size: 72,
            radius: RdRadii.control,
          ),
          const SizedBox(height: 6),
          name,
          const SizedBox(height: 4),
          UnreleasedBadge(label: badge),
        ],
      );
    } else {
      content = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: RdColors.surface3,
          borderRadius: BorderRadius.circular(RdRadii.control),
        ),
        child: Row(
          children: [
            RdPortrait(
              charId: operator.id,
              name: operator.name,
              size: 48,
              radius: RdRadii.chip,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  name,
                  const SizedBox(height: 3),
                  UnreleasedBadge(label: badge),
                  const SizedBox(height: 3),
                  Text(
                    profession,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: RdColors.text3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      label: '${operator.name}, $badge, $profession',
      excludeSemantics: true,
      child: InkWell(
        key: Key('home-unreleased-${operator.id}'),
        borderRadius: BorderRadius.circular(RdRadii.control),
        onTap: () => _openOperator(context, operator),
        child: compact
            ? Padding(padding: const EdgeInsets.only(top: 2), child: content)
            : content,
      ),
    );
  }
}
