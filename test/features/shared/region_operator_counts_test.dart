import 'package:arknight_nexus/app/providers.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/features/shared/region_operator_counts.dart';
import 'package:arknight_nexus/features/shared/region_sync.dart';
import 'package:arknight_nexus/i18n/nexus_i18n.dart';
import 'package:arknight_nexus/services/operator_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

OperatorSummary _operator(String id, {String? source}) => OperatorSummary(
      id: id,
      name: id,
      rarity: 6,
      profession: 'CASTER',
      branch: 'splashcaster',
      thumbnailHue: 0,
      unreleasedSource: source,
    );

class _FakeOperators implements OperatorService {
  _FakeOperators(this.operators);

  final List<OperatorSummary> operators;
  final regions = <RegionCode>[];

  @override
  Future<List<OperatorSummary>> listOperators(OperatorQuery query) async {
    regions.add(query.region);
    return operators;
  }

  @override
  Future<OperatorDetail?> getOperatorDetail(
    RegionCode region,
    String operatorId,
  ) async =>
      null;
}

void main() {
  group('formatOperatorCounts', () {
    test('adds the unreleased count when there is one', () {
      const counts = RegionOperatorCounts(native: 415, unreleased: 17);
      expect(
        formatOperatorCounts(const NexusI18n(RegionCode.kr), counts),
        '415명 · 미실장 17명',
      );
      expect(
        formatOperatorCounts(const NexusI18n(RegionCode.en), counts),
        '415 operators · 17 unreleased',
      );
      expect(
        formatOperatorCounts(const NexusI18n(RegionCode.cn), counts),
        '415名 · 未实装 17名',
      );
    });

    test('shows the native count alone without unreleased operators', () {
      const counts = RegionOperatorCounts(native: 1234, unreleased: 0);
      expect(
        formatOperatorCounts(const NexusI18n(RegionCode.kr), counts),
        '1,234명',
      );
    });
  });

  test('regionOperatorCountsProvider splits native and unreleased', () async {
    final service = _FakeOperators([
      _operator('char_1'),
      _operator('char_2'),
      _operator('char_3', source: 'cn'),
    ]);
    final container = ProviderContainer(
      overrides: [
        operatorServiceProvider.overrideWithValue(service),
        regionEnsureProvider.overrideWith((ref) async {}),
      ],
    );
    addTearDown(container.dispose);
    container.read(regionProvider.notifier).state = RegionCode.jp;

    final subscription =
        container.listen(regionOperatorCountsProvider, (_, __) {});
    addTearDown(subscription.close);
    final counts = await container.read(regionOperatorCountsProvider.future);

    expect(counts, const RegionOperatorCounts(native: 2, unreleased: 1));
    expect(counts!.total, 3);
    expect(service.regions, [RegionCode.jp]);
  });

  test('regionOperatorCountsProvider is null for a region without data',
      () async {
    final container = ProviderContainer(
      overrides: [
        operatorServiceProvider.overrideWithValue(_FakeOperators(const [])),
        regionEnsureProvider.overrideWith((ref) async {}),
      ],
    );
    addTearDown(container.dispose);
    final subscription =
        container.listen(regionOperatorCountsProvider, (_, __) {});
    addTearDown(subscription.close);

    expect(await container.read(regionOperatorCountsProvider.future), isNull);
  });
}
