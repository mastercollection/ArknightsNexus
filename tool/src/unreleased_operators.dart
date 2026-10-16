import 'dart:convert';

import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/item.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/region_snapshot.dart';

import 'region_labels.dart';

/// Regions whose official data fills in the operators [region] has not
/// released yet, in priority order: the global (EN) server first, then CN,
/// which releases everything first. CN has no unreleased operators.
List<RegionCode> unreleasedSourcesFor(RegionCode region) {
  return switch (region) {
    RegionCode.cn => const [],
    RegionCode.en => const [RegionCode.cn],
    _ => const [RegionCode.en, RegionCode.cn],
  };
}

/// Adds to [native] (a snapshot normalized from the region's own tables) the
/// operators of [sources] it does not have, by id, each from the first
/// source in [sources] that has it, marked with
/// [OperatorDetail.unreleasedSource]. Operators of a source that are
/// themselves unreleased there are ignored, so [sources] may be published
/// (already merged) snapshots.
///
/// The added operators come first: those of the last source first (CN only
/// operators are the newest), each in the source's order, which is newest
/// release first (`OperatorNormalizer`); then the
/// region's own operators in their order. Items their costs need and the
/// terms (`<$ba.*>`) their texts and those terms refer to are copied too
/// when the region lacks them, items marked [ItemEntry.unreleasedSource],
/// each from the first of [sources] that has it, like the operators.
/// The item names, icons and rarities the added operators' costs carry are
/// then the snapshot's, so costs read in the region's language wherever
/// the region has the item.
///
/// When [labels] has both the region's and a source's [RegionLabels], the
/// operators taken from that source get the region's names for their
/// factions, branch, recruitment tags and BA tags ([localizeLabels]), so the
/// filters do not list a faction twice in two languages; [labelStats]
/// tallies that.
///
/// [RegionSnapshot.unreleasedSourceVersions] records every source's version
/// even when nothing was added: the snapshot depends on them either way.
RegionSnapshot mergeUnreleasedOperators(
  RegionSnapshot native,
  List<RegionSnapshot> sources, {
  Map<RegionCode, RegionLabels> labels = const {},
  LabelLocalizationStats? labelStats,
}) {
  final known = {for (final operator in native.operators) operator.id};
  final targetLabels = labels[native.region];
  final borrowedBySource = <List<OperatorDetail>>[];
  for (final source in sources) {
    final sourceLabels = labels[source.region];
    final borrowed = <OperatorDetail>[];
    for (final operator in source.operators) {
      if (operator.isUnreleased || !known.add(operator.id)) {
        continue;
      }
      final unreleased = operator.asUnreleased(source.region.value);
      borrowed.add(
        targetLabels == null || sourceLabels == null
            ? unreleased
            : localizeLabels(
                unreleased,
                source: sourceLabels,
                target: targetLabels,
                stats: labelStats,
              ),
      );
    }
    borrowedBySource.add(borrowed);
  }
  final borrowed = [
    for (final group in borrowedBySource.reversed) ...group,
  ];

  final items = List.of(native.items);
  final itemIds = {for (final item in native.items) item.itemId};
  final terms = Map.of(native.terms);
  final itemIndexes = <String, Map<String, ItemEntry>>{};
  Map<String, ItemEntry> itemsOf(RegionSnapshot source) =>
      itemIndexes.putIfAbsent(
        source.region.value,
        () => {
          for (final item in source.items)
            if (item.unreleasedSource == null) item.itemId: item,
        },
      );

  for (final operator in borrowed) {
    for (final id in _costItemIds(operator)) {
      if (!itemIds.add(id)) {
        continue;
      }
      for (final source in sources) {
        final item = itemsOf(source)[id];
        if (item != null) {
          items.add(item.asUnreleased(source.region.value));
          break;
        }
      }
    }

    final pending = termKeysIn(jsonEncode(operator.toJson())).toList();
    while (pending.isNotEmpty) {
      final key = pending.removeLast();
      if (terms.containsKey(key)) {
        continue;
      }
      for (final source in sources) {
        final description = source.terms[key];
        if (description != null) {
          terms[key] = description;
          pending.addAll(termKeysIn(description));
          break;
        }
      }
    }
  }

  final itemsById = {for (final item in items) item.itemId: item};
  return RegionSnapshot(
    schemaVersionValue: native.schemaVersionValue,
    region: native.region,
    sourceRevision: native.sourceRevision,
    sourceVersion: native.sourceVersion,
    fetchedAt: native.fetchedAt,
    stageCodeMap: native.stageCodeMap,
    terms: terms,
    items: items,
    buildingFormulas: native.buildingFormulas,
    operators: [
      for (final operator in borrowed) _withItemsOf(operator, itemsById),
      ...native.operators,
    ],
    unreleasedSourceVersions: {
      for (final source in sources)
        source.region.value: source.sourceVersion.versionControl,
    },
  );
}

/// [operator] with the item details of its costs taken from [items].
///
/// Costs sit in several nested structures (elite, skill, mastery and module
/// costs); rewriting the JSON form reaches all of them in one place.
OperatorDetail _withItemsOf(
  OperatorDetail operator,
  Map<String, ItemEntry> items,
) {
  void visit(Object? node) {
    if (node is List) {
      node.forEach(visit);
    } else if (node is Map<String, Object?>) {
      // Only `OperatorCost.toJson` has an `itemName`.
      final item = node.containsKey('itemName') ? items[node['id']] : null;
      if (item != null) {
        node
          ..['itemName'] = item.name
          ..['itemRarity'] = item.rarity
          ..['itemIconId'] = item.iconId
          ..['itemType'] = item.itemType;
        return;
      }
      node.values.forEach(visit);
    }
  }

  final json =
      jsonDecode(jsonEncode(operator.toJson())) as Map<String, Object?>;
  visit(json);
  return OperatorDetail.fromJson(json);
}

final _termPattern = RegExp(r'<\$([^<>]+)>');

/// Term keys of the `<$key>` links in [text].
Iterable<String> termKeysIn(String text) =>
    _termPattern.allMatches(text).map((match) => match.group(1)!.trim());

/// Ids of every item an operator's elite, skill and module costs use.
Set<String> _costItemIds(OperatorDetail operator) {
  return {
    for (final costs in operator.eliteEvolveCosts)
      for (final cost in costs) cost.id,
    for (final stage in operator.allSkillLevelUpCosts)
      for (final cost in stage.costs) cost.id,
    for (final skill in operator.skills)
      for (final stage in skill.upgradeCosts)
        for (final cost in stage.costs) cost.id,
    for (final module in operator.modules)
      for (final costs
          in module.itemCost?.values ?? const <List<OperatorCost>>[])
        for (final cost in costs) cost.id,
  };
}
