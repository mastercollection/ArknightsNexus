import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/features/operators/operator_detail_view_model.dart';
import 'package:arknight_nexus/i18n/nexus_i18n.dart';
import 'package:flutter_test/flutter_test.dart';

const _i18n = NexusI18n(RegionCode.kr);

String _label(String text) {
  final match = RegExp(r'\{[^{}]+\}').firstMatch(text)!;
  return slotLabel(text, match.start, match.end);
}

String _labelOf(String text, String key) {
  final match = RegExp('\\{-?$key(:[^{}]*)?\\}').firstMatch(text)!;
  return slotLabel(text, match.start, match.end);
}

OperatorSkillLevel _level(
  int level,
  String description,
  Map<String, double> values, {
  int duration = 20,
}) {
  return OperatorSkillLevel(
    level: level,
    spCost: 30 - level,
    initialSp: 5,
    duration: duration,
    description: description,
    blackboard: [
      for (final MapEntry(:key, :value) in values.entries)
        OperatorBlackboardEntry(key: key, value: value),
    ],
  );
}

void main() {
  group('slotLabel', () {
    test('keeps the words before the value and the text glued after it', () {
      const text = '아군 유닛이 하루카에게 치료받을 시 주변의 적 {max_target_extra}명에게 '
          '치유량의 {atk_scale_extra:0%}에 해당하는 마법 대미지를 입힘\n'
          '2회차부터 공격력 +{atk:0%}, 무한 지속';
      expect(_labelOf(text, 'max_target_extra'), '주변의 적 ▢명에게');
      expect(_labelOf(text, 'atk_scale_extra'), '치유량의 ▢에');
      expect(_labelOf(text, 'atk'), '2회차부터 공격력 +▢');
    });

    test('takes a third word when the two before are short', () {
      expect(_label('저지 가능 수 +{block_cnt}'), '저지 가능 수 +▢');
    });

    test('drops a one-letter connective in front', () {
      expect(_label('배치 후 공격력 및 방어력 +{def:0%}'), '공격력 및 방어력 +▢');
    });

    test('a clause starting with the value takes the words after it', () {
      expect(_label('{prob:0%} 확률로 목표를 기절'), '▢ 확률로 목표를');
    });

    test('English skips filler words and takes the unit after a space', () {
      expect(
        _label('Deals damage and stuns them for {stun} seconds'),
        'damage and stuns them for ▢ seconds',
      );
      expect(_label('ATK +{atk:0%} and DEF +10%'), 'ATK +▢');
    });

    test('unspaced text keeps eight characters and a one-letter unit', () {
      expect(_label('使范围内的地面敌人浮空{duration}秒内无法行动'), '内的地面敌人浮空▢秒');
    });

    test('stops at the literal \\n of CN texts', () {
      expect(_label(r'攻击力+{atk:0%}\n持续时间无限'), '攻击力+▢');
    });
  });

  group('buildSkillComparisonRows', () {
    final skill = OperatorSkill(
      id: 'skchr_test_2',
      name: 'Test',
      recoveryType: 'auto',
      activationType: 'manual',
      description: '',
      levels: [
        for (var level = 1; level <= 3; level++)
          _level(
            level,
            '이동 속도 {-move_speed:0%} 감소, 공격력 +{atk:0%}, {duration}초 지속',
            {
              'atk': 0.1 * level,
              'move_speed': -0.3,
              'haruka_s_2[first].atk': 0,
              'ability_range_radius': 1.7,
            },
            duration: level == 1 ? 0 : 20 + level,
          ),
      ],
    );
    final rows = buildSkillComparisonRows(skill, _i18n);

    test('base rows are localized; durations get seconds or a dash', () {
      expect(rows.take(3).map((row) => row.label), ['필요 SP', '초기 SP', '지속 시간']);
      expect(rows[2].values, ['–', '22초', '23초']);
    });

    test('described values follow the description, formatted as shown', () {
      final described =
          rows.where((row) => row.kind == SkillRowKind.described).toList();
      expect(described.map((row) => row.label), ['이동 속도 ▢ 감소', '공격력 +▢']);
      expect(described[0].values, ['30%', '30%', '30%']);
      expect(described[1].values, ['10%', '20%', '30%']);
    });

    test('values the description does not use stay, under their raw keys', () {
      final internal =
          rows.where((row) => row.kind == SkillRowKind.internal).toList();
      expect(
        internal.map((row) => row.label),
        ['haruka_s_2[first].atk', 'ability_range_radius'],
      );
      expect(internal[1].values, ['1.7', '1.7', '1.7']);
    });
  });
}
