import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ui/redesign/rd_widgets.dart';

/// Owned-count and JSON import dialogs of the items pages.
///
/// PC/tablet: a centered `#0f1729` card (radius 20). Phones: a bottom sheet
/// (`#141414`, radius 22 on top, drag handle). Barrier taps, Esc, Android
/// back and the close button all go through [onCloseRequest] when given
/// (return `false` to keep the dialog open); without it the dialog just pops.
///
/// [closeLocked] dims the close button while something is in progress; the
/// button still forwards to [onCloseRequest], which decides whether the close
/// is refused or queued.
Future<T?> showItemsDialog<T>({
  required BuildContext context,
  required String title,
  required String closeLabel,
  required WidgetBuilder builder,
  double maxWidth = 420,
  Widget? compactHeader,
  ValueListenable<bool>? closeLocked,
  Future<bool> Function()? onCloseRequest,
}) {
  final compact = context.rdLayout == RdLayout.compact;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: closeLabel,
    barrierColor: compact ? const Color(0x8C000000) : const Color(0xA802050C),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      if (!compact) {
        return FadeTransition(opacity: curved, child: child);
      }
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return ItemsDialogFrame(
        title: title,
        closeLabel: closeLabel,
        maxWidth: maxWidth,
        compactHeader: compactHeader,
        closeLocked: closeLocked,
        onCloseRequest: onCloseRequest,
        child: Builder(builder: builder),
      );
    },
  );
}

class ItemsDialogFrame extends StatefulWidget {
  const ItemsDialogFrame({
    required this.title,
    required this.closeLabel,
    required this.child,
    this.maxWidth = 420,
    this.compactHeader,
    this.closeLocked,
    this.onCloseRequest,
    super.key,
  });

  final String title;
  final String closeLabel;
  final Widget child;
  final double maxWidth;

  /// Replaces the title text in the bottom-sheet header on phones.
  final Widget? compactHeader;
  final ValueListenable<bool>? closeLocked;
  final Future<bool> Function()? onCloseRequest;

  @override
  State<ItemsDialogFrame> createState() => _ItemsDialogFrameState();
}

class _ItemsDialogFrameState extends State<ItemsDialogFrame> {
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

  Widget _closeButton(bool compact) {
    Widget button(bool locked) => Opacity(
          opacity: locked ? 0.45 : 1,
          child: RdIconButton(
            icon: Icons.close,
            tooltip: widget.closeLabel,
            size: compact ? 44 : 40,
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

  @override
  Widget build(BuildContext context) {
    final compact = context.rdLayout == RdLayout.compact;
    final titleText = Semantics(
      header: true,
      child: Text(
        widget.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: RdColors.text,
        ),
      ),
    );
    final header = Row(
      children: [
        Expanded(
          child: compact ? (widget.compactHeader ?? titleText) : titleText,
        ),
        const SizedBox(width: 8),
        _closeButton(compact),
      ],
    );

    final Widget surface;
    if (compact) {
      final insets = MediaQuery.viewInsetsOf(context).bottom;
      final maxHeight = MediaQuery.sizeOf(context).height * 0.92 - insets;
      surface = Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: insets),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: math.max(maxHeight, 200)),
            decoration: const BoxDecoration(
              color: RdColors.sheet,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    header,
                    const SizedBox(height: 14),
                    widget.child,
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      final width =
          math.min(MediaQuery.sizeOf(context).width * 0.92, widget.maxWidth);
      surface = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Container(
            width: width,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: RdColors.inner2,
              borderRadius: BorderRadius.circular(RdRadii.card),
              border: Border.all(color: const Color(0x1AFFFFFF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  offset: Offset(0, 24),
                  blurRadius: 60,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, const SizedBox(height: 16), widget.child],
            ),
          ),
        ),
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
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: RdColors.text),
          child: surface,
        ),
      ),
    );
  }
}
