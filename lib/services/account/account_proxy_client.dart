/// Imports a game account through the account proxy Worker (`worker/`),
/// which runs the whole Yostar login for the web build: the game servers
/// send no CORS headers, so the browser cannot call them itself.
///
/// Two requests per import: `send-code`, then `import`, which answers with
/// the raw `account/syncData` body. Bodies go as `text/plain` so the
/// browser skips the CORS preflight.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_failure.dart';
import 'account_source.dart';
import 'yostar_account_client.dart';

class AccountProxyClient implements AccountSource {
  AccountProxyClient(
    this.server,
    this.baseUri, {
    http.Client? client,
    String? deviceId,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        deviceId = deviceId ?? YostarDeviceIds.random().deviceId;

  /// The deployed Worker. Set for the web build with
  /// `--dart-define=NEXUS_ACCOUNT_PROXY_URL=https://<worker>.workers.dev/`;
  /// empty leaves the web import off.
  static const baseUrl = String.fromEnvironment('NEXUS_ACCOUNT_PROXY_URL');

  static const configured = baseUrl != '';

  final YostarServer server;
  final Uri baseUri;

  /// Sent with both steps, so the login keeps one device like the game
  /// client does.
  final String deviceId;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<void> sendCode(String email) async {
    await _post('send-code', {'email': email});
  }

  @override
  Future<Map<String, Object?>> fetchSyncData(String email, String code) =>
      _post('import', {'email': email, 'code': code});

  @override
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    final base = baseUri.path.endsWith('/')
        ? baseUri
        : baseUri.replace(path: '${baseUri.path}/');
    final http.Response response;
    try {
      response = await _client.post(
        base.resolve(path),
        headers: {'content-type': 'text/plain; charset=utf-8'},
        body: jsonEncode({
          'server': server.name,
          'deviceId': deviceId,
          ...body,
        }),
      );
    } catch (error) {
      throw NetworkFailure('Account proxy $path failed: $error');
    }

    final Object? data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw NetworkFailure(
        'Account proxy $path failed with HTTP ${response.statusCode}',
      );
    }
    if (data is! Map<String, Object?>) {
      throw NetworkFailure('Account proxy $path returned no JSON object');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountFailure(
        '${data['step'] ?? path} failed: '
        '${data['error'] ?? 'HTTP ${response.statusCode}'}',
        code: data['code'] ?? response.statusCode,
      );
    }
    return data;
  }
}
