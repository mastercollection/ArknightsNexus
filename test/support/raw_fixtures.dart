import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/data_sources/arknights_data_source.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';

import 'fake_http_client.dart';

/// Serves `test/support/fixtures/raw` as [region]'s upstream tables, with
/// data version [versionControl] (68.2.0 by default). Each [extraOperators]
/// entry adds an operator the fixtures do not have (see [ExtraOperator]).
///
/// [labelSuffix] is appended to every faction, branch, recruitment tag and
/// BA term name, standing for the region's language.
///
/// Besides the app's tables this serves `gacha_table.json` (recruitment
/// tag names), which only the snapshot generator reads.
Future<void> registerRawFixtures(
  FakeHttpClient http,
  RegionCode region, {
  String versionControl = '68.2.0',
  List<ExtraOperator> extraOperators = const [],
  String labelSuffix = '',
}) async {
  final descriptor = region.descriptor;
  http.registerText(
    descriptor.dataVersionUri,
    'Stream://torappu-data/v068/rel68.0\n'
    'Change:100033 on 2025/12/09\n'
    'VersionControl:$versionControl\n',
  );

  for (final file in [
    ...ArknightsDataSource.requiredTableFiles,
    gachaTableFixture,
  ]) {
    var content = await File('test/support/fixtures/raw/$file').readAsString();
    if (extraOperators.isNotEmpty) {
      content = _addOperators(file, content, extraOperators);
    }
    if (labelSuffix.isNotEmpty) {
      content = _suffixLabels(file, content, labelSuffix);
    }
    http.registerText(descriptor.tableUri(file), content);
  }
}

const gachaTableFixture = 'gacha_table.json';

/// An operator released after the fixture ones, in list order (the last is
/// the newest): a copy of Amiya named [name] whose elite 1 costs two
/// [itemId] (a material named [itemName] the fixtures do not have, added
/// when given) and whose trait links the term `ba.<id>`, which in turn
/// links `ba.<id>.more`. With [newFaction] its nation is `power_<id>`,
/// named `<name> Nation`, a faction the fixtures do not have. With
/// [withToken] it has a summon `token_<id>` named `<name> Summon` whose
/// description links the term `ba.<id>.token`.
class ExtraOperator {
  const ExtraOperator({
    required this.id,
    required this.name,
    this.itemId = '30012',
    this.itemName,
    this.newFaction = false,
    this.withToken = false,
  });

  final String id;
  final String name;
  final String itemId;
  final String? itemName;
  final bool newFaction;
  final bool withToken;
}

String _addOperators(String file, String content, List<ExtraOperator> extra) {
  final json = jsonDecode(content) as Map<String, Object?>;
  Map<String, Object?> copy(Object? value) =>
      jsonDecode(jsonEncode(value)) as Map<String, Object?>;

  switch (file) {
    case ArknightsDataSource.characterTableFile:
      for (final operator in extra) {
        final character = copy(json['char_002_amiya'])
          ..['name'] = operator.name
          ..['appellation'] = operator.name
          ..['description'] = 'Hits <\$ba.${operator.id}>hard</>';
        if (operator.newFaction) {
          character['nationId'] = 'power_${operator.id}';
        }
        final phases = character['phases']! as List<Object?>;
        (phases[1]! as Map<String, Object?>)['evolveCost'] = [
          {'id': operator.itemId, 'count': 2, 'type': 'MATERIAL'},
        ];
        json[operator.id] = character;
        if (operator.withToken) {
          character['displayTokenDict'] = {'token_${operator.id}': true};
          json['token_${operator.id}'] = copy(json['char_002_amiya'])
            ..['name'] = '${operator.name} Summon'
            ..['profession'] = 'TOKEN'
            ..['description'] = 'Links <\$ba.${operator.id}.token>it</>'
            ..['skills'] = <Object?>[];
        }
      }
    case ArknightsDataSource.handbookTeamTableFile:
      for (final operator in extra) {
        if (operator.newFaction) {
          json['power_${operator.id}'] = {
            'powerId': 'power_${operator.id}',
            'powerName': '${operator.name} Nation',
          };
        }
      }
    case ArknightsDataSource.handbookInfoTableFile:
      final handbook = json['handbookDict']! as Map<String, Object?>;
      for (final operator in extra) {
        handbook[operator.id] = {
          'charID': operator.id,
          'infoName': operator.name,
        };
      }
    case ArknightsDataSource.itemTableFile:
      final items = json['items']! as Map<String, Object?>;
      for (final operator in extra) {
        final itemName = operator.itemName;
        if (itemName != null) {
          items[operator.itemId] = copy(items['30012'])
            ..['itemId'] = operator.itemId
            ..['name'] = itemName
            ..['sortId'] = 20;
        }
      }
    case ArknightsDataSource.gamedataConstFile:
      final terms = json['termDescriptionDict']! as Map<String, Object?>;
      for (final operator in extra) {
        final key = 'ba.${operator.id}';
        terms[key] = {
          'termId': key,
          'termName': operator.name,
          'description': 'Like <\$$key.more>more</>',
        };
        terms['$key.more'] = {
          'termId': '$key.more',
          'termName': 'More',
          'description': 'Even more',
        };
        if (operator.withToken) {
          terms['$key.token'] = {
            'termId': '$key.token',
            'termName': 'Token term',
            'description': 'Summon term',
          };
        }
      }
  }
  return jsonEncode(json);
}

String _suffixLabels(String file, String content, String suffix) {
  final json = jsonDecode(content) as Map<String, Object?>;
  void rename(Object? entry, String field) {
    if (entry is Map<String, Object?>) {
      final name = entry[field];
      if (name is String && name.trim().isNotEmpty) {
        entry[field] = '${name.trim()}$suffix';
      }
    }
  }

  switch (file) {
    case ArknightsDataSource.characterTableFile:
      for (final character in json.values.whereType<Map<String, Object?>>()) {
        final tags = character['tagList'];
        if (tags is List) {
          character['tagList'] = [
            for (final tag in tags.cast<String>())
              tag.trim().isEmpty ? tag : '${tag.trim()}$suffix',
          ];
        }
      }
    case ArknightsDataSource.handbookTeamTableFile:
      for (final power in json.values) {
        rename(power, 'powerName');
      }
    case ArknightsDataSource.uniequipTableFile:
      for (final branch
          in (json['subProfDict']! as Map<String, Object?>).values) {
        rename(branch, 'subProfessionName');
      }
    case ArknightsDataSource.gamedataConstFile:
      for (final term
          in (json['termDescriptionDict']! as Map<String, Object?>).values) {
        rename(term, 'termName');
      }
    case gachaTableFixture:
      for (final tag in json['gachaTags']! as List<Object?>) {
        rename(tag, 'tagName');
      }
  }
  return jsonEncode(json);
}
