import 'dart:async';

import 'package:flutter/material.dart';

import 'nexus_icons.dart';
import 'redesign/rd_tokens.dart';

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
    // Opaque surface-3 toast; the status shows in the icon and outline.
    final (Color border, Color fg, IconData icon) = switch (widget.type) {
      NexusMessageType.success => (
          RdColors.success,
          RdColors.success,
          Icons.check_circle,
        ),
      NexusMessageType.error => (
          RdColors.dangerLine,
          RdColors.dangerText,
          Icons.cancel,
        ),
      NexusMessageType.warning => (
          RdColors.warning,
          RdColors.warningText,
          Icons.error,
        ),
      NexusMessageType.info => (
          RdColors.border,
          RdColors.text2,
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
                    color: RdColors.surface3,
                    borderRadius: BorderRadius.circular(RdRadii.control),
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
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1,
                            color: RdColors.text,
                          ),
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
