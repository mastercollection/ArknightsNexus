import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/features/stages/stage_enemy_view.dart';
import 'package:arknight_nexus/i18n/nexus_i18n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OperatorSummary operator(String id, List<String> baTags) => OperatorSummary(
        id: id,
        name: id,
        rarity: 6,
        profession: 'Caster',
        branch: '',
        teams: const [],
        nations: const [],
        groups: const [],
        baTags: baTags,
        thumbnailHue: 0,
      );

  test('matches immunities to operators by their battle term names', () {
    final info = StageImmunityInfo.build(
      {'ba.stun': '기절', 'ba.sleep': '수면', 'ba.palsy': '마비'},
      [
        operator('char_stun', ['기절', '정지']),
        operator('char_sleep', ['수면']),
        operator('char_both', ['수면', '기절']),
      ],
    );

    expect(
      info.operators['stun']!.map((o) => o.id),
      ['char_stun', 'char_both'],
    );
    expect(
      info.operators['sleep']!.map((o) => o.id),
      ['char_sleep', 'char_both'],
    );
    expect(info.operators['palsy'], isEmpty);
    // No term name in the data: no operators and the app's own label.
    expect(info.operators.containsKey('silence'), isFalse);

    const i18n = NexusI18n(RegionCode.kr);
    expect(info.label(i18n, 'stun'), '기절');
    expect(info.label(i18n, 'silence'), '침묵');
  });
}
