import 'dart:convert';

import 'package:arknight_nexus/data_sources/arknights_data_source.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/raw_models/gamedata_const.dart';
import 'package:arknight_nexus/raw_models/handbook_team.dart';
import 'package:arknight_nexus/raw_models/uniequip.dart';
import 'package:arknight_nexus/services/normalizers/operator_normalizer.dart';

/// A region's names for the categories an operator is labelled with, by
/// upstream id: factions (teams, nations, groups), branches, recruitment
/// tags and BA terms.
///
/// Snapshots store only the names, in the region's language. An operator
/// borrowed from another region carries that region's names; these maps
/// relate them through the shared ids ([localizeLabels]).
class RegionLabels {
  const RegionLabels({
    this.powers = const {},
    this.branches = const {},
    this.recruitTags = const {},
    this.baTerms = const {},
  });

  /// Reads the [tableFiles] in [bodies] (file name to JSON text).
  factory RegionLabels.fromTables(Map<String, String> bodies) {
    Map<String, Object?> table(String file) =>
        jsonDecode(bodies[file]!) as Map<String, Object?>;

    final recruitTags = <String, String>{};
    final gachaTags = table(gachaTableFile)['gachaTags'];
    if (gachaTags is List) {
      for (final tag in gachaTags.whereType<Map<String, Object?>>()) {
        final id = tag['tagId'];
        final name = tag['tagName'];
        if (id != null && name is String && name.trim().isNotEmpty) {
          recruitTags['$id'] = name.trim();
        }
      }
    }

    return RegionLabels(
      powers: RawHandbookTeamTable.fromJson(
        table(ArknightsDataSource.handbookTeamTableFile),
      ).powerNames(),
      branches: RawUniequipTable.fromJson(
        table(ArknightsDataSource.uniequipTableFile),
      ).subProfNames(),
      recruitTags: recruitTags,
      baTerms: baTermNames(
        RawGameDataConst.fromJson(
          table(ArknightsDataSource.gamedataConstFile),
        ),
      ),
    );
  }

  /// Recruitment tag names by tag id. Not one of the app's tables: the
  /// character table lists an operator's tags by name only.
  static const gachaTableFile = 'gacha_table.json';

  /// The upstream tables [RegionLabels.fromTables] reads.
  static const tableFiles = [
    ArknightsDataSource.handbookTeamTableFile,
    ArknightsDataSource.uniequipTableFile,
    ArknightsDataSource.gamedataConstFile,
    gachaTableFile,
  ];

  /// Faction (`handbook_team_table` power) names, for teams, nations and
  /// groups alike.
  final Map<String, String> powers;

  /// Branch (sub-profession) names.
  final Map<String, String> branches;

  /// Recruitment tag names.
  final Map<String, String> recruitTags;

  /// BA term names by term key (`ba.*`).
  final Map<String, String> baTerms;
}

/// Tally of the labels [localizeLabels] rewrote or left alone.
class LabelLocalizationStats {
  /// Labels now in the target region's language.
  int mapped = 0;

  /// Labels the target region has no id for, kept in the source language,
  /// as `field: label` with their number of occurrences.
  final Map<String, int> kept = {};

  void _keep(String field, String label) {
    final key = '$field: $label';
    kept[key] = (kept[key] ?? 0) + 1;
  }
}

/// [operator], a [source] region's operator borrowed into the [target]
/// region, with its categorical labels in the target's language: every
/// faction, branch and recruitment tag whose id (looked up by the source's
/// name) the target has gets the target's name, and the BA tags are read
/// again from its texts with the target's term names. A label the target
/// has no id for, such as a faction new in the source, keeps the source's
/// name. Descriptive text (names, quotes, skills...) is left as it is.
///
/// [sharedTags] (see [sharedTagNames]) names the recruitment tags missing
/// from the source's gacha table, such as tags recruitment does not offer.
OperatorDetail localizeLabels(
  OperatorDetail operator, {
  required RegionLabels source,
  required RegionLabels target,
  Map<String, String> sharedTags = const {},
  LabelLocalizationStats? stats,
}) {
  final tally = stats ?? LabelLocalizationStats();
  String translate(
    String field,
    String label,
    Map<String, String> sourceNames,
    Map<String, String> targetNames, [
    Map<String, String> fallback = const {},
  ]) {
    for (final MapEntry(:key, :value) in sourceNames.entries) {
      if (value != label) {
        continue;
      }
      final name = targetNames[key];
      if (name != null) {
        tally.mapped++;
        return name;
      }
    }
    if (fallback[label] case final name?) {
      tally.mapped++;
      return name;
    }
    tally._keep(field, label);
    return label;
  }

  List<String> powers(String field, List<String> labels) => [
        for (final label in labels)
          translate(field, label, source.powers, target.powers),
      ];

  final texts = baTagTexts(
    characterTexts: [operator.archetypeDescription, operator.quote],
    traits: operator.traits,
    talents: operator.talents,
    skills: operator.skills,
    modules: operator.modules,
  ).toList();
  final baTags = resolveBaTags({...source.baTerms, ...target.baTerms}, texts);
  final targetBaTags = resolveBaTags(target.baTerms, texts).toSet();
  for (final tag in baTags) {
    if (targetBaTags.contains(tag)) {
      tally.mapped++;
    } else {
      tally._keep('baTags', tag);
    }
  }

  final json = operator.toJson()
    ..['branch'] =
        translate('branch', operator.branch, source.branches, target.branches)
    ..['teams'] = powers('teams', operator.teams)
    ..['nations'] = powers('nations', operator.nations)
    ..['groups'] = powers('groups', operator.groups)
    ..['tags'] = [
      for (final tag in operator.tags)
        translate(
          'tags',
          tag,
          source.recruitTags,
          target.recruitTags,
          sharedTags,
        ),
    ]
    ..['baTags'] = baTags;
  return OperatorDetail.fromJson(
    jsonDecode(jsonEncode(json)) as Map<String, Object?>,
  );
}

/// The target's name for each recruitment tag name of the source, read
/// from the operators both regions have released ([source] and [target]
/// operators with the same id): an operator lists its tags in the same order
/// on every server. A name paired with different names is left out.
Map<String, String> sharedTagNames(
  Iterable<OperatorDetail> source,
  Iterable<OperatorDetail> target,
) {
  final targetTags = {
    for (final operator in target)
      if (!operator.isUnreleased) operator.id: operator.tags,
  };
  final names = <String, String>{};
  final conflicting = <String>{};
  for (final operator in source) {
    final tags = targetTags[operator.id];
    if (operator.isUnreleased ||
        tags == null ||
        tags.length != operator.tags.length) {
      continue;
    }
    for (var index = 0; index < tags.length; index++) {
      final name = operator.tags[index];
      if (names.putIfAbsent(name, () => tags[index]) != tags[index]) {
        conflicting.add(name);
      }
    }
  }
  return names..removeWhere((name, _) => conflicting.contains(name));
}
