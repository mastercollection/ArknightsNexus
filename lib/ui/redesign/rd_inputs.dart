import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'rd_tokens.dart';

/// Option of an [RdSelect].
class RdSelectOption<T> {
  const RdSelectOption(this.value, this.label, {this.shortLabel});

  final T value;

  /// Label in the menu (and in the closed field unless [shortLabel] is set).
  final String label;

  /// Label of the closed field ("KR" for "KR · 한국어").
  final String? shortLabel;
}

/// Dropdown of the canvas (`#121a2c`, 1px line, radius 10/12).
///
/// [label] names the control for screen readers and as its tooltip. Without
/// [width] the field fills its parent, or wraps its label when [shrinkWrap]
/// is set.
class RdSelect<T> extends StatelessWidget {
  const RdSelect({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.width,
    this.height = 36,
    this.fontSize = 13,
    this.shrinkWrap = false,
    super.key,
  });

  final String label;
  final T value;
  final List<RdSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final double? width;
  final double height;
  final double fontSize;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == value).firstOrNull;
    final radius = height >= 44 ? RdRadii.control : RdRadii.small;
    final shown = Text(
      selected?.shortLabel ?? selected?.label ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: fontSize, color: RdColors.text),
    );
    return Semantics(
      label: label,
      value: selected?.label,
      button: true,
      child: PopupMenuButton<T>(
        tooltip: label,
        initialValue: value,
        onSelected: (next) {
          if (next != value) {
            onChanged(next);
          }
        },
        color: RdColors.inner,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RdRadii.small),
          side: const BorderSide(color: RdColors.line3),
        ),
        constraints: BoxConstraints(minWidth: width ?? 0),
        itemBuilder: (context) => [
          for (final option in options)
            PopupMenuItem<T>(
              value: option.value,
              height: 44,
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      option.value == value ? FontWeight.w700 : FontWeight.w400,
                  color: option.value == value
                      ? RdColors.accent
                      : RdColors.secondary,
                ),
              ),
            ),
        ],
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.only(left: 10, right: 6),
          decoration: BoxDecoration(
            color: RdColors.field,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: RdColors.line3),
          ),
          child: Row(
            mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (shrinkWrap) shown else Expanded(child: shown),
              const SizedBox(width: 4),
              Icon(
                Icons.expand_more,
                size: height >= 40 ? 18 : 16,
                color: RdColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `−` / `+` stepper button.
///
/// The default look is the outlined 40px square of the detail and plan
/// steppers. [tonal] is the large accent-tinted button of the owned-count
/// editor. With [onHoldStart] / [onHoldEnd] the button repeats while held
/// (the caller runs the timer); a tap from the keyboard or assistive
/// technology calls [onPressed] once.
class RdStepButton extends StatefulWidget {
  const RdStepButton({
    required this.increase,
    required this.tooltip,
    required this.onPressed,
    this.width = 40,
    this.height = 40,
    this.tonal = false,
    this.onHoldStart,
    this.onHoldEnd,
    super.key,
  });

  /// `+` when true, `−` otherwise.
  final bool increase;

  /// Tooltip and semantics label.
  final String tooltip;

  /// Disabled while null.
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final bool tonal;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;

  @override
  State<RdStepButton> createState() => _RdStepButtonState();
}

class _RdStepButtonState extends State<RdStepButton> {
  bool _hovered = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  Widget _glyph() {
    final symbol = widget.increase ? '+' : '−';
    if (widget.tonal) {
      return Text(
        symbol,
        style: const TextStyle(
          fontSize: 22,
          height: 1,
          fontWeight: FontWeight.w700,
          color: RdColors.text,
        ),
      );
    }
    return Text(
      symbol,
      style: TextStyle(
        fontSize: 18,
        color: _enabled ? RdColors.secondary : RdColors.placeholder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onHoldStart == null) {
      return Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: Semantics(
          button: true,
          enabled: _enabled,
          label: widget.tooltip,
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RdRadii.small),
              side: const BorderSide(color: RdColors.white14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(RdRadii.small),
              onTap: widget.onPressed,
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: Center(child: _glyph()),
              ),
            ),
          ),
        ),
      );
    }
    final enabled = _enabled;
    final highlighted = (_hovered || _focused) && enabled;
    final holdEnd = widget.onHoldEnd ?? () {};
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.tooltip,
        onTap: widget.onPressed,
        excludeSemantics: true,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor:
              enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          onShowHoverHighlight: (value) {
            setState(() => _hovered = value);
            if (!value) {
              // Leaving the button while holding ends the hold.
              holdEnd();
            }
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed?.call();
                return null;
              },
            ),
          },
          child: Listener(
            onPointerDown: enabled ? (_) => widget.onHoldStart!() : null,
            onPointerUp: (_) => holdEnd(),
            onPointerCancel: (_) => holdEnd(),
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: widget.width,
                height: widget.height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: highlighted
                      ? const Color(0x3D4D75BC)
                      : const Color(0x294D75BC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: highlighted
                        ? const Color(0x7A85B6FF)
                        : RdColors.searchBorder,
                  ),
                ),
                child: _glyph(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered monospace number field: the box (focus border, a dimming veil
/// while disabled) around a [TextField] the caller controls.
class RdNumberField extends StatelessWidget {
  const RdNumberField({
    required this.controller,
    required this.focusNode,
    this.enabled = true,
    this.height = 44,
    this.fontSize = 15,
    this.radius = RdRadii.small,
    this.color = RdColors.segmentTrack,
    this.borderColor = RdColors.white14,
    this.semanticLabel,
    this.inputFormatters = const [],
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final double height;
  final double fontSize;
  final double radius;
  final Color color;

  /// Border while unfocused; focus turns it accent.
  final Color borderColor;
  final String? semanticLabel;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) => Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: borderRadius,
              border: Border.all(
                color: focusNode.hasFocus ? RdColors.accent : borderColor,
              ),
            ),
            child: Semantics(
              label: semanticLabel,
              textField: true,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                inputFormatters: inputFormatters,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                cursorColor: RdColors.accent,
                style: RdText.mono(fontSize: fontSize),
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
                    borderRadius: borderRadius,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Integer input that clamps to [min]..[max] while typing and restores the
/// display value on blur (`el-input-number :controls=false`).
class RdNumberInput extends StatefulWidget {
  const RdNumberInput({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String? semanticLabel;

  @override
  State<RdNumberInput> createState() => _RdNumberInputState();
}

class _RdNumberInputState extends State<RdNumberInput> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.value}');
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(RdNumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = '${widget.value}';
    if (_controller.text == text) {
      return;
    }
    // Stepper taps change the value while the field may still hold focus;
    // a field being edited (empty, or over the cap) is left alone.
    final parsed = int.tryParse(_controller.text.trim());
    if (!_focusNode.hasFocus ||
        (parsed != null && _clamp(parsed) != widget.value)) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (!_focusNode.hasFocus) {
      _restoreDisplay();
    }
  }

  void _restoreDisplay() {
    final text = '${_clamp(widget.value)}';
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  int _clamp(int value) {
    final upper = widget.max < widget.min ? widget.min : widget.max;
    return value.clamp(widget.min, upper);
  }

  void _handleChanged(String text) {
    final parsed = int.tryParse(text.trim());
    if (parsed == null) {
      return;
    }
    final next = _clamp(parsed);
    if (next != widget.value) {
      widget.onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RdNumberField(
      controller: _controller,
      focusNode: _focusNode,
      semanticLabel: widget.semanticLabel,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: _handleChanged,
      onSubmitted: (_) => _restoreDisplay(),
    );
  }
}
