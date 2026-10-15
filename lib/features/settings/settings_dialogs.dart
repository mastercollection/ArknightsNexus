import 'package:flutter/material.dart';

import '../../ui/redesign/rd_widgets.dart';

/// `ElMessageBox.confirm` in the canvas style (`DesktopSettings.dc.html`
/// alertdialog): warning badge, title, message, cancel / confirm. Resolves to
/// true only when confirmed; barrier taps, Esc and Android back cancel.
Future<bool> showSettingsConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmText,
  required String cancelText,
}) async {
  final result = await showRdSheet<bool>(
    context: context,
    mode: RdSheetMode.dialog,
    maxWidth: 460,
    builder: (dialogContext) => _SettingsDialog(
      badge: '!',
      badgeColor: RdColors.gold,
      badgeFill: RdColors.goldFill,
      title: title,
      body: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: RdColors.secondary,
        ),
      ),
      cancelText: cancelText,
      onCancel: () => Navigator.of(dialogContext).pop(false),
      confirmText: confirmText,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return result == true;
}

/// `ElMessageBox.alert` in the canvas style: info badge, message, and an
/// optional monospace [detail] box (the log folder path).
Future<void> showSettingsAlert({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmText,
  String? detail,
}) {
  return showRdSheet<void>(
    context: context,
    mode: RdSheetMode.dialog,
    maxWidth: 460,
    builder: (dialogContext) => _SettingsDialog(
      badge: 'i',
      badgeColor: RdColors.cyan,
      badgeFill: const Color(0x248BD6FF),
      title: title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: RdColors.secondary,
            ),
          ),
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: RdColors.inner,
                borderRadius: BorderRadius.circular(RdRadii.control),
              ),
              child: SelectableText(detail, style: RdText.mono(fontSize: 12)),
            ),
          ],
        ],
      ),
      confirmText: confirmText,
      onConfirm: () => Navigator.of(dialogContext).pop(),
    ),
  );
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({
    required this.badge,
    required this.badgeColor,
    required this.badgeFill,
    required this.title,
    required this.body,
    required this.confirmText,
    required this.onConfirm,
    this.cancelText,
    this.onCancel,
  });

  final String badge;
  final Color badgeColor;
  final Color badgeFill;
  final String title;
  final Widget body;
  final String confirmText;
  final VoidCallback onConfirm;
  final String? cancelText;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final compact = context.rdLayout == RdLayout.compact;
    final buttonHeight = compact ? 48.0 : 40.0;
    final cancel = cancelText == null
        ? null
        : RdButton(
            label: cancelText!,
            variant: RdButtonVariant.ghost,
            height: buttonHeight,
            expand: compact,
            onPressed: onCancel,
          );
    final confirm = RdButton(
      label: confirmText,
      variant: RdButtonVariant.primary,
      height: buttonHeight,
      expand: compact,
      onPressed: onConfirm,
    );
    final Widget actions;
    if (compact) {
      actions = Row(
        children: [
          if (cancel != null) ...[
            Expanded(child: cancel),
            const SizedBox(width: 8),
          ],
          Expanded(child: confirm),
        ],
      );
    } else {
      actions = Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (cancel != null) ...[cancel, const SizedBox(width: 8)],
          confirm,
        ],
      );
    }

    return RdSheetFrame(
      title: title,
      titleLeading: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: badgeFill),
        child: ExcludeSemantics(
          child: Text(
            badge,
            style: TextStyle(fontWeight: FontWeight.w800, color: badgeColor),
          ),
        ),
      ),
      dialogPadding: EdgeInsets.all(compact ? 20 : 22),
      scrollable: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(child: SingleChildScrollView(child: body)),
          const SizedBox(height: 14),
          actions,
        ],
      ),
    );
  }
}
