import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/user_data.dart';
import 'package:arknight_nexus/features/plan/operator_plan_screen.dart';
import 'package:arknight_nexus/features/plan/plan_materials_grid.dart';
import 'package:arknight_nexus/features/plan/plan_screen.dart';
import 'package:arknight_nexus/i18n/nexus_i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plan_test_support.dart';

const _phone = Size(390, 844);
const _tablet = Size(800, 1000);
const _pc = Size(1440, 900);

void main() {
  group('plan screen', () {
    late PlanFakeOperatorService operatorService;
    late PlanFakeItemService itemService;
    late PlanMemoryUserDataRepository userDataRepository;

    setUp(() {
      operatorService = PlanFakeOperatorService([
        planOperatorDetail('char_002_amiya', 'Amiya', 'Caster'),
        planOperatorDetail('char_003_kalts', 'Kaltsit', 'Medic'),
      ]);
      itemService = PlanFakeItemService(formulas: planSkillBookFormulas);
      userDataRepository = PlanMemoryUserDataRepository(
        const UserData(
          favorites: ['char_003_kalts'],
          selectedOperatorIds: ['char_002_amiya'],
          operatorPlans: [
            UserPlanOperator(
              operatorId: 'char_002_amiya',
              current: UserPlanOperatorState(elite: 0, level: 1),
              target: UserPlanOperatorState(
                elite: 0,
                level: 3,
                skillLevels: [2],
              ),
            ),
          ],
        ),
      );
    });

    Future<void> pump(
      WidgetTester tester, {
      Size size = const Size(1000, 2400),
      bool inShell = false,
    }) =>
        pumpPlanPage(
          tester,
          operatorService: operatorService,
          itemService: itemService,
          userDataRepository: userDataRepository,
          size: size,
          inShell: inShell,
        );

    testWidgets('shows the selected plan operators grid', (tester) async {
      await pump(tester);

      expect(find.text('오퍼레이터'), findsOneWidget);
      expect(find.text('종합 결과'), findsOneWidget);
      expect(find.text('선택한 오퍼레이터'), findsOneWidget);
      expect(find.text('현재 플랜에 포함된 오퍼레이터입니다.'), findsOneWidget);
      expect(find.text('Amiya'), findsOneWidget);
      // Favorites are only listed while nothing is selected.
      expect(find.text('Kaltsit'), findsNothing);
      expect(find.text('★★★★★★'), findsOneWidget);
    });

    testWidgets('opens the operator plan from a selected tile', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Amiya'));
      await tester.pumpAndSettle();

      expect(find.byType(OperatorPlanScreen), findsOneWidget);
      expect(find.text('상태 비교'), findsOneWidget);
    });

    testWidgets('adds operators through the picker dialog', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const Key('plan-picker-open')));
      await tester.pumpAndSettle();

      expect(find.text('오퍼레이터 선택'), findsOneWidget);
      expect(find.text('메딕'), findsOneWidget);
      expect(find.text('Kaltsit'), findsOneWidget);
      expect(find.text('추가'), findsOneWidget);
      // PC/tablet: a centred dialog, not a bottom sheet.
      expect(find.byType(BottomSheet), findsNothing);

      await tester.tap(find.text('Kaltsit'));
      await tester.pumpAndSettle();

      expect(
        (await userDataRepository.read()).selectedOperatorIds,
        ['char_002_amiya', 'char_003_kalts'],
      );
      // The picker stays open and the added operator leaves the list.
      expect(find.text('추가할 수 있는 오퍼레이터가 없습니다.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('plan-picker-close')));
      await tester.pumpAndSettle();
      expect(find.text('오퍼레이터 선택'), findsNothing);
      expect(find.text('Kaltsit'), findsOneWidget);
    });

    testWidgets('filters the picker by search text', (tester) async {
      userDataRepository.data = const UserData();
      await pump(tester);

      await tester.tap(find.byKey(const Key('plan-picker-open')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'kal');
      await tester.pumpAndSettle();

      expect(find.text('Kaltsit'), findsOneWidget);
      expect(find.text('Amiya'), findsNothing);
    });

    testWidgets('picker search matches the translated profession', (
      tester,
    ) async {
      userDataRepository.data = const UserData();
      await pump(tester);

      await tester.tap(find.byKey(const Key('plan-picker-open')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, '캐스터');
      await tester.pumpAndSettle();

      expect(find.text('Amiya'), findsOneWidget);
      expect(find.text('Kaltsit'), findsNothing);
    });

    testWidgets(
        'removes operators in selection mode and falls back to '
        'favorites', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const Key('plan-selection-action')));
      await tester.pumpAndSettle();
      expect(
        find.text('제거할 오퍼레이터를 고른 뒤 상단 체크 버튼을 누르세요.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('plan-picker-open')), findsNothing);
      expect(find.byKey(const Key('plan-selection-cancel')), findsOneWidget);
      // Nothing marked yet: confirming is a no-op.
      expect(find.text('제거'), findsOneWidget);
      await tester.tap(find.byKey(const Key('plan-selection-action')));
      await tester.pumpAndSettle();
      expect(
        (await userDataRepository.read()).selectedOperatorIds,
        ['char_002_amiya'],
      );

      await tester.tap(find.text('Amiya'));
      await tester.pumpAndSettle();
      expect(find.text('1명 제거'), findsOneWidget);
      await tester.tap(find.byKey(const Key('plan-selection-action')));
      await tester.pumpAndSettle();

      final data = await userDataRepository.read();
      expect(data.selectedOperatorIds, isEmpty);
      expect(data.operatorPlans, isEmpty);
      expect(find.text('즐겨찾기 오퍼레이터'), findsOneWidget);
      expect(find.text('Kaltsit'), findsOneWidget);
      expect(find.text('+ 플랜에 추가'), findsOneWidget);

      // Tapping a favorite adds it to the plan.
      await tester.tap(find.text('Kaltsit'));
      await tester.pumpAndSettle();
      expect(
        (await userDataRepository.read()).selectedOperatorIds,
        ['char_003_kalts'],
      );
      expect(find.text('선택한 오퍼레이터'), findsOneWidget);
    });

    testWidgets('cancelling selection mode keeps the plan', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const Key('plan-selection-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amiya'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plan-selection-cancel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('plan-picker-open')), findsOneWidget);
      expect(find.text('현재 플랜에 포함된 오퍼레이터입니다.'), findsOneWidget);
      expect(
        (await userDataRepository.read()).selectedOperatorIds,
        ['char_002_amiya'],
      );
    });

    testWidgets('shows the empty state without plan or favorites', (
      tester,
    ) async {
      userDataRepository.data = const UserData();
      await pump(tester);

      expect(find.text('아직 선택한 오퍼레이터가 없습니다.'), findsOneWidget);
      expect(find.byKey(const Key('plan-selection-action')), findsNothing);
    });

    testWidgets('summarizes planned costs, farming and materials', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('종합 결과'));
      await tester.pumpAndSettle();

      // Selection (trash) is only offered on the operators tab.
      expect(find.byKey(const Key('plan-selection-action')), findsNothing);
      expect(find.text('집계 오퍼레이터'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('plan-summary-count'))).data,
        '1',
      );
      expect(find.text('300'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('부족 30'), findsOneWidget);
      expect(find.text('파밍 환산'), findsOneWidget);
      expect(find.text('경험치 LS-6'), findsOneWidget);
      expect(find.text('용문폐 CE-6'), findsOneWidget);
      expect(find.text('1회 클리어'), findsNWidgets(2));
      expect(find.text('72 이성 소모'), findsOneWidget);
      expect(find.text('필요 재료'), findsOneWidget);
      expect(find.text('T3'), findsOneWidget);
      expect(find.text('Skill Book'), findsOneWidget);
      expect(findPlanText('필요 3 / 부족 2'), findsOneWidget);
      expect(find.text('E0 Lv.1 → E0 Lv.3'), findsOneWidget);
      expect(find.text('상세 열기'), findsOneWidget);

      await tester.tap(find.text('상세 열기'));
      await tester.pumpAndSettle();
      expect(find.byType(OperatorPlanScreen), findsOneWidget);
    });

    testWidgets('summary item icons open the item page', (tester) async {
      await pump(tester);

      await tester.tap(find.text('종합 결과'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Skill Book 아이템 상세'));
      await tester.pumpAndSettle();

      expect(find.text('item:skill_book'), findsOneWidget);
    });

    testWidgets('shows validation errors in the summary', (tester) async {
      userDataRepository.data = const UserData(
        selectedOperatorIds: ['char_002_amiya'],
        operatorPlans: [
          UserPlanOperator(
            operatorId: 'char_002_amiya',
            current: UserPlanOperatorState(elite: 0, level: 10),
            target: UserPlanOperatorState(elite: 0, level: 3),
          ),
        ],
      );
      await pump(tester);

      await tester.tap(find.text('종합 결과'));
      await tester.pumpAndSettle();

      expect(find.text('입력 확인 필요'), findsOneWidget);
      expect(find.text('Amiya: 초기 육성 단계가 목표보다 높습니다.'), findsOneWidget);
    });

    testWidgets('expands workshop recipes in the summary', (tester) async {
      await pump(tester);

      await tester.tap(find.text('종합 결과'));
      await tester.pumpAndSettle();
      expect(find.text('조합식 펼쳐보기'), findsOneWidget);

      await tester.tap(find.byType(PlanRecipeSwitch));
      await tester.pumpAndSettle();

      expect(find.text('원본 재료 보기'), findsOneWidget);
      expect(find.text('Skill Book'), findsNothing);
      expect(find.text('Skill Page'), findsOneWidget);
      expect(find.text('T2'), findsOneWidget);
      expect(findPlanText('필요 6 / 부족 6'), findsOneWidget);
    });

    testWidgets('a region switch reloads and turns the recipe expansion off', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('종합 결과'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PlanRecipeSwitch));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PlanRecipeSwitch>(find.byType(PlanRecipeSwitch)).value,
        isTrue,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanScreen)),
      );
      container.read(regionProvider.notifier).state = RegionCode.en;
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Expand Recipes'), findsOneWidget);
      expect(
        tester.widget<PlanRecipeSwitch>(find.byType(PlanRecipeSwitch)).value,
        isFalse,
      );
      expect(find.text('Skill Book'), findsOneWidget);
    });

    testWidgets('shows the empty summary state', (tester) async {
      userDataRepository.data = const UserData();
      await pump(tester);

      await tester.tap(find.text('종합 결과'));
      await tester.pumpAndSettle();

      expect(find.text('종합할 오퍼레이터가 없습니다.'), findsOneWidget);
    });

    testWidgets('shows the load error with a retry', (tester) async {
      operatorService.failList = true;
      await pump(tester);

      expect(find.text('플랜 화면을 불러오지 못했습니다.'), findsOneWidget);
      expect(find.textContaining('list failed'), findsOneWidget);

      operatorService.failList = false;
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('Amiya'), findsOneWidget);
    });

    for (final (label, size) in [
      ('phone', _phone),
      ('tablet', _tablet),
      ('PC', _pc),
    ]) {
      testWidgets('lays out on $label inside the shell', (tester) async {
        await pump(tester, size: size, inShell: true);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('plan-picker-open')), findsOneWidget);
        expect(find.byKey(const Key('plan-selection-action')), findsOneWidget);
        expect(find.text('Amiya'), findsOneWidget);

        // Selection mode header (confirm + cancel) fits as well.
        await tester.tap(find.byKey(const Key('plan-selection-action')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Amiya'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('1명 제거'), findsOneWidget);
        await tester.tap(find.byKey(const Key('plan-selection-cancel')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('plan-picker-open')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('오퍼레이터 선택'), findsOneWidget);
        // Phones get a bottom sheet, PC a centred dialog.
        expect(
          find.byType(BottomSheet),
          size == _phone ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.byKey(const Key('plan-picker-close')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('종합 결과'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('필요 재료'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('상세 열기'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('상세 열기'), findsOneWidget);
      });
    }

    testWidgets('phone layout shows favorites with the short add hint', (
      tester,
    ) async {
      userDataRepository.data = const UserData(favorites: ['char_003_kalts']);
      await pump(tester, size: _phone, inShell: true);

      expect(tester.takeException(), isNull);
      expect(find.text('+ 추가'), findsOneWidget);
      await tester.tap(find.text('Kaltsit'));
      await tester.pumpAndSettle();
      expect(
        (await userDataRepository.read()).selectedOperatorIds,
        ['char_003_kalts'],
      );
    });
  });
}
