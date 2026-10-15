import 'dart:convert';

import 'package:arknight_nexus/domain/penguin_matrix.dart';
import 'package:arknight_nexus/services/penguin_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_http_client.dart';

const _endpoint = 'https://penguin-stats.io/PenguinStats/api/v2/result/matrix';

Uri _matrixUri(String itemId, String server) {
  return Uri.parse(_endpoint).replace(
    queryParameters: {'itemFilter': itemId, 'server': server},
  );
}

Map<String, Object> _entry(String stageId, String itemId, int qty, int times) {
  return {
    'stageId': stageId,
    'itemId': itemId,
    'quantity': qty,
    'times': times,
  };
}

void main() {
  group('DartPenguinStatsService', () {
    late FakeHttpClient httpClient;
    late DartPenguinStatsService service;

    setUp(() {
      httpClient = FakeHttpClient();
      service = DartPenguinStatsService(httpClient: httpClient);
    });

    test('returns empty for a blank item id without a request', () async {
      final result = await service.getItemMatrix('   ');
      expect(result, isEmpty);
      expect(httpClient.requestedUris, isEmpty);
    });

    test(
      'parses the matrix wrapper, filters, derives rate, and sorts',
      () async {
        httpClient.registerText(
          _matrixUri('30012', 'CN'),
          jsonEncode({
            'matrix': [
              // lower rate (0.5) listed first to prove sorting.
              _entry('main_01-07', '30012', 50, 100),
              _entry('main_01-01', '30012', 80, 100),
              _entry('x', '30013', 10, 10), // filtered: wrong item.
              _entry('y', '30012', 10, 0), // filtered: zero times.
              _entry('z', '30012', 0, 10), // filtered: zero quantity.
            ],
          }),
        );

        final result = await service.getItemMatrix('30012');

        expect(result.map((e) => e.stageId), ['main_01-01', 'main_01-07']);
        expect(result.first.dropRate, closeTo(0.8, 1e-9));
        expect(result.first.times, 100);
      },
    );

    test('parses a bare array payload', () async {
      httpClient.registerText(
        _matrixUri('30012', 'CN'),
        jsonEncode([_entry('main_01-01', '30012', 1, 4)]),
      );

      final result = await service.getItemMatrix('30012');

      expect(result, hasLength(1));
      expect(result.single.dropRate, closeTo(0.25, 1e-9));
    });

    test('requests the selected server and caches per server/item', () async {
      httpClient.registerText(
        _matrixUri('30012', 'KR'),
        jsonEncode({
          'matrix': [_entry('s', '30012', 1, 2)],
        }),
      );

      await service.getItemMatrix('30012', server: PenguinServer.kr);
      await service.getItemMatrix('30012', server: PenguinServer.kr);

      // Second call served from cache: only one network request total.
      expect(
        httpClient.requestedUris.where(
          (u) => u.queryParameters['server'] == 'KR',
        ),
        hasLength(1),
      );
    });
  });
}
