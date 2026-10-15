import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/features/plan/plan_materials_grid.dart';
import 'package:arknight_nexus/features/plan/plan_screen.dart';
import 'package:arknight_nexus/features/plan/plan_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'plan_test_support.dart';

const _phone = Size(390, 844);
const _tablet = Size(800, 1000);
const _pc = Size(1440, 900);

void main() {
  group('operator plan screen', () {
    late PlanFakeOperatorService operatorService;
    late PlanFakeItemService itemService;
    late PlanMemoryUserDataRepository userDataRepository;

    setUp(() {
      operatorService = PlanFakeOperatorService([
        planOperatorDetail(
          'char_002_amiya',
          'Amiya',
          'Caster',
          modules: const [planTestModule],
        ),
      ]);
      itemService = PlanFakeItemService();
      userDataRepository = PlanMemoryUserDataRepository(
        const UserData(
          selectedOperatorIds: ['char_002_amiya'],
          operatorPlans: [
            UserPlanOperator(
              operatorId: 'char_002_amiya',
              current: UserPlanOperatorState(
                elite: 0,
                level: 1,
                skillLevels: [1],
                modules: [
                  UserPlanModule(
                    moduleId: 'uniequip_002_amiya',
                    currentStage: 0,
                    targetStage: 0,
                  ),
                ],
              ),
              target: UserPlanOperatorState(
                elite: 0,
                level: 3,
                skillLevels: [2],
                modules: [
                  UserPlanModule(
                    moduleId: 'uniequip_002_amiya',
                    currentStage: 0,
                    targetStage: 0,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });

    Future<void> openDetail(
      WidgetTester tester, {
      Size size = const Size(1000, 2400),
      bool inShell = false,
    }) async {
      await pumpPlanPage(
        tester,
        operatorService: operatorService,
        itemService: itemService,
        userDataRepository: userDataRepository,
        size: size,
        inShell: inShell,
      );
      await tester.tap(find.text('Amiya'));
      await tester.pumpAndSettle();
    }

    Future<void> waitForAutosave(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
    }

    String saveStatusText(WidgetTester tester) => tester
        .widget<PlanSaveStatusPill>(find.byType(PlanSaveStatusPill))
        .label;

    Future<void> tapSegment(WidgetTester tester, String key) async {
      final finder = find.byKey(Key(key));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
    }

    testWidgets('loads the operator plan with the cost summary', (
      tester,
    ) async {
      await openDetail(tester);

      expect(find.text('Amiya'), findsWidgets);
      // The header shows the translated profession.
      expect(find.text('캐스터 / Core'), findsOneWidget);
      expect(find.text('상태 비교'), findsOneWidget);
      expect(find.text('초기 상태'), findsOneWidget);
      expect(find.text('목표 상태'), findsOneWidget);
      expect(find.text('스킬 설정'), findsOneWidget);
      expect(find.text('Skill 1'), findsOneWidget);
      expect(find.text('모듈 설정'), findsOneWidget);
      expect(find.text('Amiya Module'), findsOneWidget);
      expect(find.text('미해금'), findsNWidgets(2));
      expect(find.text('계산 결과'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('72 이성 소모'), findsOneWidget);
      expect(find.text('Skill Book'), findsOneWidget);
      expect(findPlanText('필요 3 / 부족 2'), findsOneWidget);
      // Level caps and the idle autosave pill.
      expect(find.text('/ 50'), findsNWidgets(2));
      expect(saveStatusText(tester), '자동 저장');
      // Mastery chips use the M1-M3 images.
      expect(
        find.descendant(
          of: find.byKey(const Key('plan-target-skill-0-8')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
    });

    testWidgets('autosaves level, skill and module edits after a debounce', (
      tester,
    ) async {
      await openDetail(tester);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('plan-target-level')),
          matching: find.byType(EditableText),
        ),
        '4',
      );
      await tester.pump(const Duration(milliseconds: 100));
      // Still inside the 400ms debounce window.
      expect(
        (await userDataRepository.read()).operatorPlans.single.target.level,
        3,
      );
      expect(saveStatusText(tester), '저장 중');
      await waitForAutosave(tester);
      expect(
        (await userDataRepository.read()).operatorPlans.single.target.level,
        4,
      );
      expect(saveStatusText(tester), '플랜을 저장했습니다.');
      // 100 + 200 + 300 EXP for Lv.1 -> Lv.4.
      expect(find.text('600'), findsOneWidget);

      await tapSegment(tester, 'plan-target-skill-0-3');
      await waitForAutosave(tester);

      await tapSegment(tester, 'plan-target-module-uniequip_002_amiya-2');
      await waitForAutosave(tester);

      final plan = (await userDataRepository.read()).operatorPlans.single;
      expect(plan.operatorId, 'char_002_amiya');
      expect(plan.target.level, 4);
      expect(plan.target.skillLevels.first, 3);
      expect(
        plan.target.modules
            .singleWhere((module) => module.moduleId == 'uniequip_002_amiya')
            .targetStage,
        2,
      );
      expect(findPlanText('필요 7 / 부족 6'), findsOneWidget);
      // The skill route shows the new target.
      expect(find.text('Lv.3'), findsOneWidget);
    });

    testWidgets('saves mastery levels picked from the M1-M3 chips', (
      tester,
    ) async {
      await openDetail(tester);

      await tapSegment(tester, 'plan-target-skill-0-10');
      await waitForAutosave(tester);

      expect(
        (await userDataRepository.read())
            .operatorPlans
            .single
            .target
            .skillLevels
            .first,
        10,
      );
      expect(find.bySemanticsLabel('특화 3'), findsWidgets);
    });

    testWidgets('level steppers respect the elite level cap', (tester) async {
      await openDetail(tester);

      final increase = find.bySemanticsLabel('목표 상태 레벨 올리기');
      await tester.ensureVisible(increase);
      await tester.tap(increase);
      await waitForAutosave(tester);
      expect(
        (await userDataRepository.read()).operatorPlans.single.target.level,
        4,
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('plan-target-level')),
          matching: find.byType(EditableText),
        ),
        '99',
      );
      await waitForAutosave(tester);
      // E0 caps at 50.
      expect(
        (await userDataRepository.read()).operatorPlans.single.target.level,
        50,
      );
    });

    testWidgets('clamps the level when the elite phase lowers the cap', (
      tester,
    ) async {
      userDataRepository.data = const UserData(
        selectedOperatorIds: ['char_002_amiya'],
        operatorPlans: [
          UserPlanOperator(
            operatorId: 'char_002_amiya',
            current: UserPlanOperatorState(elite: 0, level: 1),
            target: UserPlanOperatorState(elite: 2, level: 90),
          ),
        ],
      );
      await openDetail(tester);

      await tapSegment(tester, 'plan-target-elite-0');
      await waitForAutosave(tester);

      final plan = (await userDataRepository.read()).operatorPlans.single;
      expect(plan.target.elite, 0);
      expect(plan.target.level, 50);
    });

    testWidgets('shows validation errors when current exceeds target', (
      tester,
    ) async {
      await openDetail(tester);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('plan-current-level')),
          matching: find.byType(EditableText),
        ),
        '10',
      );
      await waitForAutosave(tester);

      expect(find.text('Amiya: 초기 육성 단계가 목표보다 높습니다.'), findsOneWidget);
      expect(find.text('추가 재료가 없습니다.'), findsOneWidget);
    });

    testWidgets('a failed autosave shows the pill state and the error', (
      tester,
    ) async {
      await openDetail(tester);
      userDataRepository.failWrites = true;

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('plan-target-level')),
          matching: find.byType(EditableText),
        ),
        '5',
      );
      await waitForAutosave(tester);

      expect(saveStatusText(tester), '저장 실패');
      expect(find.byKey(const Key('plan-save-error-toast')), findsOneWidget);
      expect(find.textContaining('disk full'), findsOneWidget);

      await tester.tap(find.byTooltip('알림 닫기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-save-error-toast')), findsNothing);

      // The next edit retries and recovers.
      userDataRepository.failWrites = false;
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('plan-target-level')),
          matching: find.byType(EditableText),
        ),
        '6',
      );
      await waitForAutosave(tester);
      expect(saveStatusText(tester), '플랜을 저장했습니다.');
      expect(
        (await userDataRepository.read()).operatorPlans.single.target.level,
        6,
      );
    });

    testWidgets('the error toast hides itself after a few seconds', (
      tester,
    ) async {
      await openDetail(tester);
      userDataRepository.failWrites = true;

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('plan-target-level')),
          matching: find.byType(EditableText),
        ),
        '5',
      );
      await waitForAutosave(tester);
      expect(find.byKey(const Key('plan-save-error-toast')), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-save-error-toast')), findsNothing);
      expect(saveStatusText(tester), '저장 실패');
    });

    testWidgets('expands recipes and opens item pages from materials', (
      tester,
    ) async {
      itemService = PlanFakeItemService(formulas: planSkillBookFormulas);
      await openDetail(tester);

      await tester.ensureVisible(find.byType(PlanRecipeSwitch));
      await tester.tap(find.byType(PlanRecipeSwitch));
      await tester.pumpAndSettle();
      expect(find.text('원본 재료 보기'), findsOneWidget);
      expect(find.text('Skill Page'), findsOneWidget);

      final link = find.bySemanticsLabel('Skill Page 아이템 상세');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.text('item:skill_page'), findsOneWidget);
    });

    testWidgets('shows the not-found state for an unknown operator', (
      tester,
    ) async {
      await pumpPlanPage(
        tester,
        operatorService: operatorService,
        itemService: itemService,
        userDataRepository: userDataRepository,
      );
      GoRouter.of(tester.element(find.byType(PlanScreen)))
          .push('/plan/char_unknown');
      await tester.pumpAndSettle();

      expect(find.text('육성 상세를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.text('대상 오퍼레이터 정보를 찾을 수 없습니다.'), findsOneWidget);
      expect(find.text('다시 불러오기'), findsOneWidget);
      expect(find.byType(PlanSaveStatusPill), findsNothing);
    });

    for (final (label, size) in [
      ('phone', _phone),
      ('tablet', _tablet),
      ('PC', _pc),
    ]) {
      testWidgets('lays out on $label inside the shell', (tester) async {
        await openDetail(tester, size: size, inShell: true);

        expect(tester.takeException(), isNull);
        expect(find.byType(PlanSaveStatusPill), findsOneWidget);
        expect(find.byKey(const Key('plan-current-elite')), findsOneWidget);
        expect(find.byKey(const Key('plan-target-level')), findsOneWidget);
        expect(find.byKey(const Key('plan-target-skill-0')), findsOneWidget);
        expect(
          find.byKey(const Key('plan-target-module-uniequip_002_amiya')),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('필요 재료'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);

        // Back returns to the plan list (the PC header scrolls with the page).
        await tester.ensureVisible(find.byTooltip('육성 계획으로 돌아가기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('육성 계획으로 돌아가기'));
        await tester.pumpAndSettle();
        expect(find.text('선택한 오퍼레이터'), findsOneWidget);
      });
    }
  });
}
