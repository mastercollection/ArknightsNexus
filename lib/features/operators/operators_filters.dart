import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'operators_list_controller.dart';

/// The four filter dimensions of the operators list (the old filter drawer:
/// rarity, profession, affiliation and BA tags).
enum OperatorFilterDimension { rarity, profession, affiliation, baTags }

extension on OperatorFilterDimension {
  String title(NexusI18n i18n) => switch (this) {
        OperatorFilterDimension.rarity =>
          i18n.t('operatorsList.filters.rarity'),
        OperatorFilterDimension.profession =>
          i18n.t('operatorsList.filters.profession'),
        OperatorFilterDimension.affiliation =>
          i18n.t('operatorsList.filters.affiliation'),
        OperatorFilterDimension.baTags =>
          i18n.t('operatorsList.filters.baTags'),
      };

  String get keyName => switch (this) {
        OperatorFilterDimension.rarity => 'rarity',
        OperatorFilterDimension.profession => 'profession',
        OperatorFilterDimension.affiliation => 'affiliation',
        OperatorFilterDimension.baTags => 'ba-tags',
      };

  bool get multi => this == OperatorFilterDimension.baTags;

  bool get searchable =>
      this == OperatorFilterDimension.affiliation ||
      this == OperatorFilterDimension.baTags;
}

/// One selectable value of a dimension.
class _FilterOption {
  const _FilterOption(this.label, this.selected, this.apply);

  final String label;
  final bool selected;

  /// Selects (single) or toggles (multi) this option.
  final void Function(OperatorsListController list) apply;
}

List<_FilterOption> _optionsOf(
  OperatorFilterDimension dimension,
  OperatorsListController list,
  NexusI18n i18n,
) {
  final filters = list.filters;
  final options = list.options;
  switch (dimension) {
    case OperatorFilterDimension.rarity:
      return [
        for (final rarity in options.rarities)
          _FilterOption(
            '$rarity ★',
            filters.rarity == rarity,
            (list) => list.filters = list.filters.copyWith(
              rarity: () => list.filters.rarity == rarity ? null : rarity,
            ),
          ),
      ];
    case OperatorFilterDimension.profession:
      return [
        for (final profession in options.professions)
          _FilterOption(
            i18n.profession(profession),
            filters.profession == profession,
            (list) => list.filters = list.filters.copyWith(
              profession: () =>
                  list.filters.profession == profession ? null : profession,
            ),
          ),
      ];
    case OperatorFilterDimension.affiliation:
      return [
        for (final affiliation in options.affiliations)
          _FilterOption(
            affiliation,
            filters.affiliation == affiliation,
            (list) => list.filters = list.filters.copyWith(
              affiliation: () =>
                  list.filters.affiliation == affiliation ? null : affiliation,
            ),
          ),
      ];
    case OperatorFilterDimension.baTags:
      return [
        for (final tag in options.baTags)
          _FilterOption(
            tag,
            filters.baTags.contains(tag),
            (list) => list.toggleBaTag(tag),
          ),
      ];
  }
}

/// Selected value(s) of [dimension] as one label, or null when unset.
String? _shownValue(
  OperatorFilterDimension dimension,
  OperatorFilters filters,
  NexusI18n i18n,
) {
  switch (dimension) {
    case OperatorFilterDimension.rarity:
      return filters.rarity == null ? null : '${filters.rarity} ★';
    case OperatorFilterDimension.profession:
      return filters.profession == null
          ? null
          : i18n.profession(filters.profession!);
    case OperatorFilterDimension.affiliation:
      return filters.affiliation;
    case OperatorFilterDimension.baTags:
      final tags = filters.baTags;
      if (tags.isEmpty) {
        return null;
      }
      return tags.length == 1
          ? tags.first
          : i18n.t('rd.operators.chip.more', {
              'value': tags.first,
              'count': tags.length - 1,
            });
  }
}

void _clearDimension(
  OperatorFilterDimension dimension,
  OperatorsListController list,
) {
  list.filters = switch (dimension) {
    OperatorFilterDimension.rarity => list.filters.copyWith(rarity: () => null),
    OperatorFilterDimension.profession =>
      list.filters.copyWith(profession: () => null),
    OperatorFilterDimension.affiliation =>
      list.filters.copyWith(affiliation: () => null),
    OperatorFilterDimension.baTags => list.filters.copyWith(baTags: const []),
  };
}

const _chipOnBorder = RdColors.chipOnBorder;
const _chipOnFill = RdColors.chipOnFill;

/// Rounded-rect toggle button of the filter lists (`aria-pressed`).
class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 34,
    this.background = Colors.transparent,
    this.tag = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final Color background;

  /// BA tag colours (`TAG_ON`) for the selected state.
  final bool tag;

  @override
  Widget build(BuildContext context) {
    final (Color border, Color fill, Color text) = selected
        ? tag
            ? (
                const Color(0xB35EB6FF),
                const Color(0x801C3560),
                const Color(0xFFE0EFFF),
              )
            : (_chipOnBorder, _chipOnFill, RdColors.text)
        : (RdColors.line3, background, RdColors.secondary);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(height >= 44 ? 12 : 10),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(height >= 44 ? 12 : 10),
          onTap: onTap,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: height >= 44 ? 14 : 12),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: height >= 44 ? 14 : 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: text,
                ),
              ),
            ),
          ),
        ),
      ),
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

/// PC filter sidebar: page title, rarity / profession chips, searchable
/// affiliation and BA tag chips, and the reset button.
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

  Widget _group(String title, Widget body, {String? note}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: title,
            children: [
              if (note != null)
                TextSpan(
                  text: ' · $note',
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    color: RdColors.muted,
                  ),
                ),
            ],
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: RdColors.secondary,
          ),
        ),
        const SizedBox(height: 10),
        body,
      ],
    );
  }

  Widget _wrap(List<Widget> children, {double spacing = 8}) {
    return Wrap(spacing: spacing, runSpacing: spacing, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final list = ref.watch(operatorsListControllerProvider);
    final filters = list.filters;

    List<Widget> optionButtons(
      OperatorFilterDimension dimension, {
      String query = '',
    }) {
      final q = query.trim().toLowerCase();
      return [
        for (final option in _optionsOf(dimension, list, i18n))
          if (q.isEmpty ||
              option.selected ||
              option.label.toLowerCase().contains(q))
            _OptionButton(
              key: ValueKey(
                'operators-filter-${dimension.keyName}-${option.label}',
              ),
              label: option.label,
              selected: option.selected,
              tag: dimension == OperatorFilterDimension.baTags,
              onTap: () => option.apply(list),
            ),
      ];
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: RdColors.line)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(i18n.t('rd.operators.eyebrow'), style: RdText.eyebrow),
            const SizedBox(height: 6),
            Semantics(
              header: true,
              child: Text(
                i18n.t('operatorsList.topBar.title'),
                style: RdText.pageTitle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              i18n.t('operatorsList.topBar.description'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: RdColors.muted,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    i18n.t('operatorsList.filters.title'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: RdColors.text,
                    ),
                  ),
                ),
                Text(
                  i18n.t('rd.operators.filterEyebrow'),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.3,
                    color: RdColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _group(
              i18n.t('operatorsList.filters.rarity'),
              _wrap(optionButtons(OperatorFilterDimension.rarity)),
            ),
            const SizedBox(height: 22),
            _group(
              i18n.t('operatorsList.filters.profession'),
              _wrap([
                _OptionButton(
                  key: const ValueKey('operators-filter-profession-all'),
                  label: i18n.t('rd.operators.filter.all'),
                  selected: filters.profession == null,
                  onTap: () => list.filters =
                      list.filters.copyWith(profession: () => null),
                ),
                ...optionButtons(OperatorFilterDimension.profession),
              ]),
            ),
            const SizedBox(height: 22),
            _group(
              i18n.t('operatorsList.filters.affiliation'),
              note: filters.affiliation ?? i18n.t('rd.operators.filter.all'),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MiniSearch(
                    controller: _affiliationQuery,
                    hint: i18n.t('rd.operators.filter.search', {
                      'title': i18n.t('operatorsList.filters.affiliation'),
                    }),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 176),
                    child: SingleChildScrollView(
                      child: _wrap(
                        optionButtons(
                          OperatorFilterDimension.affiliation,
                          query: _affiliationQuery.text,
                        ),
                        spacing: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _group(
              i18n.t('operatorsList.filters.baTags'),
              note: i18n.t('rd.operators.filter.allOf'),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MiniSearch(
                    controller: _tagQuery,
                    hint: i18n.t('rd.operators.filter.search', {
                      'title': i18n.t('operatorsList.filters.baTags'),
                    }),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 210),
                    child: SingleChildScrollView(
                      child: _wrap(
                        optionButtons(
                          OperatorFilterDimension.baTags,
                          query: _tagQuery.text,
                        ),
                        spacing: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: const Color(0x1A5984FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0x52679EFF)),
                ),
                child: InkWell(
                  key: const Key('operators-filter-reset'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: list.clearFilters,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        i18n.t('operatorsList.filters.reset'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: RdColors.linkText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
    // Canvas chips are 36px; phones get 44px touch targets.
    final chipHeight = context.rdLayout == RdLayout.compact ? 44.0 : 36.0;

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
          if (!filters.hasDimension && query.isEmpty)
            Container(
              height: chipHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: RdColors.white5,
                borderRadius: BorderRadius.circular(RdRadii.pill),
              ),
              child: Text(
                i18n.t('operatorsList.states.noFilters'),
                style: const TextStyle(fontSize: 13, color: RdColors.muted),
              ),
            ),
          if (filters.hasDimension)
            pill(
              key: const Key('operators-filter-chip-reset'),
              label: i18n.t('rd.operators.filter.resetShort'),
              on: false,
              onTap: list.clearFilters,
            ),
          if (query.isNotEmpty) ...[
            const SizedBox(width: 8),
            pill(
              label: i18n.t('rd.operators.chip.query', {'value': query}),
              on: true,
              mark: '✕',
              semanticLabel:
                  i18n.t('rd.operators.chip.clearQuery', {'value': query}),
              onTap: onClearQuery,
            ),
          ],
          for (final dimension in OperatorFilterDimension.values) ...[
            const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final title = dimension.title(i18n);
                final value = _shownValue(dimension, filters, i18n);
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
                      ? () => _clearDimension(dimension, list)
                      : () => showOperatorFilterSheet(context, dimension),
                );
              },
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
              i18n.t('rd.operators.filterEyebrow'),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                color: RdColors.muted,
              ),
            ),
            const SizedBox(height: 2),
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
                  final value = _shownValue(dimension, list.filters, i18n);
                  return Material(
                    color: RdColors.sheetOption,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: RdColors.white10),
                    ),
                    child: InkWell(
                      key: Key('operators-filter-row-${dimension.keyName}'),
                      borderRadius: BorderRadius.circular(14),
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
    final all = _optionsOf(dimension, list, i18n);
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
                  _clearDimension(dimension, list);
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
                              option.apply(list);
                              return;
                            }
                            // A pick always selects (the sheet closes).
                            if (!option.selected) {
                              option.apply(list);
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
                  : i18n.t('rd.operators.filter.close'),
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
