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

class OwnedCountEditorState extends ConsumerState<OwnedCountEditor>
    with OwnedCountDraft<OwnedCountEditor> {
  @override
  ItemEntry get draftItem => widget.item;

  @override
  ValueListenable<Set<String>> get draftSavingItemIds => widget.savingItemIds;

  @override
  Future<void> Function(int value) get draftOnCommit => widget.onCommit;

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
                  onPressed: disabled ? null : () => stepOnce(-1),
                  onHoldStart: () => beginAdjusting(-1),
                  onHoldEnd: endAdjusting,
                ),
                SizedBox(width: compact ? 10 : 12),
                Expanded(
                  child: RdNumberField(
                    controller: draft,
                    focusNode: draftFocusNode,
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
                  onPressed: disabled ? null : () => stepOnce(1),
                  onHoldStart: () => beginAdjusting(1),
                  onHoldEnd: endAdjusting,
                ),
              ],
            ),
            SizedBox(height: compact ? 14 : 16),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: draft,
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

/// Draft state of an owned-count editor (`items.vue`): the text field
/// value, hold-to-repeat stepping and the commit rules shared by the
/// count dialog and the inline stepper of the detail page.
///
/// The draft is committed (saved through [draftOnCommit]) on button
/// release, pointer leave while holding, input blur/enter, and keyboard
/// activation of a step button.
mixin OwnedCountDraft<T extends StatefulWidget> on State<T> {
  ItemEntry get draftItem;
  ValueListenable<Set<String>> get draftSavingItemIds;
  Future<void> Function(int value) get draftOnCommit;

  late final TextEditingController draft =
      TextEditingController(text: '${draftItem.ownedCount}');
  final draftFocusNode = FocusNode();
  Timer? _holdTimeout;
  Timer? _holdInterval;
  DateTime _holdStartedAt = DateTime.now();
  bool _holding = false;

  bool get draftSaving => draftSavingItemIds.value.contains(draftItem.itemId);

  /// Whether the user is changing the draft (typing or holding a button);
  /// outside updates of the count must not overwrite it then.
  bool get draftBusy => _holding || draftFocusNode.hasFocus;

  @override
  void initState() {
    super.initState();
    draftFocusNode.addListener(() {
      if (!draftFocusNode.hasFocus) {
        unawaited(commit());
      }
    });
  }

  @override
  void dispose() {
    _stopAdjusting();
    draft.dispose();
    draftFocusNode.dispose();
    super.dispose();
  }

  void setDraftValue(num value) {
    final text = '${clampOwnedCount(value)}';
    draft.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _adjust(int direction, int step) {
    final current = int.tryParse(draft.text.isEmpty ? '0' : draft.text) ?? 0;
    setDraftValue(current + direction * step);
  }

  void _stopAdjusting() {
    _holdTimeout?.cancel();
    _holdTimeout = null;
    _holdInterval?.cancel();
    _holdInterval = null;
  }

  /// `beginAdjustingCount`: one step at once, then every 100ms after 450ms
  /// with the accelerating [ownedCountHoldStep].
  void beginAdjusting(int direction) {
    if (draftSaving) {
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
  void endAdjusting() {
    _stopAdjusting();
    if (!_holding) {
      return;
    }
    _holding = false;
    unawaited(commit());
  }

  /// Keyboard / assistive activation of a step button: one step, then save.
  void stepOnce(int direction) {
    if (draftSaving) {
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
    final normalized = normalizeOwnedCountInput(draft.text);
    if (normalized != draft.text) {
      setDraftValue(int.parse(normalized));
    }
    await draftOnCommit(int.parse(normalized));
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

/// Inline owned-count control of the item detail header: `−`, the count
/// field and `+`, with the hold-to-repeat and commit rules of
/// [OwnedCountEditor]. A count of 0 is drawn muted.
class OwnedCountStepper extends ConsumerStatefulWidget {
  const OwnedCountStepper({
    required this.item,
    required this.savingItemIds,
    required this.onCommit,
    this.height = 40,
    this.fieldWidth = 72,
    super.key,
  });

  final ItemEntry item;
  final ValueListenable<Set<String>> savingItemIds;
  final Future<void> Function(int value) onCommit;
  final double height;
  final double fieldWidth;

  @override
  ConsumerState<OwnedCountStepper> createState() => _OwnedCountStepperState();
}

class _OwnedCountStepperState extends ConsumerState<OwnedCountStepper>
    with OwnedCountDraft<OwnedCountStepper> {
  @override
  ItemEntry get draftItem => widget.item;

  @override
  ValueListenable<Set<String>> get draftSavingItemIds => widget.savingItemIds;

  @override
  Future<void> Function(int value) get draftOnCommit => widget.onCommit;

  @override
  void didUpdateWidget(OwnedCountStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Saved, rolled back or another item: show the stored count unless the
    // user is still editing.
    final count = widget.item.ownedCount;
    if (!draftBusy && draft.text != '$count') {
      setDraftValue(count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final height = widget.height;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: widget.savingItemIds,
      builder: (context, saving, _) {
        final disabled = saving.contains(widget.item.itemId);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RdStepButton(
              increase: false,
              tooltip: i18n.t('rd.items.decrease'),
              width: height,
              height: height,
              onPressed: disabled ? null : () => stepOnce(-1),
              onHoldStart: () => beginAdjusting(-1),
              onHoldEnd: endAdjusting,
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: widget.fieldWidth,
              child: ListenableBuilder(
                listenable: Listenable.merge([draft, draftFocusNode]),
                builder: (context, _) => Container(
                  height: height,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: RdColors.surface3,
                    borderRadius: BorderRadius.circular(RdRadii.control),
                    border: Border.all(
                      color: draftFocusNode.hasFocus
                          ? RdColors.accentLine
                          : RdColors.border,
                    ),
                  ),
                  child: Semantics(
                    label: i18n.t('rd.items.countInput'),
                    textField: true,
                    child: TextField(
                      controller: draft,
                      focusNode: draftFocusNode,
                      enabled: !disabled,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      textAlign: TextAlign.center,
                      inputFormatters: const [_OwnedCountFormatter()],
                      onSubmitted: (_) => unawaited(commit()),
                      cursorColor: RdColors.accent,
                      style: RdText.mono(
                        fontSize: 15,
                        color: (int.tryParse(draft.text) ?? 0) > 0
                            ? RdColors.text
                            : RdColors.text3,
                      ),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            RdStepButton(
              increase: true,
              tooltip: i18n.t('rd.items.increase'),
              width: height,
              height: height,
              onPressed: disabled ? null : () => stepOnce(1),
              onHoldStart: () => beginAdjusting(1),
              onHoldEnd: endAdjusting,
            ),
          ],
        );
      },
    );
  }
}
