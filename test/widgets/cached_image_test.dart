import 'dart:typed_data';

import 'package:arknight_nexus/app/providers.dart';
import 'package:arknight_nexus/data_sources/image_source.dart';
import 'package:arknight_nexus/services/image_cache_service.dart';
import 'package:arknight_nexus/widgets/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingImageCacheService implements ImageCacheService {
  final requests = <ImageRequest>[];

  @override
  Future<ResolvedImage> resolve(ImageRequest request) async {
    requests.add(request);
    return const ResolvedImage.missing();
  }

  @override
  Future<void> prefetch(List<ImageRequest> requests) async {}
}

/// Resolves every image to a 1x1 transparent PNG.
class _ReadyImageCacheService implements ImageCacheService {
  final requests = <ImageRequest>[];

  static final _png = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  Future<ResolvedImage> resolve(ImageRequest request) async {
    requests.add(request);
    return ResolvedImage.bytes(_png);
  }

  @override
  Future<void> prefetch(List<ImageRequest> requests) async {}
}

Future<void> _pump(WidgetTester tester, ImageCacheService service) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [imageCacheServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(
        home: Scaffold(
          body: CachedImage(
            kind: CachedImageKind.skillIcon,
            id: 'amiya_1',
            size: 40,
            placeholder: Text('fallback'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows placeholder when the image is missing', (tester) async {
    await _pump(tester, _RecordingImageCacheService());

    expect(find.text('fallback'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('requests the configured kind and id from the service',
      (tester) async {
    final service = _RecordingImageCacheService();

    await _pump(tester, service);

    expect(service.requests, hasLength(1));
    expect(service.requests.single.kind, CachedImageKind.skillIcon);
    expect(service.requests.single.id, 'amiya_1');
  });

  testWidgets('shows an image resolved earlier in its first frame',
      (tester) async {
    final service = _ReadyImageCacheService();
    await _pump(tester, service);
    expect(find.byType(Image), findsOneWidget);

    // Leave and come back: no placeholder frame, no second lookup.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [imageCacheServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(
          home: Scaffold(
            body: CachedImage(
              kind: CachedImageKind.skillIcon,
              id: 'amiya_1',
              size: 40,
              placeholder: Text('fallback'),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('fallback'), findsNothing);
    expect(service.requests, hasLength(1));
  });
}
