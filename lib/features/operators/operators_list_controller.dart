import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data_sources/region_code.dart';
import '../../domain/operator.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/operator_service.dart';
import '../shared/operator_search.dart';

/// `useInfiniteSlice` options used by the Vue page.
const operatorsInitialCount = 36;
const operatorsBatchSize = 24;

/// The four filter dimensions of the operators list (the old filter drawer:
/// rarity, profession, affiliation and BA tags).
enum OperatorFilterDimension { rarity, profession, affiliation, baTags }

extension OperatorFilterDimensionInfo on OperatorFilterDimension {
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

  /// Key fragment of the dimension's chips and rows.
  String get keyName => switch (this) {
        OperatorFilterDimension.rarity => 'rarity',
        OperatorFilterDimension.profession => 'profession',
        OperatorFilterDimension.affiliation => 'affiliation',
        OperatorFilterDimension.baTags => 'ba-tags',
      };

  /// Several values can be picked at once (BA tags).
  bool get multi => this == OperatorFilterDimension.baTags;

  /// Long option lists get a search box.
  bool get searchable =>
      this == OperatorFilterDimension.affiliation ||
      this == OperatorFilterDimension.baTags;
}

/// One selectable value of a [OperatorFilterDimension].
class OperatorFilterOption {
  const OperatorFilterOption({
    required this.dimension,
    required this.value,
    required this.label,
    required this.selected,
  });

  final OperatorFilterDimension dimension;

  /// The rarity (int) or the profession / affiliation / tag (String).
  final Object value;
  final String label;
  final bool selected;
}

class OperatorFilters {
  const OperatorFilters({
    this.query = '',
    this.affiliation,
    this.rarity,
    this.profession,
    this.baTags = const [],
    this.hideUnreleased = false,
  });

  final String query;
  final String? affiliation;
  final int? rarity;
  final String? profession;
  final List<String> baTags;

  /// Hides the operators the region has not released yet
  /// ([OperatorSummary.isUnreleased]); they are listed by default.
  final bool hideUnreleased;

  /// Any of the drawer filters or the unreleased toggle (the search text is
  /// not one of them).
  bool get hasDimension =>
      affiliation != null ||
      rarity != null ||
      profession != null ||
      baTags.isNotEmpty ||
      hideUnreleased;

  OperatorFilters copyWith({
    String? query,
    String? Function()? affiliation,
    int? Function()? rarity,
    String? Function()? profession,
    List<String>? baTags,
    bool? hideUnreleased,
  }) {
    return OperatorFilters(
      query: query ?? this.query,
      affiliation: affiliation == null ? this.affiliation : affiliation(),
      rarity: rarity == null ? this.rarity : rarity(),
      profession: profession == null ? this.profession : profession(),
      baTags: baTags ?? this.baTags,
      hideUnreleased: hideUnreleased ?? this.hideUnreleased,
    );
  }
}

class OperatorFilterOptions {
  const OperatorFilterOptions({
    required this.affiliations,
    required this.baTags,
    required this.rarities,
    required this.professions,
    this.hasUnreleased = false,
  });

  factory OperatorFilterOptions.from(List<OperatorSummary> operators) {
    return OperatorFilterOptions(
      affiliations: {
        for (final operator in operators) ...[
          ...operator.teams,
          ...operator.nations,
          ...operator.groups,
        ],
      }.toList()
        ..sort(),
      baTags: {for (final operator in operators) ...operator.baTags}.toList()
        ..sort(),
      rarities: {for (final operator in operators) operator.rarity}.toList()
        ..sort((a, b) => b - a),
      professions:
          {for (final operator in operators) operator.profession}.toList()
            ..sort(),
      hasUnreleased: operators.any((operator) => operator.isUnreleased),
    );
  }

  final List<String> affiliations;
  final List<String> baTags;
  final List<int> rarities;
  final List<String> professions;

  /// The list has unreleased operators, so the toggle hiding them is shown.
  final bool hasUnreleased;
}

/// State of the operators list (`src/pages/operators.vue`).
///
/// In the Vue app the detail page is a child route rendered inside the list
/// page, so filters survive opening an operator and reset when leaving to
/// home. Here the PC master-detail renders the same workspace for
/// `/operators` and `/operators/:id`, which are different go_router pages, so
/// the state lives in an auto-disposed provider instead of a widget: it
/// stays alive while any operators page is mounted and resets once the user
/// leaves the section.
class OperatorsListController extends ChangeNotifier {
  OperatorsListController(this._ref);

  final Ref _ref;

  List<OperatorSummary> _allOperators = const [];
  List<OperatorSummary> operatorList = const [];
  OperatorFilterOptions options = OperatorFilterOptions.from(const []);
  OperatorFilters _filters = const OperatorFilters();
  bool isLoading = true;
  String errorMessage = '';
  int visibleCount = operatorsInitialCount;

  /// Last list scroll offset, restored when the list widget is rebuilt on
  /// another route (PC master-detail selection).
  double scrollOffset = 0;

  int _loadToken = 0;
  bool _disposed = false;
  bool _started = false;

  OperatorFilters get filters => _filters;

  int get operatorCount => _allOperators.length;

  bool get hasMore => visibleCount < operatorList.length;

  /// Starts the first load once; later calls are no-ops.
  ///
  /// When the list was already loaded this session for the current region
  /// and data revision, it is used at once (without notifying: this runs
  /// while the page builds), so reopening the section shows the operators in
  /// its first frame instead of a frame of loading tiles first.
  void ensureLoaded() {
    if (_started) {
      return;
    }
    _started = true;
    final loaded = _ref.read(_loadedOperatorsProvider).lookup(
          _ref.read(regionProvider),
          _ref.read(dataRevisionProvider),
        );
    if (loaded == null) {
      load();
      return;
    }
    _allOperators = loaded.operators;
    options = loaded.options;
    _applyLocalFilters();
    isLoading = false;
  }

  Future<void> load({bool reset = false}) async {
    _started = true;
    final token = ++_loadToken;
    final region = _ref.read(regionProvider);
    // The first load starts while widgets build; it is already "loading",
    // so only later reloads need to notify.
    final changed = !isLoading || errorMessage.isNotEmpty || reset;
    isLoading = true;
    errorMessage = '';
    if (reset) {
      _allOperators = const [];
      operatorList = const [];
    }
    if (changed) {
      _notify();
    }

    try {
      var operators = _allOperators;
      if (operators.isEmpty) {
        // `listOperators` -> `ensureRegionReady` -> `ensure_region_fresh`
        // (done by the service; a failed check shows the error state).
        operators = await _ref
            .read(operatorServiceProvider)
            .listOperators(OperatorQuery(region: region));
      }
      if (_disposed || token != _loadToken) {
        return;
      }
      _allOperators = operators;
      options = OperatorFilterOptions.from(operators);
      _ref.read(_loadedOperatorsProvider).store(
            region,
            _ref.read(dataRevisionProvider),
            operators,
            options,
          );
      _applyLocalFilters();
    } catch (error) {
      if (_disposed || token != _loadToken) {
        return;
      }
      errorMessage = '$error';
      operatorList = const [];
    } finally {
      if (!_disposed && token == _loadToken) {
        isLoading = false;
        _notify();
      }
    }
  }

  set filters(OperatorFilters next) {
    _filters = next;
    _applyLocalFilters();
    _notify();
  }

  /// [notify] is false when called while widgets build (route `?q=`).
  void setQuery(String query, {bool notify = true}) {
    if (query == _filters.query) {
      return;
    }
    _filters = _filters.copyWith(query: query);
    _applyLocalFilters();
    if (notify) {
      _notify();
    }
  }

  /// `clearFilters`: resets the four drawer filters and the unreleased
  /// toggle, and keeps the search.
  void clearFilters() {
    filters = _filters.copyWith(
      affiliation: () => null,
      rarity: () => null,
      profession: () => null,
      baTags: const [],
      hideUnreleased: false,
    );
  }

  void toggleHideUnreleased() {
    filters = _filters.copyWith(hideUnreleased: !_filters.hideUnreleased);
  }

  void toggleBaTag(String tag) {
    final tags = _filters.baTags;
    filters = _filters.copyWith(
      baTags: tags.contains(tag)
          ? [
              for (final value in tags)
                if (value != tag) value,
            ]
          : [...tags, tag],
    );
  }

  /// Options of [dimension] for the current data, with their labels and
  /// whether each is selected.
  List<OperatorFilterOption> filterOptions(
    OperatorFilterDimension dimension,
    NexusI18n i18n,
  ) {
    final filters = _filters;
    OperatorFilterOption option(Object value, String label, bool selected) =>
        OperatorFilterOption(
          dimension: dimension,
          value: value,
          label: label,
          selected: selected,
        );
    return switch (dimension) {
      OperatorFilterDimension.rarity => [
          for (final rarity in options.rarities)
            option(rarity, '$rarity ★', filters.rarity == rarity),
        ],
      OperatorFilterDimension.profession => [
          for (final profession in options.professions)
            option(
              profession,
              i18n.profession(profession),
              filters.profession == profession,
            ),
        ],
      OperatorFilterDimension.affiliation => [
          for (final affiliation in options.affiliations)
            option(
              affiliation,
              affiliation,
              filters.affiliation == affiliation,
            ),
        ],
      OperatorFilterDimension.baTags => [
          for (final tag in options.baTags)
            option(tag, tag, filters.baTags.contains(tag)),
        ],
    };
  }

  /// Selects [option], or clears it when it is already the selected value;
  /// BA tags toggle.
  void applyFilterOption(OperatorFilterOption option) {
    final value = option.value;
    switch (option.dimension) {
      case OperatorFilterDimension.rarity:
        filters = _filters.copyWith(
          rarity: () => _filters.rarity == value ? null : value as int,
        );
      case OperatorFilterDimension.profession:
        filters = _filters.copyWith(
          profession: () =>
              _filters.profession == value ? null : value as String,
        );
      case OperatorFilterDimension.affiliation:
        filters = _filters.copyWith(
          affiliation: () =>
              _filters.affiliation == value ? null : value as String,
        );
      case OperatorFilterDimension.baTags:
        toggleBaTag(value as String);
    }
  }

  /// Selected value(s) of [dimension] as one label, or null when unset.
  String? shownFilterValue(OperatorFilterDimension dimension, NexusI18n i18n) {
    final filters = _filters;
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

  void clearFilterDimension(OperatorFilterDimension dimension) {
    filters = switch (dimension) {
      OperatorFilterDimension.rarity => _filters.copyWith(rarity: () => null),
      OperatorFilterDimension.profession =>
        _filters.copyWith(profession: () => null),
      OperatorFilterDimension.affiliation =>
        _filters.copyWith(affiliation: () => null),
      OperatorFilterDimension.baTags => _filters.copyWith(baTags: const []),
    };
  }

  void loadMore() {
    if (!hasMore) {
      return;
    }
    visibleCount =
        math.min(visibleCount + operatorsBatchSize, operatorList.length);
    _notify();
  }

  /// `applyLocalFilters`. The search also matches the profession name of the
  /// current language (e.g. "메딕"), not only the raw profession code.
  void _applyLocalFilters() {
    final filters = _filters;
    final i18n = _ref.read(i18nProvider);
    final needle = operatorSearchNeedle(filters.query);
    operatorList = _allOperators.where((operator) {
      final matchesQuery = operatorMatchesQuery(operator, needle, i18n);
      final affiliation = filters.affiliation;
      final matchesAffiliation = affiliation == null ||
          operator.teams.contains(affiliation) ||
          operator.nations.contains(affiliation) ||
          operator.groups.contains(affiliation);
      final matchesRarity =
          filters.rarity == null || operator.rarity == filters.rarity;
      final matchesProfession = filters.profession == null ||
          operator.profession == filters.profession;
      final matchesBaTags =
          filters.baTags.every((tag) => operator.baTags.contains(tag));
      if (filters.hideUnreleased && operator.isUnreleased) {
        return false;
      }
      return matchesQuery &&
          matchesAffiliation &&
          matchesRarity &&
          matchesProfession &&
          matchesBaTags;
    }).toList();
    // `useInfiniteSlice` resets whenever the source list changes.
    visibleCount = math.min(operatorsInitialCount, operatorList.length);
    scrollOffset = 0;
  }

  /// Applied-filter chips (`activeFilterChips`).
  List<String> activeChips(NexusI18n i18n) {
    final query = _filters.query.trim();
    return [
      if (query.isNotEmpty) i18n.t('rd.operators.chip.query', {'value': query}),
      if (_filters.affiliation != null)
        i18n.t('rd.operators.chip.affiliation', {
          'value': _filters.affiliation,
        }),
      if (_filters.rarity != null) '${_filters.rarity} ★',
      if (_filters.profession != null) i18n.profession(_filters.profession!),
      for (final tag in _filters.baTags)
        '${i18n.t('operatorsList.filters.baTags')}: $tag',
      if (_filters.hideUnreleased) i18n.t('rd.operators.filter.hideUnreleased'),
    ];
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The operator list (and its filter options) last loaded this session.
///
/// [OperatorsListController] is disposed when the user leaves the section;
/// this keeps the loaded list for the next visit. The list only changes with
/// the region or a sync (which bumps [dataRevisionProvider]), so both are
/// part of the key; the region's freshness check runs once per session.
class _LoadedOperators {
  RegionCode? _region;
  int? _revision;
  ({List<OperatorSummary> operators, OperatorFilterOptions options})? _value;

  ({List<OperatorSummary> operators, OperatorFilterOptions options})? lookup(
    RegionCode region,
    int revision,
  ) {
    return region == _region && revision == _revision ? _value : null;
  }

  void store(
    RegionCode region,
    int revision,
    List<OperatorSummary> operators,
    OperatorFilterOptions options,
  ) {
    _region = region;
    _revision = revision;
    _value = (operators: operators, options: options);
  }
}

/// Recreated with the operator service, so a different data source never
/// serves a list loaded from another one.
final _loadedOperatorsProvider = Provider<_LoadedOperators>((ref) {
  ref.watch(operatorServiceProvider);
  return _LoadedOperators();
});

final operatorsListControllerProvider =
    ChangeNotifierProvider.autoDispose<OperatorsListController>((ref) {
  final controller = OperatorsListController(ref);
  ref.listen(regionProvider, (previous, next) {
    if (previous != next) {
      controller.load(reset: true);
    }
  });
  ref.listen(dataRevisionProvider, (previous, next) {
    if (previous != next) {
      controller.load(reset: true);
    }
  });
  return controller;
});
