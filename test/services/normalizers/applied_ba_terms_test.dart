import 'package:arknight_nexus/services/normalizers/operator_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appliedBaTermIds', () {
    test('counts a term the blackboard applies', () {
      expect(
        appliedBaTermIds([
          ('목표를 1초간 <\$ba.stun>기절</>', ['prob', 'stun']),
          ('공격 시 <\$ba.cold>냉기</> 부여', ['attack@cold']),
          ('적을 <\$ba.levitate>공중 부양</>', ['levitate_duration']),
          ('빙결된 적의 취약 2배 <\$ba.frozen>빙결</>', ['damage_scale_cold']),
        ]),
        ['ba.stun', 'ba.cold', 'ba.levitate', 'ba.frozen'],
      );
    });

    test('counts a term the text applies without a blackboard key', () {
      expect(
        appliedBaTermIds([
          ('공격 범위 내 모든 적을 <\$ba.stun>기절</>시키고', ['atk_scale']),
          ('주변의 지상 적에게 <\$ba.sleep>수면</> 효과 부여', ['duration']),
          ('Stuns all enemies: <\$ba.stun>Stun</> for 3 seconds', []),
        ]),
        ['ba.stun', 'ba.sleep'],
      );
    });

    test('skips a term the text only reacts to', () {
      expect(
        appliedBaTermIds([
          ('<\$ba.sleep>수면</> 상태의 적 공격 가능', ['def_penetrate']),
          ('공격 범위 내 <\$ba.palsy>마비</> 상태인 적에게 대미지', ['atk_scale']),
          ('<\$ba.levitate>공중 부양 상태</>의 적은 대미지를 받음', ['interval']),
          (
            '<@ba.kw>통합 전략</>에서 모든 강제 이동 상태, '
                '<\$ba.levitate>공중 부양</> 상태의 적은 대미지를 받음',
            ['interval', 'atk_scale', 'duration'],
          ),
          ('攻击处于<\$ba.stun>晕眩</>状态的敌人', ['atk_scale']),
          ('Deals more damage to <\$ba.stun>Stunned</> enemies', []),
        ]),
        isEmpty,
      );
    });

    test('skips a term the text protects from', () {
      expect(
        appliedBaTermIds([
          ('[쉐라그] 오퍼레이터가 <\$ba.frozen>빙결</> 상태 면역', ['def']),
          (
            '다음에 받는 <\$ba.stun>기절</>/<\$ba.frozen>빙결</> 효과를 상쇄하고, '
                '공격한 대상을 3초간 <\$ba.stun>기절</>시킴',
            ['extra_cost', 'stun'],
          ),
        ]),
        // The stun key makes the second text apply Stun; Freeze stays out.
        ['ba.stun'],
      );
    });
  });
}
