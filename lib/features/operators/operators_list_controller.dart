import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/operator.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/operator_service.dart';

/// `useInfiniteSlice` options used by the Vue page.
const operatorsInitialCount = 36;
const operatorsBatchSize = 24;

class OperatorFilters {
  const OperatorFilters({
    this.query = '',
    this.affiliation,
    this.rarity,
    this.profession,
    this.baTags = const [],
  });

  final String query;
  final String? affiliation;
  final int? rarity;
  final String? profession;
  final List<String> baTags;

  /// Any of the four drawer filters (the search text is not one of them).
  bool get hasDimension =>
      affiliation != null ||
      rarity != null ||
      profession != null ||
      baTags.isNotEmpty;

  OperatorFilters copyWith({
    String? query,
    String? Function()? affiliation,
    int? Function()? rarity,
    String? Function()? profession,
    List<String>? baTags,
  }) {
    return OperatorFilters(
      query: query ?? this.query,
      affiliation: affiliation == null ? this.affiliation : affiliation(),
      rarity: rarity == null ? this.rarity : rarity(),
      profession: profession == null ? this.profession : profession(),
      baTags: baTags ?? this.baTags,
    );
  }
}

class OperatorFilterOptions {
  const OperatorFilterOptions({
    required this.affiliations,
    required this.baTags,
    required this.rarities,
    required this.professions,
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
    );
  }

  final List<String> affiliations;
  final List<String> baTags;
  final List<int> rarities;
  final List<String> professions;
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
  void ensureLoaded() {
    if (_started) {
      return;
    }
    _started = true;
    load();
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

  /// `clearFilters`: resets the four drawer filters and keeps the search.
  void clearFilters() {
    filters = _filters.copyWith(
      affiliation: () => null,
      rarity: () => null,
      profession: () => null,
      baTags: const [],
    );
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
    final query = filters.query.trim().toLowerCase();
    operatorList = _allOperators.where((operator) {
      final affiliations = [
        ...operator.teams,
        ...operator.nations,
        ...operator.groups,
      ];
      final matchesQuery = query.isEmpty ||
          [
            operator.name,
            operator.profession,
            i18n.profession(operator.profession),
            ...affiliations,
          ].any((value) => value.toLowerCase().contains(query));
      final matchesAffiliation = filters.affiliation == null ||
          affiliations.contains(filters.affiliation);
      final matchesRarity =
          filters.rarity == null || operator.rarity == filters.rarity;
      final matchesProfession = filters.profession == null ||
          operator.profession == filters.profession;
      final matchesBaTags =
          filters.baTags.every((tag) => operator.baTags.contains(tag));
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
