import 'dart:io';

import 'package:arknight_nexus/domain/operator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/region_labels.dart';

void main() {
  // CN and KR names of the same ids; CN also has a faction KR lacks.
  const cn = RegionLabels(
    powers: {'iberia': '伊比利亚', 'rhodes': '罗德岛', 'new_nation': '新势力'},
    branches: {'alchemist': '炼金师'},
    recruitTags: {'23': '减速', '24': '削弱'},
    baTerms: {'ba.sluggish': '迟缓', 'ba.cn_only': '新状态'},
  );
  const kr = RegionLabels(
    powers: {'iberia': '이베리아', 'rhodes': '로도스 아일랜드'},
    branches: {'alchemist': '연금술사'},
    recruitTags: {'23': '감속', '24': '디버프'},
    baTerms: {'ba.sluggish': '감속'},
  );

  const operator = OperatorDetail(
    id: 'char_900_new',
    name: '新干员',
    codename: '新干员',
    rarity: 6,
    profession: 'Caster',
    thumbnailHue: 0,
    releaseOrder: 0,
    branch: '炼金师',
    teams: ['罗德岛'],
    nations: ['伊比利亚', '新势力'],
    groups: ['Unknown Group'],
    baTags: ['新状态', '迟缓'],
    quote: '引用 <\$ba.sluggish>迟缓</>',
    tags: ['削弱', '减速'],
    archetypeDescription: '描述 <\$ba.cn_only>新状态</>',
    traits: [
      OperatorTrait(
        groupKey: 'trait-0',
        description: '<@ba.sluggish>迟缓</>',
        elite: 0,
        level: 1,
        requiredPotentialRank: 0,
      ),
    ],
  );

  test('puts the labels whose id the region has in its language', () {
    final stats = LabelLocalizationStats();
    final localized =
        localizeLabels(operator, source: cn, target: kr, stats: stats);

    expect(localized.branch, '연금술사');
    expect(localized.teams, ['로도스 아일랜드']);
    // A faction KR does not have keeps the CN name.
    expect(localized.nations, ['이베리아', '新势力']);
    // Not a name of the source's table either (a humanized id fallback).
    expect(localized.groups, ['Unknown Group']);
    expect(localized.tags, ['디버프', '감속']);
    expect(localized.baTags, ['新状态', '감속']);
    expect(stats.mapped, 6);
    expect(stats.kept, {
      'nations: 新势力': 1,
      'groups: Unknown Group': 1,
      'baTags: 新状态': 1,
    });

    // Descriptive text stays in the source language.
    expect(localized.name, '新干员');
    expect(localized.quote, operator.quote);
    expect(localized.archetypeDescription, operator.archetypeDescription);
    expect(localized.traits.single.description, '<@ba.sluggish>迟缓</>');
  });

  test('keeps the labels as they are between regions with the same names', () {
    final localized = localizeLabels(operator, source: cn, target: cn);
    expect(localized.toJson(), operator.toJson());
  });

  test('reads the names from the upstream tables', () async {
    Future<String> read(String file) =>
        File('test/support/fixtures/raw/$file').readAsString();
    final labels = RegionLabels.fromTables({
      for (final file in RegionLabels.tableFiles) file: await read(file),
    });

    expect(labels.powers, {'power_ri': 'Rhodes Island'});
    expect(labels.branches, {'caster_core': 'Core Caster'});
    expect(labels.recruitTags, {'1': 'Guard', '19': 'DPS', '16': 'Support'});
    expect(labels.baTerms, {'ba.stun': 'Stun', 'ba.sluggish': 'Slow'});
  });
}
