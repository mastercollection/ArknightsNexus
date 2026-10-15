import 'dart:typed_data';

import 'package:arknight_nexus/core/errors/app_failure.dart';
import 'package:arknight_nexus/core/http/package_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PackageHttpClient', () {
    test('returns response text for successful GET requests', () async {
      final client = PackageHttpClient(
        client: MockClient((request) async {
          expect(request.url, Uri.parse('https://example.test/data.txt'));
          return http.Response('hello', 200);
        }),
      );

      expect(
        await client.getText(Uri.parse('https://example.test/data.txt')),
        'hello',
      );
    });

    test('returns response bytes for successful GET requests', () async {
      final client = PackageHttpClient(
        client: MockClient((request) async {
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );

      expect(
        await client.getBytes(Uri.parse('https://example.test/data.bin')),
        Uint8List.fromList([1, 2, 3]),
      );
    });

    test('throws NetworkFailure for non-success responses', () async {
      final client = PackageHttpClient(
        client: MockClient((request) async {
          return http.Response('missing', 404);
        }),
      );

      expect(
        () => client.getText(Uri.parse('https://example.test/missing.txt')),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
