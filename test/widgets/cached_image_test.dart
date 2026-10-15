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
}
