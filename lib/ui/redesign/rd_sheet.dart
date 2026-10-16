import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'rd_widgets.dart';

/// Where [showRdSheet] presents its content.
enum RdSheetMode {
  /// Bottom sheet on phones, centered dialog on wider layouts.
  adaptive,

  /// Always a bottom sheet (the operator filter sheets).
  sheet,

  /// Always a dialog (confirmations).
  dialog,
}

/// Opens [builder] as a bottom sheet (surface-2, 20px top radius) or as a
/// faded-in dialog over the canvas barrier, per [mode]. The content usually
/// is an [RdSheetFrame], which draws the surface that matches the route.
///
/// [sheetMaxHeight] / [dialogMaxHeight] cap the surface (the frame fills at
/// most that much); [dialogAlignment] and [dialogPadding] place the dialog.
/// Pass `enableDrag: false` when the content guards its close
/// ([RdSheetFrame.onCloseRequest]), since a drag-dismiss bypasses the guard.
Future<T?> showRdSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  RdSheetMode mode = RdSheetMode.adaptive,
  String? barrierLabel,
  double maxWidth = 560,
  double sheetMaxWidth = double.infinity,
  double? sheetMaxHeight,
  double? dialogMaxHeight,
  AlignmentGeometry dialogAlignment = Alignment.center,
  EdgeInsets dialogPadding = const EdgeInsets.all(16),
  bool enableDrag = true,
}) {
  final sheet = switch (mode) {
    RdSheetMode.adaptive => context.rdLayout == RdLayout.compact,
    RdSheetMode.sheet => true,
    RdSheetMode.dialog => false,
  };
  Widget scoped(BuildContext context) =>
      _RdSheetScope(sheet: sheet, child: Builder(builder: builder));

  if (sheet) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: RdColors.barrier,
      constraints: BoxConstraints(
        maxWidth: sheetMaxWidth,
        maxHeight: sheetMaxHeight ?? double.infinity,
      ),
      builder: scoped,
    );
  }
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: RdColors.barrier,
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final height = MediaQuery.sizeOf(dialogContext).height;
      return SafeArea(
        child: Align(
          alignment: dialogAlignment,
          child: Padding(
            padding: dialogPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: dialogMaxHeight ?? height,
              ),
              child: scoped(dialogContext),
            ),
          ),
        ),
      );
    },
  );
}

class _RdSheetScope extends InheritedWidget {
  const _RdSheetScope({required this.sheet, required super.child});

  final bool sheet;

  @override
  bool updateShouldNotify(_RdSheetScope oldWidget) => sheet != oldWidget.sheet;
}

/// Surface of a [showRdSheet] route: the handle, optional header (title or a
/// custom [header], [titleLeading], close button) and [child].
///
/// Barrier taps, Esc, Android back and the close button all go through
/// [onCloseRequest] when given (return `false` to keep it open); without it
/// they just pop. [closeLocked] dims the close button while something is in
/// progress; the button still forwards to [onCloseRequest], which decides
/// whether the close is refused or queued.
class RdSheetFrame extends StatefulWidget {
  const RdSheetFrame({
    required this.child,
    this.title,
    this.header,
    this.titleLeading,
    this.closeLabel,
    this.closeKey,
    this.closeLocked,
    this.onCloseRequest,
    this.semanticLabel,
    this.color,
    this.sheetHeight,
    this.sheetMaxHeightFactor = 0.85,
    this.dialogPadding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
    this.headerGap = 14,
    this.scrollable = true,
    super.key,
  });

  final Widget child;
  final String? title;

  /// Replaces the title text in the header row.
  final Widget? header;

  /// Badge before the title (confirm / alert dialogs).
  final Widget? titleLeading;

  /// Tooltip of the close button; no close button without it.
  final String? closeLabel;
  final Key? closeKey;
  final ValueListenable<bool>? closeLocked;
  final Future<bool> Function()? onCloseRequest;

  /// Route name for screen readers; defaults to [title].
  final String? semanticLabel;

  /// Surface colour; surface-2 for sheets and dialogs.
  final Color? color;

  /// Fixed sheet height; otherwise the sheet wraps its content up to
  /// [sheetMaxHeightFactor] of the screen.
  final double? sheetHeight;
  final double sheetMaxHeightFactor;
  final EdgeInsets dialogPadding;

  /// Space between the header row and [child].
  final double headerGap;

  /// Wraps [child] in a scroll view; pass `false` when it scrolls itself.
  final bool scrollable;

  /// Whether the enclosing [showRdSheet] route is a bottom sheet.
  static bool isSheet(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RdSheetScope>()?.sheet ??
      false;

  @override
  State<RdSheetFrame> createState() => _RdSheetFrameState();
}

class _RdSheetFrameState extends State<RdSheetFrame> {
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

  Widget _closeButton(bool sheet) {
    Widget button(bool locked) => Opacity(
          opacity: locked ? 0.45 : 1,
          child: RdIconButton(
            key: widget.closeKey,
            icon: Icons.close,
            tooltip: widget.closeLabel!,
            size: sheet ? 44 : 40,
            filled: false,
            onPressed: () => unawaited(_requestClose()),
          ),
        );
    final locked = widget.closeLocked;
    if (locked == null) {
      return button(false);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: locked,
      builder: (context, value, _) => button(value),
    );
  }

  Widget? _header(bool sheet) {
    final title = widget.title;
    if (title == null && widget.header == null && widget.closeLabel == null) {
      return null;
    }
    final titleWidget = widget.header ??
        (title == null
            ? const SizedBox.shrink()
            : Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: RdColors.text,
                  ),
                ),
              ));
    return Row(
      crossAxisAlignment: widget.header == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (widget.titleLeading != null) ...[
          widget.titleLeading!,
          const SizedBox(width: 10),
        ],
        Expanded(child: titleWidget),
        if (widget.closeLabel != null) ...[
          const SizedBox(width: 8),
          _closeButton(sheet),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheet = RdSheetFrame.isSheet(context);
    final header = _header(sheet);
    Widget body = widget.child;
    if (widget.scrollable) {
      body = SingleChildScrollView(child: body);
    }
    final fixed = sheet && widget.sheetHeight != null;
    final column = Column(
      mainAxisSize: fixed ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sheet) ...[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: RdColors.handle,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (header != null) ...[header, SizedBox(height: widget.headerGap)],
        if (fixed) Expanded(child: body) else Flexible(child: body),
      ],
    );

    final Widget surface;
    if (sheet) {
      final media = MediaQuery.of(context);
      final insets = media.viewInsets.bottom;
      final height = widget.sheetHeight;
      surface = Container(
        height: height,
        constraints: BoxConstraints(
          maxHeight: height ??
              (media.size.height * widget.sheetMaxHeightFactor)
                  .clamp(200.0, double.infinity),
        ),
        decoration: BoxDecoration(
          color: widget.color ?? RdColors.surface2,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(RdRadii.sheet),
          ),
          border: const Border(top: BorderSide(color: RdColors.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 28 + insets),
            child: column,
          ),
        ),
      );
    } else {
      surface = Container(
        padding: widget.dialogPadding,
        decoration: BoxDecoration(
          color: widget.color ?? RdColors.surface2,
          borderRadius: BorderRadius.circular(RdRadii.sheet),
          border: Border.all(color: RdColors.border),
        ),
        child: column,
      );
    }

    return PopScope(
      canPop: widget.onCloseRequest == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_requestClose());
        }
      },
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: widget.semanticLabel ?? widget.title,
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: RdColors.text),
            child: surface,
          ),
        ),
      ),
    );
  }
}
