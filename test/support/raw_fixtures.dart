import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/data_sources/arknights_data_source.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';

import 'fake_http_client.dart';

/// Serves `test/support/fixtures/raw` as [region]'s upstream tables, with
/// data version [versionControl] (68.2.0 by default). Each [extraOperators]
/// entry adds an operator the fixtures do not have (see [ExtraOperator]).
Future<void> registerRawFixtures(
  FakeHttpClient http,
  RegionCode region, {
  String versionControl = '68.2.0',
  List<ExtraOperator> extraOperators = const [],
}) async {
  final descriptor = region.descriptor;
  http.registerText(
    descriptor.dataVersionUri,
    'Stream://torappu-data/v068/rel68.0\n'
    'Change:100033 on 2025/12/09\n'
    'VersionControl:$versionControl\n',
  );

  for (final file in ArknightsDataSource.requiredTableFiles) {
    var content = await File('test/support/fixtures/raw/$file').readAsString();
    if (extraOperators.isNotEmpty) {
      content = _addOperators(file, content, extraOperators);
    }
    http.registerText(descriptor.tableUri(file), content);
  }
}

/// An operator released after the fixture ones, in list order (the last is
/// the newest): a copy of Amiya named [name] whose elite 1 costs two
/// [itemId] (a material named [itemName] the fixtures do not have, added
/// when given) and whose trait links the term `ba.<id>`, which in turn
/// links `ba.<id>.more`.
class ExtraOperator {
  const ExtraOperator({
    required this.id,
    required this.name,
    this.itemId = '30012',
    this.itemName,
  });

  final String id;
  final String name;
  final String itemId;
  final String? itemName;
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
        final phases = character['phases']! as List<Object?>;
        (phases[1]! as Map<String, Object?>)['evolveCost'] = [
          {'id': operator.itemId, 'count': 2, 'type': 'MATERIAL'},
        ];
        json[operator.id] = character;
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
      }
  }
  return jsonEncode(json);
}
