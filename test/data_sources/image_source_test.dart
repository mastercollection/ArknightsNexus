import 'package:arknight_nexus/data_sources/image_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeImageId', () {
    test('trims and accepts safe ids', () {
      expect(normalizeImageId('  char_002_amiya  '), 'char_002_amiya');
      expect(normalizeImageId('skchr_amiya_1[2]'), 'skchr_amiya_1[2]');
    });

    test('rejects empty and unsafe ids', () {
      expect(normalizeImageId(''), isNull);
      expect(normalizeImageId('   '), isNull);
      expect(normalizeImageId('a/b'), isNull);
      expect(normalizeImageId(r'a\b'), isNull);
      expect(normalizeImageId('..'), isNull);
      expect(normalizeImageId('a b'), isNull);
    });
  });

  group('buildImageDescriptor', () {
    test('returns null for invalid id', () {
      expect(buildImageDescriptor(CachedImageKind.portrait, '../x'), isNull);
    });

    test('builds portrait paths and url', () {
      final descriptor =
          buildImageDescriptor(CachedImageKind.portrait, 'char_002_amiya')!;
      expect(descriptor.relativePath, 'images/portraits/char_002_amiya.png');
      expect(
        descriptor.partRelativePath,
        'images/portraits/char_002_amiya.png.part',
      );
      expect(descriptor.candidateUrls, [
        '$imageRemoteBaseUrl/avatar/ASSISTANT/char_002_amiya.png',
      ]);
    });

    test('maps moduleEquip original to default', () {
      final descriptor =
          buildImageDescriptor(CachedImageKind.moduleEquip, 'original')!;
      expect(descriptor.relativePath, 'images/modules/equip/default.png');
      expect(descriptor.candidateUrls, [
        '$imageRemoteBaseUrl/equip/default.png',
      ]);
    });

    test('prefixes skill icon url', () {
      final descriptor =
          buildImageDescriptor(CachedImageKind.skillIcon, 'amiya_1')!;
      expect(descriptor.candidateUrls, [
        '$imageRemoteBaseUrl/skills/skill_icon_amiya_1.png',
      ]);
    });

    test('builds item icon url', () {
      final descriptor =
          buildImageDescriptor(CachedImageKind.itemIcon, 'sugar')!;
      expect(descriptor.candidateUrls, [
        '$imageRemoteBaseUrl/items/sugar.png',
      ]);
    });

    test('moduleType adds uppercase candidate when id is not uppercase', () {
      final descriptor =
          buildImageDescriptor(CachedImageKind.moduleType, 'cmd-y')!;
      expect(descriptor.candidateUrls, [
        '$imageRemoteBaseUrl/equipt/cmd-y.png',
        '$imageRemoteBaseUrl/equipt/CMD-Y.png',
      ]);
    });

    test('moduleType uses single candidate when id is already uppercase', () {
      final descriptor =
          buildImageDescriptor(CachedImageKind.moduleType, 'CMD-Y')!;
      expect(descriptor.candidateUrls, [
        '$imageRemoteBaseUrl/equipt/CMD-Y.png',
      ]);
    });
  });
}
