import 'dart:async';

import 'package:flutter/material.dart';

import 'nexus_icons.dart';

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

/// `ElMessageBox` overlay: a faded-in modal route over a 50% black barrier
/// that dismisses on barrier tap; [builder] supplies the whole box.
Future<T?> showNexusMessageBox<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x80000000),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
