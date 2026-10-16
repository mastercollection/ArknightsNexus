import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'operator_detail_view.dart';
import '../shared/region_operator_counts.dart';
import 'operators_filters.dart';
import 'operators_list_controller.dart';
import 'operators_list_view.dart';

/// Window width from which the operators section is a master-detail
/// workspace (list next to the detail pane) instead of pushing the detail
/// page. Lower than [RdBreakpoints.expanded]: below that the filter sidebar
/// folds into a filter button, so the list and the pane fit side by side.
const operatorsMasterDetailWidth = 1000.0;

/// Whether `/operators` and `/operators/:id` render [OperatorsWorkspace].
bool operatorsMasterDetail(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= operatorsMasterDetailWidth;

/// PC master-detail: filter sidebar (expanded width only) | list | detail
/// pane.
///
/// Both `/operators` and `/operators/:id` render this widget; the selection
/// is the route, so picking an operator uses `context.go` (the stack does
/// not grow, and `/operators/a` -> `/operators/b` keeps the same page so the
/// detail state carries over). List state is shared through
/// [operatorsListControllerProvider].
class OperatorsWorkspace extends ConsumerStatefulWidget {
  const OperatorsWorkspace({this.selectedId, super.key});

  final String? selectedId;

  @override
  ConsumerState<OperatorsWorkspace> createState() => _OperatorsWorkspaceState();
}

class _OperatorsWorkspaceState extends ConsumerState<OperatorsWorkspace> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    final list = ref.read(operatorsListControllerProvider);
    _search = TextEditingController(text: list.filters.query);
    list.ensureLoaded();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    // The grid and the sidebar watch the list themselves; this frame only
    // needs what its header shows, so paging the grid (`loadMore`) does not
    // rebuild the detail pane.
    ref.watch(
      operatorsListControllerProvider.select(
        (list) => (
          list.filters,
          list.isLoading,
          list.errorMessage,
          list.counts,
        ),
      ),
    );
    final list = ref.read(operatorsListControllerProvider);
    // Keep the field in sync when the query changes elsewhere (?q=).
    if (_search.text != list.filters.query) {
      _search.value = TextEditingValue(
        text: list.filters.query,
        selection: TextSelection.collapsed(offset: list.filters.query.length),
      );
    }
    // Expanded windows get the filter sidebar; narrower ones carry the
    // title, a filter button and the phone chip row over the list instead.
    final withSidebar = context.rdLayout == RdLayout.expanded;
    final count = list.isLoading || list.errorMessage.isNotEmpty
        ? ''
        : formatOperatorCounts(i18n, list.counts);
    final search = RdSearchField(
      controller: _search,
      height: withSidebar ? 44 : 42,
      hintText: i18n.t('operatorsList.search.placeholder'),
      onChanged: list.setQuery,
      trailing: count.isEmpty
          ? null
          : Text(
              count,
              key: const Key('operators-count'),
              style: const TextStyle(fontSize: 12, color: RdColors.text2),
            ),
    );

    final Widget top;
    if (withSidebar) {
      final chips = list.activeChips(i18n);
      top = Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            search,
            Semantics(
              container: true,
              child: chips.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        i18n.t('operatorsList.states.noFilters'),
                        style: RdText.small,
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final chip in chips) _ActiveChip(chip)],
                    ),
            ),
          ],
        ),
      );
    } else {
      top = Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      i18n.t('operatorsList.topBar.title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RdText.pageTitle,
                    ),
                  ),
                ),
                RdIconButton(
                  key: const Key('operators-filter-button'),
                  icon: Icons.filter_alt_outlined,
                  tooltip: i18n.t('operatorsList.filters.title'),
                  size: 40,
                  active: list.filters.hasDimension,
                  onPressed: () => showOperatorFiltersSheet(context),
                ),
              ],
            ),
            search,
            OperatorsFilterChipRow(
              onClearQuery: () {
                _search.clear();
                list.setQuery('');
              },
            ),
          ],
        ),
      );
    }

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        const SizedBox(height: 12),
        Expanded(
          child: OperatorsGridView(
            compact: false,
            selectedId: widget.selectedId,
            padding: EdgeInsets.fromLTRB(
              withSidebar ? 20 : 16,
              2,
              withSidebar ? 20 : 16,
              24,
            ),
            onSelect: (operator) => context.go('/operators/${operator.id}'),
          ),
        ),
      ],
    );

    final selectedId = widget.selectedId;
    final pane = selectedId == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                i18n.t('rd.operators.detail.none'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: RdColors.text3),
              ),
            ),
          )
        : OperatorDetailView(
            operatorId: selectedId,
            mode: OperatorDetailMode.pane,
            onBack: () => context.go('/operators'),
          );

    return Material(
      color: RdColors.bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sidebar = withSidebar ? 240.0 : 0.0;
          final rest = constraints.maxWidth - sidebar;
          final bounds =
              withSidebar ? _PaneBounds.wide(rest) : _PaneBounds.narrow(rest);
          final paneWidth =
              (ref.watch(operatorDetailPaneWidthProvider) ?? bounds.initial)
                  .clamp(bounds.min, bounds.max);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (withSidebar)
                SizedBox(
                  width: sidebar,
                  child: const DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: RdColors.border),
                      ),
                    ),
                    child: OperatorsFilterSidebar(),
                  ),
                ),
              Expanded(child: main),
              _PaneResizeHandle(
                label: i18n.t('rd.operators.detail.resize'),
                width: paneWidth,
                bounds: bounds,
                onChanged: (width) => ref
                    .read(operatorDetailPaneWidthProvider.notifier)
                    .state = width,
              ),
              Container(
                width: paneWidth,
                color: RdColors.surface1,
                child: pane,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Width the user dragged the PC detail pane to; `null` until they do, so
/// the pane starts at [_PaneBounds.initial]. Kept for the session, so it
/// survives leaving and reopening the operators section.
final operatorDetailPaneWidthProvider = StateProvider<double?>((ref) => null);

/// Limits of the detail pane for the width left next to the filter sidebar
/// (or the rail): the list keeps a minimum width, the pane at least
/// [_minPane].
class _PaneBounds {
  const _PaneBounds(this.min, this.max, this.initial);

  /// With the sidebar: the pane starts at half the room, up to 720px; the
  /// list keeps 320px.
  factory _PaneBounds.wide(double available) {
    final max = _max(available, 320);
    return _PaneBounds(
      _minPane,
      max,
      (available * 0.5).clamp(_minPane, 720.0).clamp(_minPane, max),
    );
  }

  /// Without the sidebar (narrower windows): the list starts at 404px and
  /// keeps 360px.
  factory _PaneBounds.narrow(double available) {
    // The 9px resize handle sits between the list and the pane.
    final max = _max(available, 360 + 9);
    return _PaneBounds(
      _minPane,
      max,
      (available - 404 - 9).clamp(_minPane, max),
    );
  }

  static double _max(double available, double minList) =>
      (available - minList).clamp(_minPane, double.infinity);

  static const _minPane = 400.0;

  final double min;
  final double max;
  final double initial;
}

/// Draggable border between the list and the detail pane. Double-click
/// restores the initial width; with keyboard focus the arrow keys move it.
class _PaneResizeHandle extends StatefulWidget {
  const _PaneResizeHandle({
    required this.label,
    required this.width,
    required this.bounds,
    required this.onChanged,
  });

  final String label;
  final double width;
  final _PaneBounds bounds;
  final ValueChanged<double?> onChanged;

  @override
  State<_PaneResizeHandle> createState() => _PaneResizeHandleState();
}

class _PaneResizeHandleState extends State<_PaneResizeHandle> {
  static const _step = 24.0;

  bool _hovered = false;
  bool _dragging = false;
  bool _focused = false;

  void _resizeBy(double delta) {
    widget.onChanged(
      (widget.width + delta).clamp(widget.bounds.min, widget.bounds.max),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _dragging || _focused;
    return Semantics(
      label: widget.label,
      value: '${widget.width.round()}',
      increasedValue: '${(widget.width + _step).round()}',
      decreasedValue: '${(widget.width - _step).round()}',
      onIncrease: () => _resizeBy(_step),
      onDecrease: () => _resizeBy(-_step),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        mouseCursor: SystemMouseCursors.resizeColumn,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft): _GrowIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight): _ShrinkIntent(),
        },
        actions: {
          _GrowIntent: CallbackAction<_GrowIntent>(
            onInvoke: (_) => _resizeBy(_step),
          ),
          _ShrinkIntent: CallbackAction<_ShrinkIntent>(
            onInvoke: (_) => _resizeBy(-_step),
          ),
        },
        child: GestureDetector(
          key: const Key('operator-detail-resize'),
          behavior: HitTestBehavior.opaque,
          // Track from the press point so the border stays under the cursor.
          dragStartBehavior: DragStartBehavior.down,
          // The pane is on the right, so dragging left widens it.
          onHorizontalDragStart: (_) => setState(() => _dragging = true),
          onHorizontalDragUpdate: (details) => _resizeBy(-details.delta.dx),
          onHorizontalDragEnd: (_) => setState(() => _dragging = false),
          onHorizontalDragCancel: () => setState(() => _dragging = false),
          onDoubleTap: () => widget.onChanged(null),
          child: SizedBox(
            width: 9,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: active ? 3 : 1,
                color: active ? RdColors.accent : RdColors.line,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GrowIntent extends Intent {
  const _GrowIntent();
}

class _ShrinkIntent extends Intent {
  const _ShrinkIntent();
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: RdColors.surface2,
        borderRadius: BorderRadius.circular(RdRadii.chip),
        border: Border.all(color: RdColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: RdColors.text2),
      ),
    );
  }
}
