import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/item.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/item_service.dart';
import '../../ui/nexus_ui.dart'
    show ItemIcon, NexusMessageType, showNexusMessage;
import '../../ui/redesign/rd_widgets.dart';
import 'item_format.dart';
import 'owned_count_editor.dart';

/// Port of `src/pages/items.vue`, laid out after the redesign boards
/// (`PcItems` / `MItems`): a header bar with search and JSON import, kind
/// tabs (chips on phones), and compact tiles grouped into sections (by kind
/// under "all", by tier for materials and tokens). Tiles are revealed
/// incrementally because the list is long.
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  static const routeName = 'items';

  /// `useInfiniteSlice(filteredItems, { initialCount: 48, batchSize: 30 })`.
  static const initialCount = 48;
  static const batchSize = 30;

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

/// One titled block of tiles. [title] is null for the single untitled
/// section of a kind without sub-sections.
class _ItemSection {
  const _ItemSection(this.title, this.items);

  final String? title;
  final List<ItemEntry> items;
}

/// A row of the list sliver: a section header or up to `columns` tiles.
class _ListRow {
  const _ListRow.header(_ItemSection this.section)
      : items = const [],
        first = false;
  const _ListRow.tiles(this.items, {required this.first}) : section = null;

  final _ItemSection? section;
  final List<ItemEntry> items;

  /// First tile row of its section (no top gap below the header).
  final bool first;
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  final _searchController = TextEditingController();
  final _slice = InfiniteSlice(
    initialCount: ItemsScreen.initialCount,
    batchSize: ItemsScreen.batchSize,
  );
  final _savingItemIds = ValueNotifier<Set<String>>(const {});
  final _editorKey = GlobalKey<OwnedCountEditorState>();

  List<ItemEntry> _items = const [];

  /// Kinds present in the region's data, in tab order.
  List<ItemKind> _kinds = const [];
  Map<String, ItemKind> _kindById = const {};

  /// Items matching the search, of every kind (tab counts).
  List<ItemEntry> _searchedItems = const [];

  /// Sections of the selected tab, and their items in display order.
  List<_ItemSection> _sections = const [];
  List<ItemEntry> _filteredItems = const [];

  /// Selected tab; null is "all".
  ItemKind? _kind;
  String _searchQuery = '';
  bool _isLoading = true;
  String _errorMessage = '';
  bool _loadMoreScheduled = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(regionProvider, (_, __) => unawaited(_loadItems()));
    ref.listenManual(dataRevisionProvider, (_, __) => unawaited(_loadItems()));
    unawaited(_loadItems());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _savingItemIds.dispose();
    super.dispose();
  }

  ItemQuery _query() => ItemQuery(
        region: ref.read(regionProvider),
        classifyType: 'MATERIAL',
      );

  Future<void> _loadItems() async {
    final token = ++_loadToken;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final result = await ref.read(itemServiceProvider).listItems(_query());
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() => _setItems(result));
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('items list load failed', error, stackTrace);
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _setItems(const []);
        _errorMessage = '$error';
      });
    } finally {
      if (mounted && token == _loadToken) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Re-reads the owned counts (after a detail page, which edits them too)
  /// without resetting the revealed tiles.
  Future<void> _refreshOwnedCounts() async {
    final token = _loadToken;
    try {
      final result = await ref.read(itemServiceProvider).listItems(_query());
      if (!mounted || token != _loadToken || _isLoading) {
        return;
      }
      final counts = {for (final item in result) item.itemId: item.ownedCount};
      final changed = _items.any(
        (item) => (counts[item.itemId] ?? item.ownedCount) != item.ownedCount,
      );
      if (!changed) {
        return;
      }
      setState(() {
        _items = [
          for (final item in _items)
            item.copyWith(ownedCount: counts[item.itemId] ?? item.ownedCount),
        ];
        _refilter(keepRevealed: true);
      });
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('items count refresh failed', error, stackTrace);
    }
  }

  void _setItems(List<ItemEntry> items) {
    _items = items;
    _kindById = {for (final item in items) item.itemId: itemKindOf(item)};
    final present = _kindById.values.toSet();
    _kinds = [
      for (final kind in ItemKind.values)
        if (present.contains(kind)) kind,
    ];
    if (_kind != null && !present.contains(_kind)) {
      _kind = null;
    }
    _refilter();
  }

  ItemKind _kindOf(ItemEntry item) => _kindById[item.itemId] ?? ItemKind.other;

  /// `filteredItems` + `watch(filteredItems, resetVisibleItems)`, then the
  /// kind tab and its sections. [keepRevealed] keeps the revealed count
  /// (owned counts changed, the filter did not).
  void _refilter({bool keepRevealed = false}) {
    final query = _searchQuery.trim().toLowerCase();
    _searchedItems = query.isEmpty
        ? _items
        : _items.where((item) {
            return [
              item.name,
              item.description,
              item.usage,
              item.obtainApproach,
              item.classifyType,
              item.itemType,
              item.itemId,
            ]
                .where((value) => value.isNotEmpty)
                .any((value) => value.toLowerCase().contains(query));
          }).toList();
    _sections = _buildSections();
    _filteredItems = [
      for (final section in _sections) ...section.items,
    ];
    final revealed = _slice.visibleCount;
    _slice.reset(_filteredItems.length);
    if (keepRevealed) {
      _slice.visibleCount =
          revealed < _filteredItems.length ? revealed : _filteredItems.length;
    }
  }

  List<_ItemSection> _buildSections() {
    final i18n = ref.read(i18nProvider);
    final kind = _kind;
    if (kind == null) {
      return [
        for (final kind in _kinds)
          if (_searchedItems.any((item) => _kindOf(item) == kind))
            _ItemSection(
              _kindLabel(i18n, kind),
              [
                for (final item in _searchedItems)
                  if (_kindOf(item) == kind) item,
              ],
            ),
      ];
    }
    final ofKind = [
      for (final item in _searchedItems)
        if (_kindOf(item) == kind) item,
    ];
    if (ofKind.isEmpty) {
      return const [];
    }
    if (!itemKindHasTierSections(kind)) {
      return [_ItemSection(null, ofKind)];
    }
    final tiers = {for (final item in ofKind) itemTierOf(item)}.toList()
      ..sort((a, b) => b.compareTo(a));
    return [
      for (final tier in tiers)
        _ItemSection(
          tier > 0 ? 'T$tier' : _kindLabel(i18n, kind),
          [
            for (final item in ofKind)
              if (itemTierOf(item) == tier) item,
          ],
        ),
    ];
  }

  void _setSearch(String value) {
    setState(() {
      _searchQuery = value;
      _refilter();
    });
  }

  void _setKind(ItemKind? kind) {
    if (kind == _kind) {
      return;
    }
    setState(() {
      _kind = kind;
      _refilter();
    });
  }

  int _countOf(ItemKind? kind) => kind == null
      ? _searchedItems.length
      : _searchedItems.where((item) => _kindOf(item) == kind).length;

  void _loadMore() {
    setState(() => _slice.loadMore(_filteredItems.length));
  }

  /// The footer is built when it comes within the scroll cache extent, like
  /// the IntersectionObserver sentinel with its 240px root margin.
  void _scheduleLoadMore() {
    if (_loadMoreScheduled) {
      return;
    }
    _loadMoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreScheduled = false;
      if (!mounted) {
        return;
      }
      _loadMore();
    });
  }

  Future<void> _openDetail(String itemId) async {
    await context.push('/items/$itemId');
    if (mounted) {
      await _refreshOwnedCounts();
    }
  }

  ItemEntry? _itemById(String itemId) {
    for (final item in _items) {
      if (item.itemId == itemId) {
        return item;
      }
    }
    return null;
  }

  void _replaceOwnedCount(String itemId, int count) {
    setState(() {
      _items = [
        for (final item in _items)
          item.itemId == itemId ? item.copyWith(ownedCount: count) : item,
      ];
      // Owned counts are not part of the filter, so `filteredItems` keeps its
      // identity in Vue and the revealed rows are not reset.
      _refilter(keepRevealed: true);
    });
  }

  bool _isSaving(String itemId) => _savingItemIds.value.contains(itemId);

  void _setItemSaving(String itemId, bool saving) {
    final next = {..._savingItemIds.value};
    if (saving) {
      next.add(itemId);
    } else {
      next.remove(itemId);
    }
    _savingItemIds.value = next;
  }

  /// `updateOwnedCount`: optimistic write, per-item saving lock, rollback and
  /// error toast on failure.
  Future<void> _updateOwnedCount(String itemId, int nextValue) async {
    final item = _itemById(itemId);
    if (item == null) {
      return;
    }
    final normalized = nextValue < 0 ? 0 : nextValue;
    final previous = item.ownedCount;
    if (normalized == previous || _isSaving(itemId)) {
      return;
    }

    _replaceOwnedCount(itemId, normalized);
    _setItemSaving(itemId, true);
    try {
      final saved = await ref
          .read(userDataServiceProvider)
          .saveUserItemCount(itemId, normalized);
      if (mounted) {
        _replaceOwnedCount(itemId, saved);
      }
    } catch (error) {
      if (mounted) {
        _replaceOwnedCount(itemId, previous);
        showNexusMessage(context, '$error', type: NexusMessageType.error);
      }
    } finally {
      _setItemSaving(itemId, false);
    }
  }

  /// Owned-count dialog (bottom sheet on phones). Closing commits the draft
  /// first; a close requested while a save is running is queued and runs
  /// as soon as that save settles (Android back and Esc included).
  Future<void> _openOwnedCountEditor(ItemEntry item) async {
    final i18n = ref.read(i18nProvider);
    final locked = ValueNotifier<bool>(_isSaving(item.itemId));
    BuildContext? dialogContext;
    var closeQueued = false;

    void onSavingChanged() {
      final saving = _isSaving(item.itemId);
      locked.value = saving;
      if (!saving && closeQueued) {
        closeQueued = false;
        final target = dialogContext;
        if (target != null && target.mounted) {
          Navigator.of(target).pop();
        }
      }
    }

    _savingItemIds.addListener(onSavingChanged);
    try {
      await showRdSheet<void>(
        context: context,
        barrierLabel: i18n.t('common.close'),
        maxWidth: 420,
        enableDrag: false,
        builder: (_) => RdSheetFrame(
          title:
              item.name.isEmpty ? i18n.t('itemsPage.topBar.title') : item.name,
          closeLabel: i18n.t('common.close'),
          header: context.rdLayout == RdLayout.compact
              ? OwnedCountEditorHeader(
                  item: item,
                  currentCountLabel: i18n.t('itemsPage.editor.currentCount'),
                )
              : null,
          closeLocked: locked,
          onCloseRequest: () async {
            if (_isSaving(item.itemId)) {
              closeQueued = true;
              return false;
            }
            await _editorKey.currentState?.commit();
            if (_isSaving(item.itemId)) {
              closeQueued = true;
              return false;
            }
            return true;
          },
          sheetMaxHeightFactor: 0.92,
          child: Builder(
            builder: (context) {
              dialogContext = context;
              return OwnedCountEditor(
                key: _editorKey,
                item: item,
                currentCountLabel: i18n.t('itemsPage.editor.currentCount'),
                savingItemIds: _savingItemIds,
                showItemHeader: context.rdLayout != RdLayout.compact,
                onCommit: (value) => _updateOwnedCount(item.itemId, value),
              );
            },
          ),
        ),
      );
    } finally {
      _savingItemIds.removeListener(onSavingChanged);
      locked.dispose();
    }
  }

  Future<void> _openImportDialog() async {
    final i18n = ref.read(i18nProvider);
    final importing = ValueNotifier<bool>(false);
    await showRdSheet<void>(
      context: context,
      barrierLabel: i18n.t('common.close'),
      maxWidth: 560,
      enableDrag: false,
      builder: (_) => RdSheetFrame(
        title: i18n.t('itemsPage.importDialog.title'),
        closeLabel: i18n.t('common.close'),
        closeLocked: importing,
        onCloseRequest: () async => !importing.value,
        sheetMaxHeightFactor: 0.92,
        child: Builder(
          builder: (dialogContext) => _ItemCountImportForm(
            importing: importing,
            onCancel: () {
              if (!importing.value) {
                Navigator.of(dialogContext).pop();
              }
            },
            onSubmit: (payload) async {
              if (importing.value) {
                return;
              }
              importing.value = true;
              try {
                final importedCount = await ref
                    .read(userDataServiceProvider)
                    .importUserItemCounts(payload);
                await _loadItems();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (mounted) {
                  showNexusMessage(
                    context,
                    ref.read(i18nProvider).t(
                      'itemsPage.messages.importSuccess',
                      {'count': importedCount},
                    ),
                    type: NexusMessageType.success,
                  );
                }
              } catch (error) {
                if (mounted) {
                  showNexusMessage(
                    context,
                    '$error',
                    type: NexusMessageType.error,
                  );
                }
              } finally {
                importing.value = false;
              }
            },
          ),
        ),
      ),
    );
    importing.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final compact = context.rdLayout == RdLayout.compact;
    final title = i18n.t('rd.items.title');
    final importLabel = i18n.t('itemsPage.actions.importJson');
    final search = RdSearchField(
      controller: _searchController,
      hintText: i18n.t('itemsPage.search.placeholder'),
      height: compact ? 44 : 40,
      onChanged: _setSearch,
    );
    final tabs = [
      _KindTabData(
        null,
        _kindLabel(i18n, null),
        _countOf(null),
      ),
      for (final kind in _kinds)
        _KindTabData(kind, _kindLabel(i18n, kind), _countOf(kind)),
    ];
    final header = compact
        ? _CompactHeader(
            title: title,
            importLabel: importLabel,
            onImport: _openImportDialog,
            search: search,
            tabsLabel: i18n.t('rd.items.kindTabs'),
            tabs: tabs,
            selected: _kind,
            onSelect: _setKind,
          )
        : _WideHeader(
            title: title,
            importLabel: importLabel,
            onImport: _openImportDialog,
            search: search,
            tabsLabel: i18n.t('rd.items.kindTabs'),
            tabs: tabs,
            selected: _kind,
            onSelect: _setKind,
          );

    return Material(
      color: RdColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: compact
                      ? const EdgeInsets.fromLTRB(16, 16, 16, 24)
                      : const EdgeInsets.fromLTRB(32, 20, 32, 32),
                  sliver: _buildContent(i18n, compact),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(NexusI18n i18n, bool compact) {
    if (_errorMessage.isNotEmpty) {
      return SliverToBoxAdapter(
        child: RdStatePanel(
          kind: RdStateKind.error,
          layout: RdStateLayout.left,
          title: i18n.t('itemsPage.states.error'),
          message: _errorMessage,
        ),
      );
    }
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Semantics(
          label: i18n.t('itemsPage.states.loading'),
          child: _LoadingGrid(compact: compact),
        ),
      );
    }
    if (_filteredItems.isEmpty) {
      return SliverToBoxAdapter(
        child: RdStatePanel(
          kind: RdStateKind.empty,
          layout: RdStateLayout.left,
          title: i18n.t('itemsPage.states.empty'),
        ),
      );
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) => _buildItemRows(
        i18n,
        compact,
        _columnsFor(constraints.crossAxisExtent, compact),
      ),
    );
  }

  /// Section headers and tile rows of the revealed part of the list.
  List<_ListRow> _rowsFor(int columns, int visible) {
    final rows = <_ListRow>[];
    var budget = visible;
    for (final section in _sections) {
      if (budget <= 0) {
        break;
      }
      if (section.title != null) {
        rows.add(_ListRow.header(section));
      }
      final shown =
          section.items.length < budget ? section.items.length : budget;
      budget -= shown;
      for (var start = 0; start < shown; start += columns) {
        final end = start + columns < shown ? start + columns : shown;
        rows.add(
          _ListRow.tiles(
            section.items.sublist(start, end),
            first: start == 0,
          ),
        );
      }
    }
    return rows;
  }

  Widget _buildItemRows(NexusI18n i18n, bool compact, int columns) {
    final total = _filteredItems.length;
    final visible = _slice.visibleLength(total);
    final rows = _rowsFor(columns, visible);
    final hasMore = _slice.hasMore(total);
    final gap = compact ? 8.0 : 10.0;
    final sectionGap = compact ? 20.0 : 24.0;
    return SliverList.builder(
      itemCount: rows.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == rows.length) {
          _scheduleLoadMore();
          return Padding(
            padding: EdgeInsets.only(top: sectionGap),
            child: _LoadMoreFooter(
              compact: compact,
              hint: i18n.t('rd.items.loadMoreHint'),
              progress: i18n.t(
                'rd.items.progress',
                {'shown': visible, 'total': total},
              ),
              buttonLabel: i18n.t('rd.items.loadMore'),
              onLoadMore: _loadMore,
            ),
          );
        }
        final row = rows[index];
        final section = row.section;
        if (section != null) {
          return Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : sectionGap),
            child: _SectionHeader(
              title: section.title!,
              count: section.items.length,
            ),
          );
        }
        final cells = <Widget>[];
        for (var i = 0; i < columns; i++) {
          if (i > 0) {
            cells.add(SizedBox(width: gap));
          }
          if (i >= row.items.length) {
            cells.add(const Expanded(child: SizedBox.shrink()));
            continue;
          }
          final item = row.items[i];
          cells.add(
            Expanded(
              child: _ItemTile(
                key: ValueKey(item.itemId),
                item: item,
                compact: compact,
                openLabel: i18n.t('rd.items.openItem', {'name': item.name}),
                editLabel: i18n.t('rd.items.editCount', {'name': item.name}),
                onOpen: () => unawaited(_openDetail(item.itemId)),
                onEditCount: () => _openOwnedCountEditor(item),
              ),
            ),
          );
        }
        final double top;
        if (index == 0) {
          top = 0;
        } else if (row.first) {
          // Below a section header, or the first row of an untitled section.
          top = rows[index - 1].section != null ? 10 : sectionGap;
        } else {
          top = gap;
        }
        return Padding(
          padding: EdgeInsets.only(top: top),
          child: Row(children: cells),
        );
      },
    );
  }
}

String _kindLabel(NexusI18n i18n, ItemKind? kind) =>
    i18n.t('rd.items.kind.${kind?.name ?? 'all'}');

/// Six 72px-high tiles per row at 1440px (`minmax(180px, 1fr)` with a 10px
/// gap) on PC; four columns on phones.
int _columnsFor(double width, bool compact) {
  if (compact) {
    return 4;
  }
  return rdAutoColumns(width, 180, gap: 10);
}

/// A kind tab: [kind] null is "all".
class _KindTabData {
  const _KindTabData(this.kind, this.label, this.count);

  final ItemKind? kind;
  final String label;
  final int count;
}

/// PC header bar (`PcItems`): surface-1, full width, title with the search
/// box and the import button, and the underlined kind tabs below.
class _WideHeader extends StatelessWidget {
  const _WideHeader({
    required this.title,
    required this.importLabel,
    required this.onImport,
    required this.search,
    required this.tabsLabel,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final String importLabel;
  final VoidCallback onImport;
  final Widget search;
  final String tabsLabel;
  final List<_KindTabData> tabs;
  final ItemKind? selected;
  final ValueChanged<ItemKind?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      decoration: const BoxDecoration(
        color: RdColors.surface1,
        border: Border(bottom: BorderSide(color: RdColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            // The search box is 360px next to the import button, narrower
            // when the title would otherwise get squeezed out.
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RdText.pageTitle,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: (constraints.maxWidth - 360).clamp(160.0, 360.0),
                  child: search,
                ),
                const SizedBox(width: 12),
                RdButton(
                  label: importLabel,
                  icon: Icons.file_download_outlined,
                  height: 40,
                  onPressed: onImport,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            container: true,
            label: tabsLabel,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (index, tab) in tabs.indexed) ...[
                    if (index > 0) const SizedBox(width: 4),
                    _UnderlineTab(
                      tab: tab,
                      selected: tab.kind == selected,
                      onTap: () => onSelect(tab.kind),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnderlineTab extends StatelessWidget {
  const _UnderlineTab({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _KindTabData tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RdRadii.chip),
        ),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: selected ? RdColors.accent : Colors.transparent,
              ),
            ),
          ),
          child: _TabLabel(tab: tab, selected: selected),
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.tab, required this.selected});

  final _KindTabData tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tab.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? RdColors.text : RdColors.text2,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${tab.count}',
          style: RdText.mono(
            fontSize: 12,
            color: selected ? RdColors.accentHover : RdColors.text3,
          ),
        ),
      ],
    );
  }
}

/// Phone app bar (`MItems`): title with the import icon button, search, and
/// a scrolling row of kind chips.
class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.title,
    required this.importLabel,
    required this.onImport,
    required this.search,
    required this.tabsLabel,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final String importLabel;
  final VoidCallback onImport;
  final Widget search;
  final String tabsLabel;
  final List<_KindTabData> tabs;
  final ItemKind? selected;
  final ValueChanged<ItemKind?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: RdColors.surface1,
        border: Border(bottom: BorderSide(color: RdColors.hairline)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RdText.mobileTitle,
                        ),
                      ),
                    ),
                    RdIconButton(
                      icon: Icons.file_download_outlined,
                      tooltip: importLabel,
                      filled: false,
                      onPressed: onImport,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: search,
            ),
            Semantics(
              container: true,
              label: tabsLabel,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: [
                    for (final (index, tab) in tabs.indexed) ...[
                      if (index > 0) const SizedBox(width: 8),
                      _ChipTab(
                        tab: tab,
                        selected: tab.kind == selected,
                        onTap: () => onSelect(tab.kind),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipTab extends StatelessWidget {
  const _ChipTab({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _KindTabData tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(18));
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? RdColors.accentSoft : RdColors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? RdColors.accentLine : RdColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: _TabLabel(tab: tab, selected: selected),
          ),
        ),
      ),
    );
  }
}

/// Section title, its tile count and a hairline to the right edge.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          header: true,
          child: Text(title, style: RdText.sectionTitle),
        ),
        const SizedBox(width: 10),
        Text(
          '$count',
          style: RdText.mono(fontSize: 12, color: RdColors.text3),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: RdColors.hairline),
          ),
        ),
      ],
    );
  }
}

/// Compact item tile. The tile opens the detail page; the owned count is a
/// separate button that opens the count editor, and on PC hovering the tile
/// adds a pencil to that button.
class _ItemTile extends StatefulWidget {
  const _ItemTile({
    required this.item,
    required this.compact,
    required this.openLabel,
    required this.editLabel,
    required this.onOpen,
    required this.onEditCount,
    super.key,
  });

  final ItemEntry item;
  final bool compact;
  final String openLabel;
  final String editLabel;
  final VoidCallback onOpen;
  final VoidCallback onEditCount;

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final compact = widget.compact;
    final radius = BorderRadius.circular(RdRadii.tile);
    final name = Text(
      item.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: compact ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        fontSize: compact ? 11 : 13,
        height: compact ? 14 / 11 : 18 / 13,
        fontWeight: FontWeight.w500,
        color: RdColors.text,
      ),
    );
    final icon = ExcludeSemantics(
      child: ItemIcon(
        itemId: item.itemId,
        iconId: item.iconId,
        name: item.name,
        size: compact ? 40 : 48,
      ),
    );
    final count = _OwnedCountButton(
      item: item,
      compact: compact,
      hovered: _hovered,
      semanticsLabel: widget.editLabel,
      onPressed: widget.onEditCount,
    );
    final open = Semantics(
      link: true,
      label: widget.openLabel,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: radius,
        onTap: widget.onOpen,
        child: compact
            ? Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                child: Column(
                  children: [
                    icon,
                    const SizedBox(height: 6),
                    Expanded(child: name),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: name),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
      ),
    );
    final hovered = _hovered && !compact;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: hovered ? RdColors.surface3 : RdColors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: hovered ? RdColors.accentLine : RdColors.hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: compact ? 116 : 72,
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: open), count],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: open),
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Center(child: count),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Owned count of a tile: text-3 at 0, text colour above. Tapping it opens
/// the count editor.
class _OwnedCountButton extends StatelessWidget {
  const _OwnedCountButton({
    required this.item,
    required this.compact,
    required this.hovered,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final ItemEntry item;
  final bool compact;
  final bool hovered;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final owned = item.ownedCount > 0;
    final pencil = hovered && !compact;
    final label = Text(
      formatOwnedCount(item.ownedCount, item.itemId),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: RdText.mono(
        fontSize: compact ? 12 : 13,
        color: owned ? RdColors.text : RdColors.text3,
      ),
    );
    final radius = BorderRadius.circular(RdRadii.chip);
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: pencil ? RdColors.accentSoft : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          borderRadius: radius,
          hoverColor: RdColors.white5,
          onTap: onPressed,
          child: Container(
            height: compact ? 32 : 36,
            constraints: BoxConstraints(minWidth: compact ? 0 : 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: pencil
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: RdColors.accentHover,
                      ),
                      const SizedBox(width: 6),
                      Flexible(child: label),
                    ],
                  )
                : label,
          ),
        ),
      ),
    );
  }
}

/// "Show more" box under the grid: the 30-per-batch hint, progress, and a
/// button for keyboard / assistive users (scrolling also loads more).
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.compact,
    required this.hint,
    required this.progress,
    required this.buttonLabel,
    required this.onLoadMore,
  });

  final bool compact;
  final String hint;
  final String progress;
  final String buttonLabel;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      '$hint · $progress',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: compact ? 12 : 13, color: RdColors.muted),
    );
    final button = RdButton(
      label: buttonLabel,
      variant: RdButtonVariant.ghost,
      height: compact ? 44 : 36,
      onPressed: onLoadMore,
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RdRadii.inner),
        border: Border.all(color: RdColors.hairline),
      ),
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [label, const SizedBox(height: 8), button],
            )
          : Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [label, button],
            ),
    );
  }
}

/// Pulsing placeholder tiles shown while items load.
class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 8.0 : 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth, compact);
        final width = ((constraints.maxWidth - gap * (columns - 1)) / columns)
            .floorToDouble();
        final iconSize = compact ? 40.0 : 48.0;
        final icon = RdSkeleton(
          width: iconSize,
          height: iconSize,
          radius: RdRadii.control,
          color: RdColors.surface3,
        );
        return RdPulse(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < columns * 3; i++)
                Container(
                  width: width,
                  height: compact ? 116 : 72,
                  padding: compact
                      ? const EdgeInsets.fromLTRB(6, 10, 6, 10)
                      : const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: RdColors.surface2,
                    borderRadius: BorderRadius.circular(RdRadii.tile),
                    border: Border.all(color: RdColors.hairline),
                  ),
                  child: compact
                      ? Column(
                          children: [
                            icon,
                            const SizedBox(height: 8),
                            const RdSkeleton(
                              height: 10,
                              widthFactor: 0.8,
                              color: RdColors.white8,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            icon,
                            const SizedBox(width: 12),
                            const Expanded(
                              child: RdSkeleton(
                                height: 12,
                                widthFactor: 0.7,
                                color: RdColors.white8,
                              ),
                            ),
                          ],
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Body of the JSON import dialog.
class _ItemCountImportForm extends ConsumerStatefulWidget {
  const _ItemCountImportForm({
    required this.importing,
    required this.onCancel,
    required this.onSubmit,
  });

  final ValueListenable<bool> importing;
  final VoidCallback onCancel;
  final Future<void> Function(String payload) onSubmit;

  @override
  ConsumerState<_ItemCountImportForm> createState() =>
      _ItemCountImportFormState();
}

class _ItemCountImportFormState extends ConsumerState<_ItemCountImportForm> {
  final _payload = TextEditingController();

  @override
  void dispose() {
    _payload.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final compact = context.rdLayout == RdLayout.compact;
    final radius = BorderRadius.circular(RdRadii.control);
    return ValueListenableBuilder<bool>(
      valueListenable: widget.importing,
      builder: (context, importing, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i18n.t('itemsPage.importDialog.description'),
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              height: 1.6,
              color: compact ? RdColors.secondary : RdColors.secondary2,
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          Stack(
            children: [
              Semantics(
                label: i18n.t('rd.items.importLabel'),
                child: TextField(
                  controller: _payload,
                  enabled: !importing,
                  minLines: 10,
                  maxLines: 10,
                  keyboardType: TextInputType.multiline,
                  cursorColor: RdColors.accent,
                  style: RdText.mono(fontSize: 13).copyWith(height: 1.6),
                  decoration: InputDecoration(
                    hintText: i18n.t('itemsPage.importDialog.placeholder'),
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: RdColors.placeholder,
                    ),
                    filled: true,
                    fillColor:
                        compact ? RdColors.sheetOption : RdColors.surface3,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: const BorderSide(color: RdColors.white14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: const BorderSide(color: RdColors.white14),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: const BorderSide(color: RdColors.white14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: const BorderSide(color: RdColors.accent),
                    ),
                  ),
                ),
              ),
              if (importing)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: RdColors.disabledVeil,
                        borderRadius: radius,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 12 : 16),
          Text(
            i18n.t('rd.items.importExample'),
            style: const TextStyle(fontSize: 12, color: RdColors.muted),
          ),
          SizedBox(height: compact ? 12 : 16),
          Row(
            children: [
              if (importing)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    i18n.t('rd.items.importing'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: RdColors.link,
                    ),
                  ),
                ),
              const Spacer(),
              RdButton(
                label: i18n.t('common.cancel'),
                variant: RdButtonVariant.ghost,
                onPressed: importing ? null : widget.onCancel,
              ),
              const SizedBox(width: 8),
              RdButton(
                label: i18n.t('itemsPage.actions.applyImport'),
                variant: RdButtonVariant.primary,
                busy: importing,
                onPressed: importing
                    ? null
                    : () => unawaited(widget.onSubmit(_payload.text)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
