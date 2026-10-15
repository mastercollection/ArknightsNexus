import 'dart:io';

import 'package:arknight_nexus/data_sources/arknights_data_source.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';

import 'fake_http_client.dart';

/// Serves `test/support/fixtures/raw` as [region]'s upstream tables, with
/// data version 68.2.0.
Future<void> registerRawFixtures(FakeHttpClient http, RegionCode region) async {
  final descriptor = region.descriptor;
  http.registerText(
    descriptor.dataVersionUri,
    'Stream://torappu-data/v068/rel68.0\n'
    'Change:100033 on 2025/12/09\n'
    'VersionControl:68.2.0\n',
  );

  for (final file in ArknightsDataSource.requiredTableFiles) {
    final content =
        await File('test/support/fixtures/raw/$file').readAsString();
    http.registerText(descriptor.tableUri(file), content);
  }
}
