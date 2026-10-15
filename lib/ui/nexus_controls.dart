import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'nexus_icons.dart';
import 'nexus_scrollbar.dart';
import 'nexus_surfaces.dart';
import 'nexus_tokens.dart';

/// Element Plus dark-theme palette, used where the Tauri app keeps stock
/// Element Plus controls (inputs, selects, sliders, drawers).
class ElementDark {
  const ElementDark._();

  static const primary = Color(0xFF409EFF);
  static const border = Color(0xFF4C4D4F);
  static const borderHover = Color(0xFF6C6E72);
  static const borderLight = Color(0xFF414243);
  static const textRegular = Color(0xFFCFD3DC);
  static const textPrimary = Color(0xFFE5EAF3);
  static const placeholder = Color(0xFF8D9095);
  static const bg = Color(0xFF141414);
  static const overlay = Color(0xFF1D1E1F);
  static const fillLight = Color(0xFF262727);
}

/// `el-input` with optional prefix icon and clear button.
class NexusInput extends StatefulWidget {
  const NexusInput({
    this.controller,
    this.placeholder,
    this.prefixIcon,
    this.clearable = true,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.autofocus = false,
    this.height = 32,
    super.key,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final IconData? prefixIcon;
  final bool clearable;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final bool autofocus;
  final double height;

  @override
  State<NexusInput> createState() => _NexusInputState();
}

class _NexusInputState extends State<NexusInput> {
  TextEditingController? _ownController;
  final _focusNode = FocusNode();
  bool _hovered = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_refresh);
    _controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(NexusInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_refresh);
      _controller.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _focusNode.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    final borderColor = focused
        ? ElementDark.primary
        : (_hovered ? ElementDark.borderHover : ElementDark.border);
    final showClear = widget.clearable &&
        _controller.text.isNotEmpty &&
        (_hovered || focused);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          // `--el-input-bg-color` (`--el-fill-color-blank`, dark).
          color: ElementDark.bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            if (widget.prefixIcon != null) ...[
              NexusIcon(
                widget.prefixIcon!,
                size: 14,
                color: ElementDark.placeholder,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                keyboardType: widget.keyboardType,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                cursorColor: ElementDark.textRegular,
                cursorWidth: 1,
                // `.el-input__inner`: line-height = inner height.
                style: TextStyle(
                  color: ElementDark.textRegular,
                  fontSize: 14,
                  height: (widget.height - 2) / 14,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: widget.placeholder,
                  hintStyle: TextStyle(
                    color: ElementDark.placeholder,
                    fontSize: 14,
                    height: (widget.height - 2) / 14,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
              ),
            ),
            if (showClear)
              GestureDetector(
                onTap: () {
                  _controller.clear();
                  widget.onChanged?.call('');
                },
                child: const MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: NexusIcon(
                    Icons.cancel_outlined,
                    size: 14,
                    color: ElementDark.placeholder,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NexusOption<T> {
  const NexusOption(this.value, this.label, {this.leading});

  final T value;
  final String label;

  /// Optional widget shown before [label] in the dropdown list only (custom
  /// `el-option` slot content such as an icon).
  final Widget? leading;
}

/// `el-select` (single). Opens an anchored dropdown; [filterable] adds a
/// search box like Element Plus' filterable mode.
class NexusSelect<T> extends StatelessWidget {
  const NexusSelect({
    required this.options,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.clearable = false,
    this.filterable = false,
    this.width,
    this.small = false,
    super.key,
  });

  final List<NexusOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? placeholder;
  final bool clearable;
  final bool filterable;
  final double? width;

  /// `size="small"`: 24px tall, 12px text.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == value).firstOrNull;
    return _SelectField(
      width: width,
      small: small,
      label: selected?.label,
      placeholder: placeholder,
      onClear: clearable && selected != null ? () => onChanged(null) : null,
      onOpen: (anchor) async {
        final result = await Navigator.of(context).push(
          _SelectPopupRoute<T>(
            anchor: anchor,
            options: options,
            selected: {if (value != null) value as T},
            filterable: filterable,
            multiple: false,
          ),
        );
        if (result != null && result.isNotEmpty) {
          onChanged(result.first);
        }
      },
    );
  }
}

/// `el-select multiple collapse-tags`.
class NexusMultiSelect<T> extends StatelessWidget {
  const NexusMultiSelect({
    required this.options,
    required this.values,
    required this.onChanged,
    this.placeholder,
    this.filterable = false,
    super.key,
  });

  final List<NexusOption<T>> options;
  final List<T> values;
  final ValueChanged<List<T>> onChanged;
  final String? placeholder;
  final bool filterable;

  @override
  Widget build(BuildContext context) {
    final labels = [
      for (final value in values)
        options.where((o) => o.value == value).firstOrNull?.label ?? '$value',
    ];
    return _SelectField(
      label: null,
      tags: labels,
      placeholder: placeholder,
      onClear: values.isEmpty ? null : () => onChanged(const []),
      onOpen: (anchor) async {
        final result = await Navigator.of(context).push(
          _SelectPopupRoute<T>(
            anchor: anchor,
            options: options,
            selected: values.toSet(),
            filterable: filterable,
            multiple: true,
          ),
        );
        if (result != null) {
          onChanged([
            for (final option in options)
              if (result.contains(option.value)) option.value,
          ]);
        }
      },
    );
  }
}

class _SelectField extends StatefulWidget {
  const _SelectField({
    required this.label,
    required this.onOpen,
    this.placeholder,
    this.onClear,
    this.tags,
    this.width,
    this.small = false,
  });

  final bool small;
  final String? label;
  final List<String>? tags;
  final String? placeholder;
  final VoidCallback? onClear;
  final Future<void> Function(Rect anchor) onOpen;
  final double? width;

  @override
  State<_SelectField> createState() => _SelectFieldState();
}

class _SelectFieldState extends State<_SelectField> {
  bool _hovered = false;
  bool _open = false;

  Future<void> _open_() async {
    final box = context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    setState(() => _open = true);
    await widget.onOpen(origin & box.size);
    if (mounted) {
      setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.tags;
    final hasValue = widget.label != null || (tags?.isNotEmpty ?? false);
    final showClear = widget.onClear != null && _hovered;

    Widget content;
    if (tags != null && tags.isNotEmpty) {
      content = Row(
        children: [
          Flexible(child: _Tag(tags.first)),
          if (tags.length > 1) ...[
            const SizedBox(width: 6),
            _Tag('+ ${tags.length - 1}'),
          ],
        ],
      );
    } else {
      content = Text(
        widget.label ?? widget.placeholder ?? '',
        overflow: TextOverflow.ellipsis,
        // `.el-select__wrapper`: line-height 24px (20px when small).
        style: TextStyle(
          fontSize: widget.small ? 12 : 14,
          height: widget.small ? 20 / 12 : 24 / 14,
          leadingDistribution: TextLeadingDistribution.even,
          color: hasValue ? ElementDark.textRegular : ElementDark.placeholder,
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _open_,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: widget.small ? 24 : 32,
          padding: widget.small
              ? const EdgeInsets.symmetric(horizontal: 8)
              : const EdgeInsets.only(left: 12, right: 8),
          decoration: BoxDecoration(
            color: ElementDark.bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _open
                  ? ElementDark.primary
                  : (_hovered ? ElementDark.borderHover : ElementDark.border),
            ),
          ),
          child: Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 4),
              if (showClear)
                GestureDetector(
                  onTap: widget.onClear,
                  child: const NexusIcon(
                    Icons.cancel_outlined,
                    size: 14,
                    color: ElementDark.placeholder,
                  ),
                )
              else
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const NexusIcon(
                    Icons.keyboard_arrow_down,
                    size: 14,
                    color: ElementDark.placeholder,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ElementDark.fillLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: ElementDark.textRegular),
      ),
    );
  }
}

class _SelectPopupRoute<T> extends PopupRoute<Set<T>> {
  _SelectPopupRoute({
    required this.anchor,
    required this.options,
    required this.selected,
    required this.filterable,
    required this.multiple,
  });

  final Rect anchor;
  final List<NexusOption<T>> options;
  final Set<T> selected;
  final bool filterable;
  final bool multiple;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'select';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return FadeTransition(
      opacity: animation,
      child: _SelectPopup<T>(route: this),
    );
  }
}

class _SelectPopup<T> extends StatefulWidget {
  const _SelectPopup({required this.route});

  final _SelectPopupRoute<T> route;

  @override
  State<_SelectPopup<T>> createState() => _SelectPopupState<T>();
}

class _SelectPopupState<T> extends State<_SelectPopup<T>> {
  late final Set<T> _selected = {...widget.route.selected};
  String _filter = '';

  void _close() {
    Navigator.of(context).pop(widget.route.multiple ? _selected : null);
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final screen = MediaQuery.sizeOf(context);
    final query = _filter.trim().toLowerCase();
    final visible = query.isEmpty
        ? route.options
        : route.options
            .where((o) => o.label.toLowerCase().contains(query))
            .toList();

    const maxListHeight = 274.0;
    final popupWidth = math.max(route.anchor.width, 120.0);
    final spaceBelow = screen.height - route.anchor.bottom - 12;
    final placeAbove = spaceBelow < 180 && route.anchor.top > spaceBelow;
    final left = math.min(route.anchor.left, screen.width - popupWidth - 8);

    final popup = Material(
      color: ElementDark.overlay,
      borderRadius: BorderRadius.circular(4),
      elevation: 8,
      shadowColor: Colors.black,
      child: Container(
        width: popupWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: ElementDark.borderLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (route.filterable)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: NexusInput(
                  autofocus: true,
                  prefixIcon: Icons.search,
                  onChanged: (value) => setState(() => _filter = value),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.min(
                  maxListHeight,
                  math.max(
                    120,
                    placeAbove ? route.anchor.top - 60 : spaceBelow - 60,
                  ),
                ),
              ),
              child: visible.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No data',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ElementDark.placeholder,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final option = visible[index];
                        final isSelected = _selected.contains(option.value);
                        return _OptionTile(
                          label: option.label,
                          leading: option.leading,
                          selected: isSelected,
                          showCheck: route.multiple,
                          onTap: () {
                            if (route.multiple) {
                              setState(() {
                                if (!_selected.remove(option.value)) {
                                  _selected.add(option.value);
                                }
                              });
                            } else {
                              Navigator.of(context).pop({option.value});
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
        Positioned(
          left: left,
          top: placeAbove ? null : route.anchor.bottom + 6,
          bottom: placeAbove ? screen.height - route.anchor.top + 6 : null,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                _close();
              }
            },
            child: popup,
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatefulWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.showCheck,
    required this.onTap,
    this.leading,
  });

  final String label;
  final Widget? leading;
  final bool selected;
  final bool showCheck;
  final VoidCallback onTap;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 34,
          color: _hovered ? ElementDark.fillLight : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        widget.selected ? FontWeight.w700 : FontWeight.w400,
                    color: widget.selected
                        ? ElementDark.primary
                        : ElementDark.textRegular,
                  ),
                ),
              ),
              if (widget.showCheck && widget.selected)
                const NexusIcon(
                  Icons.check,
                  size: 14,
                  color: ElementDark.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `el-drawer direction="btt" :with-header="false"`.
Future<T?> showNexusBottomDrawer<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxHeight = 416,
  double heightFactor = 0.6,
}) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  return NexusScrollLock.guard(
    () => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ElementDark.bg,
      barrierColor: const Color(0x80000000),
      shape: const RoundedRectangleBorder(),
      constraints: BoxConstraints(
        maxHeight: math.min(maxHeight, screenHeight * heightFactor),
        minHeight: math.min(maxHeight, screenHeight * heightFactor),
        maxWidth: double.infinity,
      ),
      builder: (context) => SafeArea(
        top: false,
        child: NexusDrawerBody(child: builder(context)),
      ),
    ),
  );
}

/// `.el-drawer__body`: 20px padding (`--el-drawer-padding-primary`) and
/// its own scroll box, which gets Chromium's classic scrollbar on overflow.
class NexusDrawerBody extends StatefulWidget {
  const NexusDrawerBody({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  State<NexusDrawerBody> createState() => _NexusDrawerBodyState();
}

class _NexusDrawerBodyState extends State<NexusDrawerBody> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NexusClassicScrollbar(
      controller: _controller,
      child: SingleChildScrollView(
        controller: _controller,
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}

/// Styled `el-segmented` (see `styles/element/index.scss`).
class NexusSegmented<T> extends StatelessWidget {
  const NexusSegmented({
    required this.options,
    required this.value,
    required this.onChanged,
    this.expand = true,
    this.itemBuilder,
    super.key,
  });

  final List<NexusOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expand;

  /// Custom segment content (e.g. an icon instead of [NexusOption.label]),
  /// like the `el-segmented` default slot.
  final Widget Function(NexusOption<T> option, bool selected)? itemBuilder;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < options.length; i++) {
      if (i > 0) {
        items.add(const SizedBox(width: 4));
      }
      final option = options[i];
      final selected = option.value == value;
      final tile = NexusHoverable(
        onTap: () => onChanged(option.value),
        builder: (context, hovered) => CustomPaint(
          // `.el-segmented__item-selected`: inset 0 1px 0 rgba(255,255,255,.16).
          foregroundPainter: selected
              ? const InsetTopHighlightPainter(
                  radius: 14,
                  color: Color(0x29FFFFFF),
                )
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected
                  ? const Color(0xE65C94DC)
                  : (hovered ? const Color(0x0FFFFFFF) : Colors.transparent),
            ),
            child: itemBuilder?.call(option, selected) ??
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: selected
                        ? const Color(0xFFF3F8FF)
                        : (hovered
                            ? const Color(0xE6F4F8FF)
                            : const Color(0xB8E2E9F7)),
                  ),
                ),
          ),
        ),
      );
      items.add(expand ? Expanded(child: tile) : tile);
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF512182A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x337A90B8)),
      ),
      // `box-shadow: inset 0 1px 0 rgba(255,255,255,0.03)`.
      child: CustomPaint(
        painter: const InsetTopHighlightPainter(radius: 18, inset: 1),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: NexusNormalLineHeight(
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: items,
            ),
          ),
        ),
      ),
    );
  }
}

/// `SliderLikeControl.vue`: slider + right-aligned bold value.
class NexusSlider extends StatelessWidget {
  const NexusSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.showValue = true,
    this.valuePrefix = '',
    this.valueSuffix = '',
    this.disabled = false,
    super.key,
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final bool showValue;
  final String valuePrefix;
  final String valueSuffix;
  final bool disabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // `grid grid-cols-[minmax(0,1fr)_auto] items-center gap-4`.
    return Row(
      children: [
        Expanded(
          child: _ElSlider(
            value: value,
            min: min,
            max: max,
            step: step,
            disabled: disabled || max <= min,
            onChanged: onChanged,
          ),
        ),
        if (showValue) ...[
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 32),
            child: Text(
              '$valuePrefix$value$valueSuffix',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: NexusColors.text,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Element Plus `el-slider`: 32px tall, 6px runway, 20px ring button centred
/// on the value (it overhangs the runway ends like the web control).
class _ElSlider extends StatefulWidget {
  const _ElSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.disabled,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final bool disabled;
  final ValueChanged<int> onChanged;

  @override
  State<_ElSlider> createState() => _ElSliderState();
}

class _ElSliderState extends State<_ElSlider> {
  bool _hovered = false;
  bool _dragging = false;

  void _update(double dx, double width) {
    if (widget.disabled || width <= 0) {
      return;
    }
    final span = widget.max - widget.min;
    final raw = (dx / width).clamp(0.0, 1.0) * span;
    final step = math.max(1, widget.step);
    final next = widget.min + (raw / step).round() * step;
    final clamped = next.clamp(widget.min, widget.max);
    if (clamped != widget.value) {
      widget.onChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final span = widget.max - widget.min;
    final fraction =
        span <= 0 ? 0.0 : ((widget.value - widget.min) / span).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return MouseRegion(
          cursor: widget.disabled
              ? SystemMouseCursors.forbidden
              : SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _update(d.localPosition.dx, width),
            onHorizontalDragStart: (d) {
              setState(() => _dragging = true);
              _update(d.localPosition.dx, width);
            },
            onHorizontalDragUpdate: (d) => _update(d.localPosition.dx, width),
            onHorizontalDragEnd: (_) => setState(() => _dragging = false),
            child: CustomPaint(
              size: Size(width, 32),
              painter: _ElSliderPainter(
                fraction: fraction,
                disabled: widget.disabled,
                active: !widget.disabled && (_hovered || _dragging),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ElSliderPainter extends CustomPainter {
  const _ElSliderPainter({
    required this.fraction,
    required this.disabled,
    required this.active,
  });

  final double fraction;
  final bool disabled;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final runway = Rect.fromLTWH(0, centerY - 3, size.width, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(runway, const Radius.circular(3)),
      Paint()..color = ElementDark.borderLight,
    );
    final accent = disabled ? ElementDark.placeholder : ElementDark.primary;
    final x = size.width * fraction;
    if (x > 0) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, centerY - 3, x, 6),
          topLeft: const Radius.circular(3),
          bottomLeft: const Radius.circular(3),
        ),
        Paint()..color = accent,
      );
    }
    final scale = active ? 1.2 : 1.0;
    final center = Offset(x, centerY);
    canvas
      ..drawCircle(center, 10 * scale, Paint()..color = Colors.white)
      ..drawCircle(
        center,
        9 * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * scale
          ..color = accent,
      );
  }

  @override
  bool shouldRepaint(_ElSliderPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.disabled != disabled ||
      oldDelegate.active != active;
}

/// Element Plus `.el-collapse-item__content` line-height (unitless).
const collapseContentLineHeight = 1.7692307692;

/// Restores `line-height: normal` (no [TextStyle.height]) for descendants,
/// e.g. Element Plus controls inside a collapse whose own CSS resets it.
class NexusNormalLineHeight extends StatelessWidget {
  const NexusNormalLineHeight({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = DefaultTextStyle.of(context).style;
    if (s.height == null) {
      return child;
    }
    return DefaultTextStyle(
      style: TextStyle(
        color: s.color,
        fontSize: s.fontSize,
        fontWeight: s.fontWeight,
        fontStyle: s.fontStyle,
        fontFamily: s.fontFamily,
        fontFamilyFallback: s.fontFamilyFallback,
        letterSpacing: s.letterSpacing,
        wordSpacing: s.wordSpacing,
        decoration: s.decoration,
        leadingDistribution: s.leadingDistribution,
      ),
      child: child,
    );
  }
}

/// One item of the `.detail-collapse` accordion used on detail pages.
class NexusCollapseItem extends StatelessWidget {
  const NexusCollapseItem({
    required this.header,
    required this.child,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final Widget header;
  final Widget child;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NexusColors.line),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF0080D19), Color(0xF0070B14)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              // `.el-collapse-item__header`: min-height 72, 13px text with a
              // 48px line-height inherited by the title slot, and a 1px
              // bottom border (transparent while active).
              child: Container(
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.only(left: 18, right: 18, bottom: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x08FFFFFF), Color(0x03FFFFFF)],
                  ),
                ),
                child: CustomPaint(
                  foregroundPainter: const InsetTopHighlightPainter(
                    radius: 24,
                    color: Color(0x09FFFFFF),
                    bottom: true,
                  ),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFEDF3FF),
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: header),
                        // `el-collapse-item__arrow`: 1em of the 13px header,
                        // flush with the header's 18px padding (measured).
                        AnimatedRotation(
                          turns: expanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: const NexusIcon(
                            Icons.chevron_right,
                            size: 13,
                            color: Color(0xBDDCE4F5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                    // `.el-collapse-item__content`: 13px, line-height 1.769
                    // (unitless, so every descendant inherits the factor).
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(
                        fontSize: 13,
                        height: collapseContentLineHeight,
                        leadingDistribution: TextLeadingDistribution.even,
                        color: Color(0xFFEDF3FF),
                      ),
                      child: child,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// `animate-pulse` placeholder bar/box.
class NexusPulse extends StatefulWidget {
  const NexusPulse({
    this.width,
    this.height = 16,
    this.radius = NexusRadii.pill,
    this.color = const Color(0x14FFFFFF),
    super.key,
  });

  final double? width;
  final double height;
  final double radius;
  final Color color;

  @override
  State<NexusPulse> createState() => _NexusPulseState();
}

class _NexusPulseState extends State<NexusPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.5).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Centered empty/error state block (`grid min-h-48 place-content-center
/// panel-soft text-center`).
class NexusMessagePanel extends StatelessWidget {
  const NexusMessagePanel({
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return NexusSurface.soft(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 160),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: NexusColors.text,
                ),
              ),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: NexusText.muted,
                ),
              ],
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      ),
    );
  }
}
