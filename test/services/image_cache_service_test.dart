import 'dart:io';

import 'package:arknight_nexus/data_sources/image_source.dart';
import 'package:arknight_nexus/repositories/file_image_cache_repository.dart';
import 'package:arknight_nexus/services/image_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_directories.dart';
import '../support/fake_http_client.dart';

void main() {
  group('DartImageCacheService', () {
    late Directory tempRoot;
    late FakeAppDirectories directories;
    late FakeHttpClient httpClient;
    late FileImageCacheRepository repository;
    late DartImageCacheService service;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('nexus-image-test-');
      directories = FakeAppDirectories(tempRoot);
      httpClient = FakeHttpClient();
      repository = FileImageCacheRepository(directories);
      service = DartImageCacheService(
        httpClient: httpClient,
        repository: repository,
      );
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('downloads, caches, and returns a ready file', () async {
      const id = 'char_002_amiya';
      final url = Uri.parse(
        '$imageRemoteBaseUrl/avatar/ASSISTANT/$id.png',
      );
      httpClient.registerBytes(url, [1, 2, 3, 4]);

      final result = await service.resolve(
        const ImageRequest(kind: CachedImageKind.portrait, id: id),
      );

      expect(result.isReady, isTrue);
      expect(await result.file!.readAsBytes(), [1, 2, 3, 4]);
      expect(result.file!.path, endsWith('char_002_amiya.png'));

      // No stale .part file remains.
      final part = await repository.fileFor(
        'images/portraits/$id.png.part',
      );
      expect(await part.exists(), isFalse);
    });

    test('serves a second request from disk without re-downloading', () async {
      const id = 'sugar';
      final url = Uri.parse('$imageRemoteBaseUrl/items/$id.png');
      httpClient.registerBytes(url, [9]);

      await service.resolve(
        const ImageRequest(kind: CachedImageKind.itemIcon, id: id),
      );

      // Fresh service instance shares the cache directory but not memory cache.
      final coldService = DartImageCacheService(
        httpClient: FakeHttpClient(),
        repository: repository,
      );
      final result = await coldService.resolve(
        const ImageRequest(kind: CachedImageKind.itemIcon, id: id),
      );

      expect(result.isReady, isTrue);
    });

    test('falls back to the next candidate url on failure', () async {
      const id = 'cmd-y';
      final upper = Uri.parse('$imageRemoteBaseUrl/equipt/CMD-Y.png');
      // Lowercase candidate is not registered, so it fails first.
      httpClient.registerBytes(upper, [7, 7]);

      final result = await service.resolve(
        const ImageRequest(kind: CachedImageKind.moduleType, id: id),
      );

      expect(result.isReady, isTrue);
      expect(await result.file!.readAsBytes(), [7, 7]);
    });

    test('returns missing when all candidates fail', () async {
      final result = await service.resolve(
        const ImageRequest(kind: CachedImageKind.portrait, id: 'unknown'),
      );

      expect(result.status, ImageStatus.missing);
      expect(result.file, isNull);
    });

    test('returns missing for an invalid id without hitting the network',
        () async {
      final result = await service.resolve(
        const ImageRequest(kind: CachedImageKind.portrait, id: '../escape'),
      );

      expect(result.status, ImageStatus.missing);
      expect(httpClient.requestedUris, isEmpty);
    });
  });
}
