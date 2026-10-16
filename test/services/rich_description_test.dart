import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/rich_text_segment.dart';
import 'package:arknight_nexus/services/rich_description.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseRichDescription', () {
    test('plain text becomes a single text run', () {
      final segments = parseRichDescription('단일 적에게 피해를 준다.');
      expect(segments, hasLength(1));
      expect(segments.single, isA<RichTextRun>());
      expect((segments.single as RichTextRun).text, '단일 적에게 피해를 준다.');
    });

    test('interpolates {key} placeholders from the blackboard', () {
      final segments = parseRichDescription(
        '공격력 +{atk}',
        const [OperatorBlackboardEntry(key: 'atk', value: 120)],
      );
      expect(segments, hasLength(2));
      expect((segments[0] as RichTextRun).text, '공격력 +');
      expect(segments[1], isA<RichValueRun>());
      expect((segments[1] as RichValueRun).text, '120');
    });

    test('formats {key:0%} placeholders as a percentage', () {
      final segments = parseRichDescription(
        '{atk_scale:0%} 증가',
        const [OperatorBlackboardEntry(key: 'atk_scale', value: 0.5)],
      );
      expect((segments[0] as RichValueRun).text, '50%');
    });

    test('keeps the literal token when no blackboard value exists', () {
      final segments = parseRichDescription('값 {missing}');
      expect((segments[1] as RichValueRun).text, '{missing}');
    });

    test('parses <@ba.*> as a nested highlight run', () {
      final segments = parseRichDescription(
        '<@ba.vup>공격력 {atk}</> 상승',
        const [OperatorBlackboardEntry(key: 'atk', value: 80)],
      );
      expect(segments[0], isA<RichHighlightRun>());
      final highlight = segments[0] as RichHighlightRun;
      expect((highlight.children[0] as RichTextRun).text, '공격력 ');
      expect((highlight.children[1] as RichValueRun).text, '80');
      expect((segments[1] as RichTextRun).text, ' 상승');
    });

    test('parses <\$...> as a term run carrying its key', () {
      final segments = parseRichDescription(r'<$ba.stun>기절</> 부여');
      expect(segments[0], isA<RichTermRun>());
      final term = segments[0] as RichTermRun;
      expect(term.key, 'ba.stun');
      expect(term.text, '기절');
    });

    test('prefers valueStr over the numeric value', () {
      final segments = parseRichDescription(
        '{duration}',
        const [
          OperatorBlackboardEntry(key: 'duration', value: 3, valueStr: '영구'),
        ],
      );
      expect((segments[0] as RichValueRun).text, '영구');
    });

    test('trims trailing zeros from fractional values', () {
      final segments = parseRichDescription(
        '{rate}',
        const [OperatorBlackboardEntry(key: 'rate', value: 1.5)],
      );
      expect((segments[0] as RichValueRun).text, '1.5');
    });

    test('closes nested tags at their own </>', () {
      // A KR talent (하루카) with a value tag inside a remark tag.
      final segments = parseRichDescription(
        '<@ba.rem>2회차부터 공격력 <@ba.vup>+{atk:0%}</>, 무한 지속</>',
        const [OperatorBlackboardEntry(key: 'atk', value: 0.1)],
      );
      expect(segments, hasLength(1));
      final outer = segments.single as RichHighlightRun;
      expect((outer.children[0] as RichTextRun).text, '2회차부터 공격력 ');
      final inner = outer.children[1] as RichHighlightRun;
      expect((inner.children[0] as RichTextRun).text, '+');
      expect((inner.children[1] as RichValueRun).text, '10%');
      expect((outer.children[2] as RichTextRun).text, ', 무한 지속');
    });

    test('a term wrapping a styled tag keeps its text only', () {
      final segments = parseRichDescription(
        '<\$ba.root><@ba.vup>속박</></> 효과',
      );
      final term = segments[0] as RichTermRun;
      expect(term.key, 'ba.root');
      expect(term.text, '속박');
      expect((segments[1] as RichTextRun).text, ' 효과');
    });

    test('a tag the data never closes runs to the end', () {
      final segments = parseRichDescription('+23%<@ba.talpu>(+3%)');
      expect((segments[0] as RichTextRun).text, '+23%');
      final tail = segments[1] as RichHighlightRun;
      expect((tail.children.single as RichTextRun).text, '(+3%)');
    });
  });
}
