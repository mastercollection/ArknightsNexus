import 'dart:typed_data';

import 'package:arknight_nexus/data_sources/image_source.dart';
import 'package:arknight_nexus/services/image_cache_service.dart';
import 'package:arknight_nexus/services/network_image_service.dart';
import 'package:arknight_nexus/widgets/resolved_image_provider.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_http_client.dart';

void main() {
  group('NetworkImageService', () {
    late FakeHttpClient http;
    late NetworkImageService service;

    setUp(() {
      http = FakeHttpClient();
      service = NetworkImageService(httpClient: http);
    });

    test('downloads once and keeps the bytes for the session', () async {
      final url = Uri.parse('$imageRemoteBaseUrl/items/30012.png');
      http.registerBytes(url, [1, 2, 3]);
      const request = ImageRequest(kind: CachedImageKind.itemIcon, id: '30012');

      final results = await Future.wait([
        service.resolve(request),
        service.resolve(request),
      ]);
      final again = await service.resolve(request);

      expect(results.first.isReady, isTrue);
      expect(results.first.bytes, [1, 2, 3]);
      expect(results.first.filePath, isNull);
      expect(identical(again, results.first), isTrue);
      expect(http.requestedUris, [url]);
    });

    test('tries the next candidate URL', () async {
      final upper = Uri.parse('$imageRemoteBaseUrl/equipt/SPC-X.png');
      http.registerBytes(upper, [9]);

      final result = await service.resolve(
        const ImageRequest(kind: CachedImageKind.moduleType, id: 'spc-x'),
      );

      expect(result.bytes, [9]);
      expect(http.requestedUris, [
        Uri.parse('$imageRemoteBaseUrl/equipt/spc-x.png'),
        upper,
      ]);
    });

    test('reports a missing image and retries it next time', () async {
      const request = ImageRequest(kind: CachedImageKind.portrait, id: 'none');

      expect((await service.resolve(request)).isReady, isFalse);
      await service.resolve(request);

      expect(http.requestedUris, hasLength(2));
    });

    test('rejects unsafe ids without a request', () async {
      final result = await service.resolve(
        const ImageRequest(kind: CachedImageKind.portrait, id: '../x'),
      );

      expect(result.isReady, isFalse);
      expect(http.requestedUris, isEmpty);
    });
  });

  group('resolvedImageProvider', () {
    test('bytes become a MemoryImage', () {
      final bytes = Uint8List.fromList([1]);
      final provider = resolvedImageProvider(ResolvedImage.bytes(bytes));

      expect(provider, isA<MemoryImage>());
      expect((provider! as MemoryImage).bytes, same(bytes));
    });

    test('a cached file becomes a FileImage on native builds', () {
      final provider = resolvedImageProvider(
        const ResolvedImage.file('/cache/images/items/30012.png'),
      );

      expect(provider, isA<FileImage>());
      expect(
        (provider! as FileImage).file.path,
        '/cache/images/items/30012.png',
      );
    });

    test('a missing image has no provider', () {
      expect(resolvedImageProvider(const ResolvedImage.missing()), isNull);
    });
  });
}
