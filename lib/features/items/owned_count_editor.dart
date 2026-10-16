import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/item.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/nexus_ui.dart' show ItemIcon;
import '../../ui/redesign/rd_widgets.dart';
import 'item_format.dart';

/// Body of the owned-count dialog (`items.vue`): icon + name header,
/// hold-to-repeat -/+ buttons around a numeric input, a formatted preview, and
/// the hold/input hints of the redesign canvas.
///
/// The draft is committed (saved through [onCommit]) on button release,
/// pointer leave while holding, input blur/enter, keyboard activation of a
/// step button, and when the dialog closes.
class OwnedCountEditor extends ConsumerStatefulWidget {
  const OwnedCountEditor({
    required this.item,
    required this.savingItemIds,
    required this.onCommit,
    required this.currentCountLabel,
    this.showItemHeader = true,
    super.key,
  });

  /// `itemsPage.editor.currentCount`.
  final String currentCountLabel;
  final ItemEntry item;
  final ValueListenable<Set<String>> savingItemIds;
  final Future<void> Function(int value) onCommit;

  /// Draw the centered icon/name/label block. Phones put that block in the
  /// bottom-sheet header instead (see [OwnedCountEditorHeader]).
  final bool showItemHeader;

  @override
  ConsumerState<OwnedCountEditor> createState() => OwnedCountEditorState();
}

class OwnedCountEditorState extends ConsumerState<OwnedCountEditor> {
  late final TextEditingController _draft =
      TextEditingController(text: '${widget.item.ownedCount}');
  final _focusNode = FocusNode();
  Timer? _holdTimeout;
  Timer? _holdInterval;
  DateTime _holdStartedAt = DateTime.now();
  bool _holding = false;

  bool get _saving => widget.savingItemIds.value.contains(widget.item.itemId);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        unawaited(commit());
      }
    });
  }

  @override
  void dispose() {
    _stopAdjusting();
    _draft.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setDraftValue(num value) {
    final text = '${clampOwnedCount(value)}';
    _draft.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _adjust(int direction, int step) {
    final current = int.tryParse(_draft.text.isEmpty ? '0' : _draft.text) ?? 0;
    _setDraftValue(current + direction * step);
  }

  void _stopAdjusting() {
    _holdTimeout?.cancel();
    _holdTimeout = null;
    _holdInterval?.cancel();
    _holdInterval = null;
  }

  /// `beginAdjustingCount`: one step at once, then every 100ms after 450ms
  /// with the accelerating [ownedCountHoldStep].
  void _beginAdjusting(int direction) {
    if (_saving) {
      return;
    }
    _stopAdjusting();
    _holding = true;
    _holdStartedAt = DateTime.now();
    _adjust(direction, 1);
    _holdTimeout = Timer(const Duration(milliseconds: 450), () {
      _holdInterval = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _adjust(
          direction,
          ownedCountHoldStep(DateTime.now().difference(_holdStartedAt)),
        );
      });
    });
  }

  /// Pointer up / cancel / leave: stop repeating and save what was reached.
  void _endAdjusting() {
    _stopAdjusting();
    if (!_holding) {
      return;
    }
    _holding = false;
    unawaited(commit());
  }

  /// Keyboard / assistive activation of a step button: one step, then save.
  void _stepOnce(int direction) {
    if (_saving) {
      return;
    }
    _adjust(direction, 1);
    unawaited(commit());
  }

  /// `commitOwnedCountDraft`.
  Future<void> commit() async {
    _stopAdjusting();
    _holding = false;
    if (!mounted) {
      return;
    }
    final normalized = normalizeOwnedCountInput(_draft.text);
    if (normalized != _draft.text) {
      _setDraftValue(int.parse(normalized));
    }
    await widget.onCommit(int.parse(normalized));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final compact = context.rdLayout == RdLayout.compact;
    final item = widget.item;
    final stepSize = compact ? 56.0 : 52.0;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: widget.savingItemIds,
      builder: (context, saving, _) {
        final disabled = saving.contains(item.itemId);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showItemHeader) ...[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ItemIcon(
                    itemId: item.itemId,
                    iconId: item.iconId,
                    name: item.name,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.32,
                      color: RdColors.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.currentCountLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: RdColors.secondary2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                RdStepButton(
                  increase: false,
                  tooltip: i18n.t('rd.items.decrease'),
                  width: stepSize,
                  height: stepSize,
                  tonal: true,
                  onPressed: disabled ? null : () => _stepOnce(-1),
                  onHoldStart: () => _beginAdjusting(-1),
                  onHoldEnd: _endAdjusting,
                ),
                SizedBox(width: compact ? 10 : 12),
                Expanded(
                  child: RdNumberField(
                    controller: _draft,
                    focusNode: _focusNode,
                    enabled: !disabled,
                    height: stepSize,
                    fontSize: 20,
                    radius: RdRadii.inner,
                    color: compact ? RdColors.sheetOption : RdColors.surface3,
                    borderColor: RdColors.tonalBorder,
                    semanticLabel: i18n.t('rd.items.countInput'),
                    inputFormatters: const [_OwnedCountFormatter()],
                    onSubmitted: (_) => unawaited(commit()),
                  ),
                ),
                SizedBox(width: compact ? 10 : 12),
                RdStepButton(
                  increase: true,
                  tooltip: i18n.t('rd.items.increase'),
                  width: stepSize,
                  height: stepSize,
                  tonal: true,
                  onPressed: disabled ? null : () => _stepOnce(1),
                  onHoldStart: () => _beginAdjusting(1),
                  onHoldEnd: _endAdjusting,
                ),
              ],
            ),
            SizedBox(height: compact ? 14 : 16),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _draft,
              builder: (context, value, _) => Semantics(
                liveRegion: true,
                child: Text(
                  'x ${formatOwnedCount(int.tryParse(value.text) ?? 0, item.itemId)}',
                  textAlign: TextAlign.center,
                  style: RdText.mono(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SizedBox(height: compact ? 14 : 16),
            _HoldHints(
              background: compact ? RdColors.sheetOption : RdColors.inner,
              holdHint: i18n.t('rd.items.holdHint'),
              steps: [
                i18n.t('rd.items.holdStep1'),
                i18n.t('rd.items.holdStep5'),
                i18n.t('rd.items.holdStep10'),
              ],
              inputHint: i18n.t('rd.items.inputHint'),
            ),
            if (disabled) ...[
              SizedBox(height: compact ? 14 : 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  i18n.t('rd.items.saving'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: RdColors.link,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Bottom-sheet header of the owned-count editor on phones: 56px icon, name
/// and the "current count" label next to the close button.
class OwnedCountEditorHeader extends StatelessWidget {
  const OwnedCountEditorHeader({
    required this.item,
    required this.currentCountLabel,
    super.key,
  });

  final ItemEntry item;
  final String currentCountLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ItemIcon(
          itemId: item.itemId,
          iconId: item.iconId,
          name: item.name,
          size: 56,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: RdColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                currentCountLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: RdColors.secondary2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hint box: hold timing, the three acceleration stages, input rules.
class _HoldHints extends StatelessWidget {
  const _HoldHints({
    required this.background,
    required this.holdHint,
    required this.steps,
    required this.inputHint,
  });

  final Color background;
  final String holdHint;
  final List<String> steps;
  final String inputHint;

  /// Accent at 14 / 24 / 34%: the larger the step, the stronger the tint.
  static const _stepFills = [
    RdColors.accentSoft,
    Color(0x3D7C8CFF),
    Color(0x577C8CFF),
  ];
  static const _stepText = [
    RdColors.accentText,
    RdColors.text,
    RdColors.text,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(RdRadii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            holdHint,
            style: const TextStyle(fontSize: 12, color: RdColors.secondary2),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _stepFills[i],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        steps[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: _stepText[i]),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            inputHint,
            style: const TextStyle(fontSize: 12, color: RdColors.muted),
          ),
        ],
      ),
    );
  }
}

class _OwnedCountFormatter extends TextInputFormatter {
  const _OwnedCountFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = normalizeOwnedCountInput(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
