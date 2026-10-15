import 'package:arknight_nexus/domain/user_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const state = UserPlanOperatorState(
    elite: 1,
    level: 40,
    skillLevels: [4],
    modules: [
      UserPlanModule(moduleId: 'uniequip_a', currentStage: 0, targetStage: 1),
      UserPlanModule(moduleId: 'uniequip_b', currentStage: 1, targetStage: 2),
    ],
  );

  group('user plan edits', () {
    test('copyWith replaces only the given fields', () {
      const plan = UserPlanOperator(
        operatorId: 'char_002_amiya',
        current: state,
        target: state,
      );
      final next = plan.copyWith(target: state.copyWith(level: 50));

      expect(next.operatorId, 'char_002_amiya');
      expect(next.current, same(state));
      expect(next.target.level, 50);
      expect(next.target.elite, 1);
      expect(next.target.skillLevels, [4]);
      expect(next.target.modules, same(state.modules));
    });

    test('withSkillLevel pads missing skills with level 1', () {
      expect(state.withSkillLevel(2, 7).skillLevels, [4, 1, 7]);
      expect(state.withSkillLevel(0, 2).skillLevels, [2]);
      expect(state.skillLevels, [4]);
    });

    test('module lookup and stage replacement', () {
      expect(state.module('uniequip_b')?.targetStage, 2);
      expect(state.module('missing'), isNull);

      final next = state.withModuleStage('uniequip_a', targetStage: 3);
      expect(next.module('uniequip_a')?.currentStage, 0);
      expect(next.module('uniequip_a')?.targetStage, 3);
      expect(next.module('uniequip_b')?.targetStage, 2);
      expect(
        state.withModuleStage('missing', currentStage: 1).modules.length,
        2,
      );
    });
  });
}
