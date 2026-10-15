import 'dart:typed_data';

/// Text body plus the response revision (`ETag`, else `Last-Modified`).
class HttpTextResponse {
  const HttpTextResponse(this.body, {this.revision});

  final String body;
  final String? revision;
}

abstract interface class NexusHttpClient {
  Future<String> getText(Uri uri);

  /// Like [getText], also returning the revision headers the Tauri backend
  /// recorded as the snapshot `sourceRevision`.
  Future<HttpTextResponse> getTextWithRevision(Uri uri);

  Future<Uint8List> getBytes(Uri uri);
}
