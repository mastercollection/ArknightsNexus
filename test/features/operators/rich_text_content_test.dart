import 'package:arknight_nexus/domain/rich_text_segment.dart';
import 'package:arknight_nexus/features/operators/operator_detail_widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a term link still opens after the mouse hovers it',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichTextContent(
            segments: const [
              RichTextRun('스킬이 '),
              RichTermRun(key: 'ba.magicpoint', text: '마력'),
              RichTextRun('을 소모'),
            ],
            onTermTap: (key, label) => taps.add('$key:$label'),
          ),
        ),
      ),
    );

    final match = find.textRange.ofSubstring('마력').evaluate().single;
    final boxes = match.renderObject.getBoxesForSelection(
      TextSelection(
        baseOffset: match.textRange.start,
        extentOffset: match.textRange.end,
      ),
    );
    final target =
        match.renderObject.localToGlobal(boxes.first.toRect().center);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(target);
    await tester.pump();
    await mouse.down(target);
    await tester.pump();
    await mouse.up();
    await tester.pump();

    expect(taps, ['ba.magicpoint:마력']);
  });
}
