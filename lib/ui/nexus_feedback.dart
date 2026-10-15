import 'package:flutter/material.dart';

import 'nexus_controls.dart';
import 'nexus_icons.dart';
import 'nexus_scrollbar.dart';
import 'nexus_overlays.dart';

/// `ElMessageBox` status icon and colour per type (Element Plus dark).
(IconData, Color) _boxIcon(NexusMessageType type) {
  return switch (type) {
    NexusMessageType.success => (Icons.check_circle, const Color(0xFF67C23A)),
    NexusMessageType.warning => (
        Icons.warning_rounded,
        const Color(0xFFE6A23C)
      ),
    NexusMessageType.info => (Icons.info, const Color(0xFF909399)),
    NexusMessageType.error => (Icons.cancel, const Color(0xFFF56C6C)),
  };
}

/// Button used in [NexusMessageBox] (`el-button` / `el-button--primary`).
class NexusDialogButton extends StatelessWidget {
  const NexusDialogButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary ? ElementDark.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: primary ? ElementDark.primary : ElementDark.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: primary ? Colors.white : ElementDark.textRegular,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `ElMessageBox` shell: overlay card with title, close button, optional
/// status icon, content, and right-aligned buttons.
class NexusMessageBox extends StatelessWidget {
  const NexusMessageBox({
    required this.title,
    required this.content,
    this.actions = const [],
    this.type,
    this.width = 420,
    super.key,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final NexusMessageType? type;
  final double width;

  @override
  Widget build(BuildContext context) {
    final icon = type == null ? null : _boxIcon(type!);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: Material(
            color: ElementDark.bg,
            borderRadius: BorderRadius.circular(4),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            color: ElementDark.textPrimary,
                          ),
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const NexusIcon(
                            Icons.close,
                            size: 16,
                            color: ElementDark.placeholder,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (icon != null) ...[
                        NexusIcon(icon.$1, size: 24, color: icon.$2),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: ElementDark.textRegular,
                          ),
                          child: content,
                        ),
                      ),
                    ],
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: actions,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showNexusMessageBox<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return NexusScrollLock.guard(
    () => showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// `ElMessageBox.confirm`: resolves to true when confirmed.
Future<bool> showNexusConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmText,
  required String cancelText,
  NexusMessageType type = NexusMessageType.warning,
}) async {
  final result = await showNexusMessageBox<bool>(
    context: context,
    builder: (context) => NexusMessageBox(
      title: title,
      type: type,
      content: Text(message),
      actions: [
        NexusDialogButton(
          label: cancelText,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        NexusDialogButton(
          label: confirmText,
          primary: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return result == true;
}

/// `ElMessageBox.alert`.
Future<void> showNexusAlert({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmText,
  NexusMessageType type = NexusMessageType.info,
}) {
  return showNexusMessageBox<void>(
    context: context,
    builder: (context) => NexusMessageBox(
      title: title,
      type: type,
      content: SelectableText(message),
      actions: [
        NexusDialogButton(
          label: confirmText,
          primary: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
