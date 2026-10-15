import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'operator_detail_view.dart';
import 'operators_filters.dart';
import 'operators_list_controller.dart';
import 'operators_list_view.dart';

/// PC master-detail (expanded width): filter sidebar | list | detail pane.
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
          list.operatorList.length,
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
    final chips = list.activeChips(i18n);
    final count = list.isLoading || list.errorMessage.isNotEmpty
        ? ''
        : i18n.t('rd.operators.count', {'count': list.operatorList.length});

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              RdSearchField(
                controller: _search,
                height: 48,
                hintText: i18n.t('operatorsList.search.placeholder'),
                onChanged: list.setQuery,
                trailing:
                    count.isEmpty ? null : Text(count, style: RdText.muted),
              ),
              Semantics(
                container: true,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in chips) _ActiveChip(chip),
                    if (chips.isEmpty)
                      _ActiveChip(
                        i18n.t('operatorsList.states.noFilters'),
                        muted: true,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: OperatorsGridView(
            compact: false,
            selectedId: widget.selectedId,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
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
                style: const TextStyle(fontSize: 14, color: RdColors.muted),
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
          const sidebar = 240.0;
          final rest = constraints.maxWidth - sidebar;
          final paneWidth = (rest * 0.5).clamp(440.0, 640.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: sidebar, child: OperatorsFilterSidebar()),
              Expanded(child: main),
              Container(
                width: paneWidth,
                decoration: const BoxDecoration(
                  color: RdColors.rail,
                  border: Border(left: BorderSide(color: RdColors.line)),
                ),
                child: pane,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip(this.label, {this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: muted ? RdColors.white5 : RdColors.line2,
        borderRadius: BorderRadius.circular(RdRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: muted ? RdColors.muted : RdColors.body,
        ),
      ),
    );
  }
}
