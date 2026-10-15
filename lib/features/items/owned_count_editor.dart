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
                _StepButton(
                  label: '−',
                  semanticsLabel: i18n.t('rd.items.decrease'),
                  size: stepSize,
                  disabled: disabled,
                  onPressStart: () => _beginAdjusting(-1),
                  onPressEnd: _endAdjusting,
                  onActivate: () => _stepOnce(-1),
                ),
                SizedBox(width: compact ? 10 : 12),
                Expanded(
                  child: _OwnedCountInput(
                    controller: _draft,
                    focusNode: _focusNode,
                    enabled: !disabled,
                    height: stepSize,
                    label: i18n.t('rd.items.countInput'),
                    background: compact
                        ? RdColors.sheetOption
                        : const Color(0xFF0B1222),
                    onSubmitted: () => unawaited(commit()),
                  ),
                ),
                SizedBox(width: compact ? 10 : 12),
                _StepButton(
                  label: '+',
                  semanticsLabel: i18n.t('rd.items.increase'),
                  size: stepSize,
                  disabled: disabled,
                  onPressStart: () => _beginAdjusting(1),
                  onPressEnd: _endAdjusting,
                  onActivate: () => _stepOnce(1),
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
                    color: Color(0xFFA9C8FF),
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

  static const _stepFills = [
    Color(0x2985B6FF), // rgba(133,182,255,0.16)
    Color(0x3D85B6FF), // 0.24
    Color(0x5785B6FF), // 0.34
  ];
  static const _stepText = [
    Color(0xFFDCE9FF),
    Color(0xFFE7EFFF),
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

/// -/+ button with press-and-hold repeat; Enter/Space (and the semantics tap
/// action) steps once and saves.
class _StepButton extends StatefulWidget {
  const _StepButton({
    required this.label,
    required this.semanticsLabel,
    required this.size,
    required this.disabled,
    required this.onPressStart,
    required this.onPressEnd,
    required this.onActivate,
  });

  final String label;
  final String semanticsLabel;
  final double size;
  final bool disabled;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final VoidCallback onActivate;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.disabled;
    final highlighted = (_hovered || _focused) && !disabled;
    return Tooltip(
      message: widget.semanticsLabel,
      waitDuration: const Duration(milliseconds: 600),
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: !disabled,
        label: widget.semanticsLabel,
        onTap: disabled ? null : widget.onActivate,
        excludeSemantics: true,
        child: FocusableActionDetector(
          enabled: !disabled,
          mouseCursor: disabled
              ? SystemMouseCursors.forbidden
              : SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          onShowHoverHighlight: (value) {
            setState(() => _hovered = value);
            if (!value) {
              // `@mouseleave="commitOwnedCountDraft"` while holding.
              widget.onPressEnd();
            }
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onActivate();
                return null;
              },
            ),
          },
          child: Listener(
            onPointerDown: disabled ? null : (_) => widget.onPressStart(),
            onPointerUp: (_) => widget.onPressEnd(),
            onPointerCancel: (_) => widget.onPressEnd(),
            child: Opacity(
              opacity: disabled ? 0.45 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: highlighted
                      ? const Color(0x3D4D75BC)
                      : const Color(0x294D75BC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: highlighted
                        ? const Color(0x7A85B6FF)
                        : const Color(0x4785B6FF),
                  ),
                ),
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: RdColors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
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

/// Numeric input (mono 20px, centered) with a dimming veil while saving.
class _OwnedCountInput extends StatelessWidget {
  const _OwnedCountInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.height,
    required this.label,
    required this.background,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final double height;
  final String label;
  final Color background;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(RdRadii.inner);
    return Stack(
      children: [
        Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            border: Border.all(color: const Color(0x6685B6FF)),
          ),
          child: Semantics(
            label: label,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
              inputFormatters: const [_OwnedCountFormatter()],
              onSubmitted: (_) => onSubmitted(),
              cursorColor: RdColors.accent,
              style: RdText.mono(fontSize: 20),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        if (!enabled)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x8C050914),
                  borderRadius: radius,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
