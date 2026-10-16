import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'operators_filters.dart';
import 'operators_list_controller.dart';
import 'operators_list_view.dart';
import 'operators_workspace.dart';

/// `/operators` (port of `src/pages/operators.vue`, redesigned).
///
/// Expanded width: the PC master-detail [OperatorsWorkspace] with nothing
/// selected. Narrower: the list page with a condensing header, filter chips
/// and filter sheets; tapping an operator pushes its detail page.
class OperatorsScreen extends ConsumerStatefulWidget {
  const OperatorsScreen({this.initialQuery, super.key});

  static const routeName = 'operators';

  /// `?q=` from the home search.
  final String? initialQuery;

  @override
  ConsumerState<OperatorsScreen> createState() => _OperatorsScreenState();
}

class _OperatorsScreenState extends ConsumerState<OperatorsScreen> {
  @override
  void initState() {
    super.initState();
    final list = ref.read(operatorsListControllerProvider);
    // A fresh `?q=` replaces the search; returning without one (PC
    // deselect) keeps the current search like the Vue child route.
    // Runs during the build phase, so it must not notify listeners.
    if (widget.initialQuery != null) {
      list.setQuery(widget.initialQuery!, notify: false);
    }
    list.ensureLoaded();
  }

  @override
  void didUpdateWidget(OperatorsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `watch(() => route.query.q)`.
    if (oldWidget.initialQuery != widget.initialQuery) {
      final query = widget.initialQuery ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(operatorsListControllerProvider).setQuery(query);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the shared list state alive while this page is mounted.
    ref.watch(operatorsListControllerProvider.select((_) => 0));
    if (context.rdLayout == RdLayout.expanded) {
      return const OperatorsWorkspace();
    }
    return const OperatorsListPage();
  }
}

/// Phone / tablet list page.
class OperatorsListPage extends ConsumerStatefulWidget {
  const OperatorsListPage({super.key});

  @override
  ConsumerState<OperatorsListPage> createState() => _OperatorsListPageState();
}

class _OperatorsListPageState extends ConsumerState<OperatorsListPage> {
  late final TextEditingController _search;

  // Condensed header state (mirrors `handleScroll` in operators.vue).
  bool _isCondensed = false;
  double _lastScrollY = 0;
  double _upwardTravel = 0;
  double _downwardTravel = 0;
  int _lockUntil = 0;

  @override
  void initState() {
    super.initState();
    final list = ref.read(operatorsListControllerProvider);
    _search = TextEditingController(text: list.filters.query);
    _lastScrollY = list.scrollOffset;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Condenses after scrollY > 140 with 52px of downward travel, expands
  /// after 56px of upward travel or near the top; 220ms lock per toggle.
  void _handleScroll(double currentScrollY) {
    // Frame time rather than a wall clock: the lock follows the animation
    // clock, which tests drive.
    final now =
        SchedulerBinding.instance.currentSystemFrameTimeStamp.inMilliseconds;
    final delta = currentScrollY - _lastScrollY;
    if (delta > 0) {
      _downwardTravel += delta;
      _upwardTravel = 0;
    } else if (delta < 0) {
      _upwardTravel += delta.abs();
      _downwardTravel = 0;
    }

    var condensed = _isCondensed;
    if (currentScrollY < 48) {
      condensed = false;
      _upwardTravel = 0;
      _downwardTravel = 0;
    } else if (now < _lockUntil) {
      _lastScrollY = currentScrollY;
      return;
    } else if (!condensed && currentScrollY > 140 && _downwardTravel > 52) {
      condensed = true;
      _lockUntil = now + 220;
      _upwardTravel = 0;
      _downwardTravel = 0;
    } else if (condensed && (currentScrollY < 56 || _upwardTravel > 56)) {
      condensed = false;
      _lockUntil = now + 220;
      _upwardTravel = 0;
      _downwardTravel = 0;
    }
    _lastScrollY = currentScrollY;
    if (condensed != _isCondensed) {
      setState(() => _isCondensed = condensed);
    }
  }

  void _clearQuery() {
    _search.clear();
    ref.read(operatorsListControllerProvider).setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final list = ref.watch(operatorsListControllerProvider);
    if (_search.text != list.filters.query) {
      _search.value = TextEditingValue(
        text: list.filters.query,
        selection: TextSelection.collapsed(offset: list.filters.query.length),
      );
    }
    final compact = context.rdLayout == RdLayout.compact;
    final hasDimension = list.filters.hasDimension;
    final count = list.isLoading || list.errorMessage.isNotEmpty
        ? ''
        : i18n.t('rd.operators.count', {'count': list.operatorList.length});
    final side = compact ? 12.0 : rdPagePadding(context).left;

    final header = Container(
      padding: EdgeInsets.fromLTRB(side, 10, side, 10),
      decoration: const BoxDecoration(
        color: RdColors.header,
        border: Border(bottom: BorderSide(color: RdColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // A section root: no back button (Esc, the mouse back button
                // and Android back climb through the shell).
                const SizedBox(width: 4),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      i18n.t('operatorsList.topBar.title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: compact ? RdText.mobileTitle : RdText.pageTitle,
                    ),
                  ),
                ),
                if (count.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(count, style: RdText.muted),
                ],
                const SizedBox(width: 6),
                RdIconButton(
                  key: const Key('operators-filter-button'),
                  icon: Icons.filter_alt_outlined,
                  tooltip: i18n.t('operatorsList.filters.title'),
                  filled: false,
                  active: hasDimension,
                  onPressed: () => showOperatorFiltersSheet(context),
                ),
              ],
            ),
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                heightFactor: _isCondensed ? 0 : 1,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isCondensed ? 0 : 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ExcludeFocus(
                          excluding: _isCondensed,
                          child: RdSearchField(
                            controller: _search,
                            hintText:
                                i18n.t('operatorsList.search.placeholder'),
                            onChanged: list.setQuery,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OperatorsFilterChipRow(onClearQuery: _clearQuery),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: RdColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: OperatorsGridView(
              compact: true,
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : side,
                14,
                compact ? 16 : side,
                24,
              ),
              onScroll: _handleScroll,
              onSelect: (operator) => context.push('/operators/${operator.id}'),
            ),
          ),
        ],
      ),
    );
  }
}
