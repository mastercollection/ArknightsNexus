import 'dart:convert';

import 'package:arknight_nexus/core/errors/app_failure.dart';
import 'package:arknight_nexus/services/account/account_proxy_client.dart';
import 'package:arknight_nexus/services/account/yostar_account_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const deviceId = '0123456789abcdef0123456789abcdef';

  AccountProxyClient proxy(
    Future<http.Response> Function(http.Request request) handler, {
    String base = 'https://proxy.example.workers.dev',
  }) =>
      AccountProxyClient(
        YostarServer.en,
        Uri.parse(base),
        client: MockClient(handler),
        deviceId: deviceId,
      );

  test('sends the code and imports with one device id', () async {
    final requests = <http.Request>[];
    final client = proxy((request) async {
      requests.add(request);
      if (request.url.path == '/import') {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'result': 0,
              'user': {
                'status': {'nickName': '독타'},
              },
            }),
          ),
          200,
        );
      }
      return http.Response('{"ok":true}', 200);
    });

    await client.sendCode('a@b.c');
    final data = await client.fetchSyncData('a@b.c', '123456');

    expect(
      requests.map((request) => request.url.toString()),
      [
        'https://proxy.example.workers.dev/send-code',
        'https://proxy.example.workers.dev/import',
      ],
    );
    // text/plain keeps the browser from sending a CORS preflight.
    expect(requests.first.headers['content-type'], startsWith('text/plain'));
    expect(jsonDecode(requests.first.body), {
      'server': 'en',
      'deviceId': deviceId,
      'email': 'a@b.c',
    });
    expect(jsonDecode(requests.last.body), {
      'server': 'en',
      'deviceId': deviceId,
      'email': 'a@b.c',
      'code': '123456',
    });
    expect(
      ((data['user'] as Map)['status'] as Map)['nickName'],
      '독타',
    );
  });

  test('keeps a base path', () async {
    Uri? url;
    final client = proxy(
      (request) async {
        url = request.url;
        return http.Response('{"ok":true}', 200);
      },
      base: 'https://example.com/proxy',
    );
    await client.sendCode('a@b.c');
    expect(url.toString(), 'https://example.com/proxy/send-code');
  });

  test('reports the failed step and code', () async {
    final client = proxy(
      (request) async => http.Response(
        jsonEncode({'error': 'bad code', 'step': 'get-auth', 'code': 100403}),
        422,
      ),
    );
    await expectLater(
      client.fetchSyncData('a@b.c', '000000'),
      throwsA(
        isA<AccountFailure>()
            .having(
              (failure) => failure.message,
              'message',
              'get-auth failed: bad code',
            )
            .having((failure) => failure.code, 'code', 100403),
      ),
    );
  });

  test('turns transport and non-JSON failures into network failures', () async {
    final offline = proxy((request) async => throw http.ClientException('x'));
    await expectLater(
      offline.sendCode('a@b.c'),
      throwsA(isA<NetworkFailure>()),
    );

    final html = proxy((request) async => http.Response('<html>', 502));
    await expectLater(html.sendCode('a@b.c'), throwsA(isA<NetworkFailure>()));
  });

  test('stays off unless the proxy URL is defined', () {
    expect(AccountProxyClient.configured, AccountProxyClient.baseUrl != '');
  });
}
