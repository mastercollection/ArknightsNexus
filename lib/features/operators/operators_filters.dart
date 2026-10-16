import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import '../shared/number_format.dart';
import 'operators_list_controller.dart';

/// Rounded-rect toggle button of the filter lists (`aria-pressed`).
class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 34,
    this.background = Colors.transparent,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final Color background;

  double get _horizontalPadding => height >= 44 ? 14 : 12;

  /// The label style on top of the [Material]'s default text style; also
  /// used by [_LazyOptionRuns] to measure the button.
  TextStyle _labelStyle([Color? color]) => TextStyle(
        fontSize: height >= 44 ? 14 : 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: color,
      );

  @override
  Widget build(BuildContext context) {
    final (Color border, Color fill, Color text) = selected
        ? (RdColors.accentLine, RdColors.accentSoft, RdColors.accentText)
        : (RdColors.border, background, RdColors.text2);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RdRadii.chip),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(RdRadii.chip),
          onTap: onTap,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: Center(
              widthFactor: 1,
              child: Text(label, style: _labelStyle(text)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A scroll box of [_OptionButton]s in the same runs a [Wrap] would make,
/// building only the runs near the visible part of the box.
///
/// The affiliation and BA tag lists have dozens of options (44 and 55 in
/// the KR data) of which a few runs fit the box; building every button
/// eagerly was most of the cost of opening the operators page. Button
/// widths come from measuring the labels with the style the buttons use,
/// and runs break with [RenderWrap]'s rule, so the layout matches the
/// [Wrap] it replaces.
class _LazyOptionRuns extends StatefulWidget {
  const _LazyOptionRuns({required this.buttons, required this.maxHeight});

  final List<_OptionButton> buttons;
  final double maxHeight;

  static const spacing = 6.0;

  @override
  State<_LazyOptionRuns> createState() => _LazyOptionRunsState();
}

class _LazyOptionRunsState extends State<_LazyOptionRuns> {
  /// Measured label widths by (label, bold); reset when the text setup or
  /// the loaded fonts change.
  final _widths = <(String, bool), double>{};
  Object? _measuredWith;

  @override
  void initState() {
    super.initState();
    // Labels measured before a font finished loading (web) are stale.
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    super.dispose();
  }

  void _fontsChanged() {
    setState(_widths.clear);
  }

  List<List<_OptionButton>> _runs(BuildContext context, double maxWidth) {
    // Inside the buttons' Material the default text style is bodyMedium.
    final base = Theme.of(context).textTheme.bodyMedium!;
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final setup = (base, textScaler, textDirection, locale);
    if (setup != _measuredWith) {
      _widths.clear();
      _measuredWith = setup;
    }

    double widthOf(_OptionButton button) {
      final text = _widths.putIfAbsent((button.label, button.selected), () {
        final painter = TextPainter(
          text: TextSpan(
            text: button.label,
            style: base.merge(button._labelStyle()),
          ),
          textDirection: textDirection,
          textScaler: textScaler,
          locale: locale,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      });
      return math.min(text + button._horizontalPadding * 2, maxWidth);
    }

    final runs = <List<_OptionButton>>[];
    var runExtent = 0.0;
    for (final button in widget.buttons) {
      final width = widthOf(button);
      if (runs.isEmpty ||
          runExtent + width + _LazyOptionRuns.spacing - maxWidth >
              precisionErrorTolerance) {
        runs.add([button]);
        runExtent = width;
      } else {
        runs.last.add(button);
        runExtent += width + _LazyOptionRuns.spacing;
      }
    }
    return runs;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final runs = _runs(context, maxWidth);
        const spacing = _LazyOptionRuns.spacing;
        final rowHeight =
            widget.buttons.isEmpty ? 0.0 : widget.buttons.first.height;
        final contentHeight = runs.isEmpty
            ? 0.0
            : runs.length * rowHeight + (runs.length - 1) * spacing;
        return SizedBox(
          height: math.min(contentHeight, widget.maxHeight),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            cacheExtent: rowHeight + spacing,
            itemCount: runs.length,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : spacing),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, button) in runs[index].indexed) ...[
                    if (i > 0) const SizedBox(width: spacing),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: button,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Inline search box of the filter panels (`#121a2c`, 38px).
class _MiniSearch extends StatelessWidget {
  const _MiniSearch({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.height = 38,
    this.background = RdColors.field,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final double height;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(RdRadii.small),
        border: Border.all(color: RdColors.line3),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 14, color: RdColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13, color: RdColors.text),
              cursorColor: RdColors.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: RdColors.placeholder,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PC sidebar
// ---------------------------------------------------------------------------

/// PC filter sidebar: page title, one collapsible group per dimension
/// (rarity and profession open; the searchable affiliation and BA tag lists
/// collapsed with their option counts), the unreleased switch and reset.
class OperatorsFilterSidebar extends ConsumerStatefulWidget {
  const OperatorsFilterSidebar({super.key});

  @override
  ConsumerState<OperatorsFilterSidebar> createState() =>
      _OperatorsFilterSidebarState();
}

class _OperatorsFilterSidebarState
    extends ConsumerState<OperatorsFilterSidebar> {
  final _affiliationQuery = TextEditingController();
  final _tagQuery = TextEditingController();

  @override
  void dispose() {
    _affiliationQuery.dispose();
    _tagQuery.dispose();
    super.dispose();
  }

  Widget _wrap(List<Widget> children) {
    return Wrap(spacing: 6, runSpacing: 6, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    // Only the filters, the option lists and the open groups show here;
    // paging the list (`loadMore`) or loading state changes must not
    // rebuild every chip.
    ref.watch(
      operatorsListControllerProvider.select(
        (list) => (
          list.filters,
          list.options,
          list.openFilterGroups.fold(0, (mask, d) => mask | (1 << d.index)),
        ),
      ),
    );
    final list = ref.read(operatorsListControllerProvider);
    final filters = list.filters;

    List<_OptionButton> optionButtons(
      OperatorFilterDimension dimension, {
      String query = '',
    }) {
      final q = query.trim().toLowerCase();
      return [
        for (final option in list.filterOptions(dimension, i18n))
          if (q.isEmpty ||
              option.selected ||
              option.label.toLowerCase().contains(q))
            _OptionButton(
              key: ValueKey(
                'operators-filter-${dimension.keyName}-${option.label}',
              ),
              label: option.label,
              selected: option.selected,
              height: 30,
              onTap: () => list.applyFilterOption(option),
            ),
      ];
    }

    Widget searchable(
      OperatorFilterDimension dimension,
      TextEditingController controller,
      double maxHeight,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MiniSearch(
            controller: controller,
            height: 36,
            hint: i18n.t('rd.operators.filter.search', {
              'title': dimension.title(i18n),
            }),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          _LazyOptionRuns(
            maxHeight: maxHeight,
            buttons: optionButtons(dimension, query: controller.text),
          ),
        ],
      );
    }

    Widget body(OperatorFilterDimension dimension) => switch (dimension) {
          OperatorFilterDimension.rarity =>
            _wrap(optionButtons(OperatorFilterDimension.rarity)),
          OperatorFilterDimension.profession => _wrap([
              _OptionButton(
                key: const ValueKey('operators-filter-profession-all'),
                label: i18n.t('rd.operators.filter.all'),
                selected: filters.profession == null,
                height: 30,
                onTap: () => list.filters =
                    list.filters.copyWith(profession: () => null),
              ),
              ...optionButtons(OperatorFilterDimension.profession),
            ]),
          OperatorFilterDimension.affiliation =>
            searchable(dimension, _affiliationQuery, 176),
          OperatorFilterDimension.baTags =>
            searchable(dimension, _tagQuery, 210),
        };

    return Container(
      color: RdColors.surface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            child: Semantics(
              header: true,
              child: Text(
                i18n.t('operatorsList.topBar.title'),
                style: RdText.pageTitle,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final dimension in OperatorFilterDimension.values)
                    _FilterGroup(
                      key: ValueKey(
                        'operators-filter-group-${dimension.keyName}',
                      ),
                      title: dimension.title(i18n),
                      open: list.openFilterGroups.contains(dimension),
                      // The long lists show how many options they hold, or
                      // the picked value(s) while folded.
                      badge: list.shownFilterValue(dimension, i18n) ??
                          (dimension.searchable
                              ? formatWholeNumber(
                                  list.filterOptions(dimension, i18n).length,
                                )
                              : null),
                      badgeSelected:
                          list.shownFilterValue(dimension, i18n) != null,
                      note: dimension.multi
                          ? i18n.t('rd.operators.filter.allOf')
                          : null,
                      onToggle: () => list.toggleFilterGroup(dimension),
                      child: body(dimension),
                    ),
                  if (list.options.hasUnreleased)
                    _UnreleasedSwitch(
                      label: i18n.t('rd.operators.filter.showUnreleased'),
                      note: i18n.t('rd.operators.filter.unreleasedNote', {
                        'source': list.options.unreleasedSources.join(' · '),
                        'count':
                            formatWholeNumber(list.options.unreleasedCount),
                      }),
                      value: !filters.hideUnreleased,
                      onChanged: list.toggleHideUnreleased,
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: RdColors.hairline)),
            ),
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RdRadii.control),
                side: const BorderSide(color: RdColors.border),
              ),
              child: InkWell(
                key: const Key('operators-filter-reset'),
                borderRadius: BorderRadius.circular(RdRadii.control),
                onTap: list.clearFilters,
                child: SizedBox(
                  height: 38,
                  child: Center(
                    child: Text(
                      i18n.t('operatorsList.filters.reset'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: RdColors.text2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One collapsible group of the sidebar: a 40px header (title, badge,
/// chevron) over its options.
class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.open,
    required this.onToggle,
    required this.child,
    this.badge,
    this.badgeSelected = false,
    this.note,
    super.key,
  });

  final String title;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  /// Option count or the selected value, next to the title.
  final String? badge;
  final bool badgeSelected;

  /// Helper under the open header (BA tags: "모두 포함").
  final String? note;

  @override
  Widget build(BuildContext context) {
    final badge = this.badge;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RdColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              borderRadius: BorderRadius.circular(RdRadii.control),
              onTap: onToggle,
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title, style: RdText.sectionTitle),
                      ),
                      if (badge != null)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeSelected
                                  ? RdColors.accentSoft
                                  : RdColors.surface3,
                              borderRadius: BorderRadius.circular(RdRadii.chip),
                            ),
                            child: Text(
                              badge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: badgeSelected
                                  ? const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: RdColors.accentText,
                                    )
                                  : RdText.mono(
                                      fontSize: 12,
                                      color: RdColors.text2,
                                    ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: RdColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (note != null) ...[
                    Text(note!, style: RdText.small),
                    const SizedBox(height: 8),
                  ],
                  child,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "미실장 표시" switch: on lists the unreleased strip; off is the
/// hide-unreleased filter.
class _UnreleasedSwitch extends StatelessWidget {
  const _UnreleasedSwitch({
    required this.label,
    required this.note,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String note;
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('operators-filter-hide-unreleased'),
        borderRadius: BorderRadius.circular(RdRadii.control),
        onTap: onChanged,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: RdColors.text,
                      ),
                    ),
                    Text(note, style: RdText.small),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 20,
                padding: const EdgeInsets.all(2),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: value ? RdColors.accent : RdColors.surface3,
                  borderRadius: BorderRadius.circular(RdRadii.pill),
                  border: value ? null : Border.all(color: RdColors.border),
                ),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: value ? RdColors.onAccent : RdColors.text3,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phone: chip row and sheets
// ---------------------------------------------------------------------------

/// The phone chip row: "no filters" / reset, the search chip (tap clears the
/// search) and one chip per dimension (tap opens its sheet, or clears it
/// when set).
class OperatorsFilterChipRow extends ConsumerWidget {
  const OperatorsFilterChipRow({required this.onClearQuery, super.key});

  /// Clears the search text (the field lives in the header).
  final VoidCallback onClearQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final list = ref.watch(operatorsListControllerProvider);
    final filters = list.filters;
    final query = filters.query.trim();
    // Board chips are 30-32px; phones keep 40px touch targets.
    final chipHeight = context.rdLayout == RdLayout.compact ? 40.0 : 32.0;

    Widget pill({
      Key? key,
      required String label,
      required bool on,
      required VoidCallback onTap,
      String? mark,
      String? semanticLabel,
    }) {
      return Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        child: RdChip(
          key: key,
          label: label,
          selected: on,
          height: chipHeight,
          onPressed: onTap,
          trailing: mark == null
              ? null
              : Text(
                  mark,
                  style: TextStyle(
                    fontSize: 11,
                    color: on ? RdColors.text : RdColors.secondary,
                  ),
                ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          if (filters.hasDimension) ...[
            pill(
              key: const Key('operators-filter-chip-reset'),
              label: i18n.t('rd.operators.filter.resetShort'),
              on: false,
              onTap: list.clearFilters,
            ),
            const SizedBox(width: 6),
          ],
          if (query.isNotEmpty) ...[
            pill(
              label: i18n.t('rd.operators.chip.query', {'value': query}),
              on: true,
              mark: '✕',
              semanticLabel:
                  i18n.t('rd.operators.chip.clearQuery', {'value': query}),
              onTap: onClearQuery,
            ),
            const SizedBox(width: 6),
          ],
          for (final (i, dimension)
              in OperatorFilterDimension.values.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Builder(
              builder: (context) {
                final title = dimension.title(i18n);
                final value = list.shownFilterValue(dimension, i18n);
                final set = value != null;
                return pill(
                  key: Key('operators-filter-${dimension.keyName}'),
                  label: set ? '$title: $value' : title,
                  on: set,
                  mark: set ? '✕' : '▾',
                  semanticLabel: set
                      ? i18n.t('rd.operators.chip.clearDimension', {
                          'title': '$title: $value',
                        })
                      : title,
                  onTap: set
                      ? () => list.clearFilterDimension(dimension)
                      : () => showOperatorFilterSheet(context, dimension),
                );
              },
            ),
          ],
          if (list.options.hasUnreleased) ...[
            const SizedBox(width: 6),
            pill(
              key: const Key('operators-filter-hide-unreleased'),
              label: i18n.t('rd.operators.filter.hideUnreleased'),
              on: filters.hideUnreleased,
              mark: filters.hideUnreleased ? '✕' : null,
              onTap: list.toggleHideUnreleased,
            ),
          ],
        ],
      ),
    );
  }
}

/// The "all filters" sheet: one row per dimension with its current value,
/// and the reset button.
Future<void> showOperatorFiltersSheet(BuildContext context) {
  return showRdSheet<void>(
    context: context,
    mode: RdSheetMode.sheet,
    sheetMaxWidth: 640,
    builder: (sheetContext) => const _AllFiltersSheet(),
  );
}

class _AllFiltersSheet extends ConsumerWidget {
  const _AllFiltersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final list = ref.watch(operatorsListControllerProvider);
    return RdSheetFrame(
      semanticLabel: i18n.t('operatorsList.filters.title'),
      scrollable: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              i18n.t('operatorsList.filters.title'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: RdColors.text,
              ),
            ),
            for (final dimension in OperatorFilterDimension.values) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final value = list.shownFilterValue(dimension, i18n);
                  return Material(
                    color: RdColors.sheetOption,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RdRadii.control),
                      side: const BorderSide(color: RdColors.white10),
                    ),
                    child: InkWell(
                      key: Key('operators-filter-row-${dimension.keyName}'),
                      borderRadius: BorderRadius.circular(RdRadii.control),
                      onTap: () {
                        Navigator.of(context).pop();
                        showOperatorFilterSheet(context, dimension);
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 52),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 76,
                              child: Text(
                                dimension.title(i18n),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: RdColors.secondary2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                value ?? i18n.t('rd.operators.filter.all'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: value == null
                                      ? FontWeight.w400
                                      : FontWeight.w700,
                                  color: value == null
                                      ? RdColors.muted
                                      : RdColors.text,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: RdColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            RdButton(
              key: const Key('operators-filter-reset'),
              label: i18n.t('operatorsList.filters.reset'),
              height: 48,
              expand: true,
              onPressed: list.clearFilters,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet of one dimension. Single-value dimensions apply and close on a
/// pick; BA tags toggle several values and close with the apply button.
Future<void> showOperatorFilterSheet(
  BuildContext context,
  OperatorFilterDimension dimension,
) {
  return showRdSheet<void>(
    context: context,
    mode: RdSheetMode.sheet,
    sheetMaxWidth: 640,
    builder: (sheetContext) => _DimensionSheet(dimension: dimension),
  );
}

class _DimensionSheet extends ConsumerStatefulWidget {
  const _DimensionSheet({required this.dimension});

  final OperatorFilterDimension dimension;

  @override
  ConsumerState<_DimensionSheet> createState() => _DimensionSheetState();
}

class _DimensionSheetState extends ConsumerState<_DimensionSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final list = ref.watch(operatorsListControllerProvider);
    final dimension = widget.dimension;
    final title = dimension.title(i18n);
    final all = list.filterOptions(dimension, i18n);
    final q = _query.text.trim().toLowerCase();
    final options = dimension.searchable && q.isNotEmpty
        ? all.where((o) => o.label.toLowerCase().contains(q)).toList()
        : all;
    final selectedCount = all.where((o) => o.selected).length;

    return RdSheetFrame(
      semanticLabel: title,
      scrollable: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: RdColors.text,
                  ),
                ),
              ),
              TextButton(
                key: const Key('operators-filter-sheet-clear'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: RdColors.link,
                ),
                onPressed: () {
                  list.clearFilterDimension(dimension);
                  if (!dimension.multi) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(i18n.t('rd.operators.filter.clearSelection')),
              ),
            ],
          ),
          if (dimension.searchable) ...[
            const SizedBox(height: 14),
            _MiniSearch(
              controller: _query,
              height: 44,
              background: RdColors.sheetOption,
              hint: i18n.t('rd.operators.filter.search', {'title': title}),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              dimension.multi
                  ? i18n.t('rd.operators.filter.multiNote')
                  : i18n.t('rd.operators.filter.singleNote', {
                      'count': all.length,
                    }),
              style: RdText.small,
            ),
          ],
          const SizedBox(height: 14),
          if (options.isEmpty)
            Text(i18n.t('rd.operators.filter.noMatch'), style: RdText.muted)
          else
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in options)
                        _OptionButton(
                          key: ValueKey(
                            'operators-filter-option-${option.label}',
                          ),
                          label: option.label,
                          selected: option.selected,
                          height: 44,
                          background: RdColors.sheetOption,
                          onTap: () {
                            if (dimension.multi) {
                              list.applyFilterOption(option);
                              return;
                            }
                            // A pick always selects (the sheet closes).
                            if (!option.selected) {
                              list.applyFilterOption(option);
                            }
                            Navigator.of(context).pop();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (dimension.multi) ...[
            const SizedBox(height: 14),
            RdButton(
              key: const Key('operators-filter-sheet-apply'),
              label: selectedCount > 0
                  ? i18n.t('rd.operators.filter.apply', {
                      'count': selectedCount,
                    })
                  : i18n.t('common.close'),
              variant: RdButtonVariant.primary,
              height: 48,
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }
}
