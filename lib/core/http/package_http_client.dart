import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../errors/app_failure.dart';
import 'http_client.dart';

class PackageHttpClient implements NexusHttpClient {
  PackageHttpClient({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// Same user agent as the Tauri backend's reqwest client.
  static const _headers = {'user-agent': 'ArknightsNexus/0.1.0'};

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<String> getText(Uri uri) async {
    final response = await _get(uri);
    return response.body;
  }

  @override
  Future<HttpTextResponse> getTextWithRevision(Uri uri) async {
    final response = await _get(uri);
    return HttpTextResponse(
      response.body,
      revision: response.headers['etag'] ?? response.headers['last-modified'],
    );
  }

  @override
  Future<Uint8List> getBytes(Uri uri) async {
    final response = await _get(uri);
    return response.bodyBytes;
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      final response = await _client.get(uri, headers: _headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw NetworkFailure(
          'GET $uri failed with HTTP ${response.statusCode}',
        );
      }

      return response;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw NetworkFailure('GET $uri failed: $error');
    }
  }
}
