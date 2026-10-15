import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'nexus_controls.dart';
import 'nexus_icons.dart';
import 'nexus_scrollbar.dart';

/// Element Plus dark `--el-box-shadow`.
const _elDarkShadow = [
  BoxShadow(
    color: Color(0x5C000000),
    offset: Offset(0, 12),
    blurRadius: 32,
    spreadRadius: 4,
  ),
  BoxShadow(color: Color(0xB8000000), offset: Offset(0, 8), blurRadius: 20),
];

/// `el-dialog align-center destroy-on-close` with the dark theme.
///
/// The dialog content is wrapped in a [PopScope]; barrier taps, Esc, and the
/// header close button all go through [onCloseRequest] when provided (return
/// `false` to keep the dialog open, mirroring `close-on-click-modal=false`
/// plus an `@update:model-value` guard). Without it the dialog just pops.
Future<T?> showNexusDialog<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  double maxWidth = 420,
  Future<bool> Function()? onCloseRequest,
}) {
  return NexusScrollLock.guard(
    () => showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      // `--el-overlay-color-lighter` (dark): rgba(0,0,0,0.5).
      barrierColor: const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return NexusDialog(
          title: title,
          maxWidth: maxWidth,
          onCloseRequest: onCloseRequest,
          child: Builder(builder: builder),
        );
      },
    ),
  );
}

class NexusDialog extends StatefulWidget {
  const NexusDialog({
    required this.title,
    required this.child,
    this.maxWidth = 420,
    this.onCloseRequest,
    super.key,
  });

  final String title;
  final Widget child;

  /// Dialog width is `min(92vw, maxWidth)`.
  final double maxWidth;
  final Future<bool> Function()? onCloseRequest;

  @override
  State<NexusDialog> createState() => _NexusDialogState();
}

class _NexusDialogState extends State<NexusDialog> {
  bool _closing = false;

  Future<void> _requestClose() async {
    if (_closing) {
      return;
    }
    final guard = widget.onCloseRequest;
    if (guard == null) {
      Navigator.of(context).pop();
      return;
    }
    _closing = true;
    try {
      final allowed = await guard();
      if (allowed && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      _closing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.min(size.width * 0.92, widget.maxWidth);
    return PopScope(
      canPop: widget.onCloseRequest == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_requestClose());
        }
      },
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: width,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ElementDark.bg,
                borderRadius: BorderRadius.circular(4),
                boxShadow: _elDarkShadow,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 32, bottom: 16),
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 24 / 18,
                            color: ElementDark.textPrimary,
                          ),
                        ),
                      ),
                      DefaultTextStyle.merge(
                        style: const TextStyle(
                          fontSize: 14,
                          color: ElementDark.textRegular,
                        ),
                        child: widget.child,
                      ),
                    ],
                  ),
                  Positioned(
                    top: -16,
                    right: -16,
                    child: _DialogCloseButton(onTap: _requestClose),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogCloseButton extends StatefulWidget {
  const _DialogCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_DialogCloseButton> createState() => _DialogCloseButtonState();
}

class _DialogCloseButtonState extends State<_DialogCloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: NexusIcon(
            Icons.close,
            size: 16,
            color: _hovered ? ElementDark.primary : const Color(0xFF909399),
          ),
        ),
      ),
    );
  }
}

enum NexusMessageType { success, error, info, warning }

/// `ElMessage` toast: top-centered, auto-dismissed after 3s.
void showNexusMessage(
  BuildContext context,
  String message, {
  NexusMessageType type = NexusMessageType.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _NexusMessageToast(
      message: message,
      type: type,
      duration: duration,
      onDismissed: () {
        if (entry.mounted) {
          entry.remove();
        }
      },
    ),
  );
  overlay.insert(entry);
}

class _NexusMessageToast extends StatefulWidget {
  const _NexusMessageToast({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final NexusMessageType type;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_NexusMessageToast> createState() => _NexusMessageToastState();
}

class _NexusMessageToastState extends State<_NexusMessageToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) {
      return;
    }
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Element Plus dark: light-9 fill, light-8 border, base colour text.
    final (Color bg, Color border, Color fg, IconData icon) =
        switch (widget.type) {
      NexusMessageType.success => (
          const Color(0xFF1C2518),
          const Color(0xFF25371C),
          const Color(0xFF67C23A),
          Icons.check_circle,
        ),
      NexusMessageType.error => (
          const Color(0xFF2B1D1D),
          const Color(0xFF412626),
          const Color(0xFFF56C6C),
          Icons.cancel,
        ),
      NexusMessageType.warning => (
          const Color(0xFF292218),
          const Color(0xFF3E301C),
          const Color(0xFFE6A23C),
          Icons.error,
        ),
      NexusMessageType.info => (
          const Color(0xFF202121),
          const Color(0xFF2D2D2F),
          const Color(0xFF909399),
          Icons.info,
        ),
    };
    final topInset = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: topInset + 16,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _controller,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1),
              end: Offset.zero,
            ).animate(_controller),
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NexusIcon(icon, size: 16, color: fg),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: TextStyle(fontSize: 14, height: 1, color: fg),
                        ),
                      ),
                    ],
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

/// `el-input type="textarea"` (dark theme): 5px/11px padding, 1.5 line
/// height, [rows] visible lines.
class NexusTextArea extends StatefulWidget {
  const NexusTextArea({
    this.controller,
    this.placeholder,
    this.rows = 2,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final int rows;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  State<NexusTextArea> createState() => _NexusTextAreaState();
}

class _NexusTextAreaState extends State<NexusTextArea> {
  final _focusNode = FocusNode();
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final borderColor = !enabled
        ? ElementDark.borderLight
        : _focusNode.hasFocus
            ? ElementDark.primary
            : (_hovered ? ElementDark.borderHover : ElementDark.border);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: enabled ? Colors.transparent : ElementDark.fillLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: enabled,
          onChanged: widget.onChanged,
          minLines: widget.rows,
          maxLines: widget.rows,
          keyboardType: TextInputType.multiline,
          cursorColor: ElementDark.textRegular,
          cursorWidth: 1,
          style: TextStyle(
            color: enabled ? ElementDark.textRegular : ElementDark.placeholder,
            fontSize: 14,
            height: 1.5,
          ),
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: widget.placeholder,
            hintStyle: const TextStyle(
              color: ElementDark.placeholder,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
