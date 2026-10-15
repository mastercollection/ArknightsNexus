import 'dart:typed_data';

import 'package:arknight_nexus/core/errors/app_failure.dart';
import 'package:arknight_nexus/core/http/http_client.dart';

class FakeHttpClient implements NexusHttpClient {
  final requestedUris = <Uri>[];
  final _textResponses = <Uri, String>{};
  final _byteResponses = <Uri, Uint8List>{};
  final _revisions = <Uri, String>{};

  void registerRevision(Uri uri, String revision) {
    _revisions[uri] = revision;
  }

  void registerText(Uri uri, String body) {
    _textResponses[uri] = body;
  }

  void registerBytes(Uri uri, List<int> bytes) {
    _byteResponses[uri] = Uint8List.fromList(bytes);
  }

  @override
  Future<String> getText(Uri uri) async {
    requestedUris.add(uri);

    final response = _textResponses[uri];
    if (response == null) {
      throw NetworkFailure('No fake text response registered for $uri');
    }

    return response;
  }

  @override
  Future<HttpTextResponse> getTextWithRevision(Uri uri) async {
    return HttpTextResponse(await getText(uri), revision: _revisions[uri]);
  }

  @override
  Future<Uint8List> getBytes(Uri uri) async {
    requestedUris.add(uri);

    final response = _byteResponses[uri];
    if (response == null) {
      throw NetworkFailure('No fake byte response registered for $uri');
    }

    return Uint8List.fromList(response);
  }
}
