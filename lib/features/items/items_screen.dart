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
import 'item_overlays.dart';
import 'item_widgets.dart';
import 'owned_count_editor.dart';

/// Port of `src/pages/items.vue`, laid out after the redesign canvas
/// (`DesktopItems` / `MobileItems`): header with JSON import, search, an
/// auto-fill card grid (150px min on PC, 3 columns on phones) with owned
/// count buttons, and an incremental "show more" footer.
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  static const routeName = 'items';

  /// `useInfiniteSlice(filteredItems, { initialCount: 48, batchSize: 30 })`.
  static const initialCount = 48;
  static const batchSize = 30;

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
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
  List<ItemEntry> _filteredItems = const [];
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

  Future<void> _loadItems() async {
    final token = ++_loadToken;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final result = await ref.read(itemServiceProvider).listItems(
            ItemQuery(
              region: ref.read(regionProvider),
              classifyType: 'MATERIAL',
            ),
          );
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _items = result;
        _refilter();
      });
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('items list load failed', error, stackTrace);
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _items = const [];
        _refilter();
        _errorMessage = '$error';
      });
    } finally {
      if (mounted && token == _loadToken) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// `filteredItems` + `watch(filteredItems, resetVisibleItems)`.
  void _refilter() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredItems = query.isEmpty
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
    _slice.reset(_filteredItems.length);
  }

  void _setSearch(String value) {
    setState(() {
      _searchQuery = value;
      _refilter();
    });
  }

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
      _filteredItems = [
        for (final item in _filteredItems)
          item.itemId == itemId ? item.copyWith(ownedCount: count) : item,
      ];
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
      await showItemsDialog<void>(
        context: context,
        title: item.name.isEmpty ? i18n.t('itemsPage.topBar.title') : item.name,
        closeLabel: i18n.t('rd.items.close'),
        maxWidth: 420,
        closeLocked: locked,
        compactHeader: OwnedCountEditorHeader(
          item: item,
          currentCountLabel: i18n.t('itemsPage.editor.currentCount'),
        ),
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
      );
    } finally {
      _savingItemIds.removeListener(onSavingChanged);
      locked.dispose();
    }
  }

  Future<void> _openImportDialog() async {
    final i18n = ref.read(i18nProvider);
    final importing = ValueNotifier<bool>(false);
    await showItemsDialog<void>(
      context: context,
      title: i18n.t('itemsPage.importDialog.title'),
      closeLabel: i18n.t('rd.items.close'),
      maxWidth: 560,
      closeLocked: importing,
      onCloseRequest: () async => !importing.value,
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
              showNexusMessage(context, '$error', type: NexusMessageType.error);
            }
          } finally {
            importing.value = false;
          }
        },
      ),
    );
    importing.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final compact = context.rdLayout == RdLayout.compact;
    final padding = rdPagePadding(context);

    final importButton = RdButton(
      label: i18n.t('itemsPage.actions.importJson'),
      variant: RdButtonVariant.primary,
      onPressed: _openImportDialog,
    );
    final search = RdSearchField(
      controller: _searchController,
      hintText: i18n.t('itemsPage.search.placeholder'),
      height: compact ? 44 : 48,
      onChanged: _setSearch,
    );
    final header = RdPageHeader(
      eyebrow: compact ? null : i18n.t('rd.items.eyebrow'),
      title: i18n.t('itemsPage.topBar.title'),
      subtitle: i18n.t('itemsPage.topBar.description'),
      onBack: _back,
      backTooltip: i18n.t('rd.items.back'),
      actions: [importButton],
      bottom: compact ? search : null,
    );

    final gap = compact ? 12.0 : 18.0;
    return Material(
      color: RdColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact) header,
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: compact
                      ? const EdgeInsets.fromLTRB(16, 14, 16, 24)
                      : padding,
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      if (!compact) ...[
                        SliverToBoxAdapter(child: header),
                        SliverToBoxAdapter(child: SizedBox(height: gap)),
                        SliverToBoxAdapter(child: search),
                        SliverToBoxAdapter(child: SizedBox(height: gap)),
                      ],
                      _buildContent(i18n, compact),
                    ],
                  ),
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
        child: ItemsStatePanel(
          title: i18n.t('itemsPage.states.error'),
          message: _errorMessage,
          alert: true,
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
        child: ItemsStatePanel(title: i18n.t('itemsPage.states.empty')),
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

  Widget _buildItemRows(NexusI18n i18n, bool compact, int columns) {
    final total = _filteredItems.length;
    final visible = _slice.visibleLength(total);
    final rowCount = (visible + columns - 1) ~/ columns;
    final hasMore = _slice.hasMore(total);
    final gap = compact ? 10.0 : 14.0;
    return SliverList.builder(
      itemCount: rowCount + (hasMore ? 1 : 0),
      itemBuilder: (context, rowIndex) {
        if (rowIndex == rowCount) {
          _scheduleLoadMore();
          return Padding(
            padding: EdgeInsets.only(top: gap),
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
        final start = rowIndex * columns;
        final cells = <Widget>[];
        for (var i = 0; i < columns; i++) {
          if (i > 0) {
            cells.add(SizedBox(width: gap));
          }
          final index = start + i;
          if (index >= visible) {
            cells.add(const Expanded(child: SizedBox.shrink()));
            continue;
          }
          final item = _filteredItems[index];
          cells.add(
            Expanded(
              child: _ItemCard(
                key: ValueKey(item.itemId),
                item: item,
                compact: compact,
                openLabel: i18n.t('rd.items.openItem', {'name': item.name}),
                editLabel: i18n.t('rd.items.editCount', {'name': item.name}),
                onOpen: () => context.push('/items/${item.itemId}'),
                onEditCount: () => _openOwnedCountEditor(item),
              ),
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.only(top: rowIndex == 0 ? 0 : gap),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cells,
            ),
          ),
        );
      },
    );
  }
}

/// `repeat(auto-fill, minmax(150px, 1fr))` with a 14px gap on PC; three
/// columns on phones.
int _columnsFor(double width, bool compact) {
  if (compact) {
    return 3;
  }
  final columns = ((width + 14) / (150 + 14)).floor();
  return columns < 1 ? 1 : columns;
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
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
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 16 : RdRadii.tile);
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 0 : 168),
      decoration: BoxDecoration(
        color: RdColors.card,
        borderRadius: radius,
        border: Border.all(color: RdColors.line2),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
              : const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                link: true,
                label: openLabel,
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(RdRadii.control),
                  onTap: onOpen,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ItemIcon(
                          itemId: item.itemId,
                          iconId: item.iconId,
                          name: item.name,
                          size: compact ? 64 : 72,
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 10),
                      ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: compact ? 35 : 38),
                        child: Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign:
                              compact ? TextAlign.center : TextAlign.start,
                          style: TextStyle(
                            fontSize: compact ? 13 : 14,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.28,
                            color: RdColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: compact ? 8 : 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OwnedCountButton(
                    item: item,
                    compact: compact,
                    semanticsLabel: editLabel,
                    onPressed: onEditCount,
                  ),
                  // The item id is a development aid (`import.meta.env.DEV`).
                  if (kDebugMode) ...[
                    SizedBox(height: compact ? 8 : 6),
                    Text(
                      item.itemId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: compact ? TextAlign.center : TextAlign.start,
                      style: RdText.mono(
                        fontSize: compact ? 10 : 11,
                        color: const Color(0xFF8A96AD),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnedCountButton extends StatelessWidget {
  const _OwnedCountButton({
    required this.item,
    required this.compact,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final ItemEntry item;
  final bool compact;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(RdRadii.control);
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: const Color(0x294D75BC),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: Color(0x3D85B6FF)),
        ),
        child: InkWell(
          borderRadius: radius,
          hoverColor: const Color(0x144D75BC),
          onTap: onPressed,
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 44 : 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Text(
              'x ${formatOwnedCount(item.ownedCount, item.itemId)}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RdText.mono(
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE7EFFF),
              ),
            ),
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
        border: Border.all(color: RdColors.white14),
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

/// 18 pulsing placeholder cards shown while items load.
class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 10.0 : 14.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth, compact);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return ItemsPulse(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < 18; i++)
                SizedBox(
                  width: width,
                  child: ItemsSurface(
                    padding: EdgeInsets.all(compact ? 10 : 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ItemsSkeletonBox(
                            width: compact ? 64 : 72,
                            height: compact ? 64 : 72,
                            radius: compact ? 16 : 18,
                            color: RdColors.soft,
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 10),
                        ItemsSkeletonBox(
                          height: compact ? 14 : 16,
                          color: RdColors.white8,
                        ),
                        SizedBox(height: compact ? 8 : 10),
                        ItemsSkeletonBox(
                          height: compact ? 10 : 12,
                          widthFactor: 0.7,
                          color: RdColors.white5,
                        ),
                      ],
                    ),
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
                    fillColor: compact
                        ? RdColors.sheetOption
                        : const Color(0xFF0B1222),
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
                        color: const Color(0x8C050914),
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
