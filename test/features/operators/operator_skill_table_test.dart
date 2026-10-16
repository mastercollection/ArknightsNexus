import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/features/operators/operator_detail_view_model.dart';
import 'package:arknight_nexus/features/operators/operator_skill_table.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _longLabel = 'Attack@max Target Shield Absorb Rate';

final _skill = OperatorSkill(
  id: 'skchr_test_2',
  name: 'Test',
  recoveryType: 'auto',
  activationType: 'manual',
  description: '',
  levels: [
    for (var level = 1; level <= 10; level++)
      OperatorSkillLevel(
        level: level,
        spCost: 40 - level,
        initialSp: 10,
        duration: 20,
        description: '',
      ),
  ],
);

final _rows = [
  SkillComparisonRow(
    key: 'sp',
    label: 'SP Cost',
    values: [for (var level = 1; level <= 10; level++) '${40 - level}'],
  ),
  SkillComparisonRow(
    key: 'long',
    label: _longLabel,
    values: [for (var level = 1; level <= 10; level++) '${level * 10}%'],
  ),
  SkillComparisonRow(
    key: 'radius',
    label: 'ability_range_radius',
    values: [for (var level = 1; level <= 10; level++) '1.7'],
    kind: SkillRowKind.internal,
  ),
];

Future<void> _pump(WidgetTester tester, double width) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: OperatorSkillTable(
              skill: _skill,
              rows: _rows,
              selectedLevel: 1,
              itemLabel: '항목',
              internalLabel: '내부 수치',
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('long item labels are not cut off', (tester) async {
    await _pump(tester, 640);
    await tester.pumpAndSettle();

    final paragraph = tester.renderObject<RenderParagraph>(
      find.text(_longLabel).first,
    );
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  testWidgets('a mouse drags the overflowing table sideways', (tester) async {
    await _pump(tester, 400);
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(OperatorSkillTable),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, 0);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(find.byType(Scrollbar), findsOneWidget);

    await tester.drag(
      find.text('SP Cost').first,
      const Offset(-150, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(100));
  });

  testWidgets('the internal values heading hides the row scrolled under it',
      (tester) async {
    await _pump(tester, 400);
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(OperatorSkillTable),
        matching: find.byType(Scrollable),
      ),
    );
    scrollable.position.jumpTo(40);
    await tester.pumpAndSettle();

    // The scrolled row and its pinned copy.
    final headings = find.byKey(const ValueKey('skill-table-internal'));
    expect(headings, findsNWidgets(2));
    for (final heading in tester.widgetList<Container>(headings)) {
      final fill = (heading.decoration! as BoxDecoration).color;
      expect(fill?.a, 1.0);
    }
  });
}
