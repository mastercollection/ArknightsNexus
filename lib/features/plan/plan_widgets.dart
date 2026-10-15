import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../ui/nexus_media.dart';
import '../../ui/redesign/rd_widgets.dart';

/// Colours of the redesigned plan pages that `RdColors` does not name.
class PlanColors {
  const PlanColors._();

  /// `#dbe2f0`: first line of state panels, tier labels.
  static const stateTitle = Color(0xFFDBE2F0);

  /// `#ffb3b3`: shortage counts.
  static const shortage = Color(0xFFFFB3B3);

  /// `#ffc6c6`: validation messages.
  static const validation = Color(0xFFFFC6C6);
  static const validationFill = Color(0x14FF6666);
  static const validationBorder = Color(0x40FF7878);

  /// Removal (selection mode) colours.
  static const dangerBorder = Color(0x73FF7878);
  static const dangerFill = Color(0x29FF7878);
  static const dangerText = Color(0xFFFFD0D0);
  static const pendingFill = Color(0x3378141C);
  static const pendingBorder = Color(0x66FF7878);

  /// Muted footnote / separator colour (`#6f7c94`).
  static const faint = Color(0xFF6F7C94);

  /// Error toast.
  static const toastFill = Color(0xFF2A1215);

  /// Item icon outline tints by material tier (`TIER_TINT` of the canvas).
  static Color tierTint(int tier) => switch (tier) {
        5 => const Color(0x99FFCF70),
        4 => const Color(0x8CC4A0FF),
        3 => const Color(0x808BD6FF),
        2 => const Color(0x736EE7A8),
        1 => const Color(0x40FFFFFF),
        _ => const Color(0x2EFFFFFF),
      };

  /// EXP (gold) and LMD (violet) resource icon outlines.
  static const expTint = Color(0x8CFFCF70);
  static const lmdTint = Color(0x8CC4A0FF);
}

final _numberFormat = NumberFormat('#,##0.###', 'en_US');

/// `new Intl.NumberFormat('ko-KR').format(value)`.
String formatPlanNumber(num value) => _numberFormat.format(value);

/// `max(0, required - owned)`: owned counts come from the item inventory.
double planShortage(num required, int? owned) =>
    math.max(0, required.toDouble() - (owned ?? 0));

/// Skill levels 1-7 read `Lv.n`; 8-10 are masteries M1-M3.
String planSkillLevelLabel(int level) =>
    level <= 7 ? 'Lv.$level' : 'Rank ${level - 7}';

/// Mastery badge images the user asked for wherever M1-M3 is shown.
String? planMasteryAsset(int level) =>
    level >= 8 && level <= 10 ? 'assets/icons/skill/$level.png' : null;

bool _isCompact(BuildContext context) => context.rdLayout == RdLayout.compact;

/// Monospace text style of the canvas (`JetBrains Mono`).
TextStyle planMono(double size, {Color color = RdColors.text}) =>
    RdText.mono(fontSize: size, color: color);

/// Page body of a plan screen: the header stays pinned above the scrolling
/// content on phones and scrolls with it on wider layouts, as the canvas
/// draws it. [overlay] (the autosave error toast) floats above everything.
class PlanPageFrame extends StatelessWidget {
  const PlanPageFrame({
    required this.header,
    required this.children,
    this.overlay,
    super.key,
  });

  final Widget header;
  final List<Widget> children;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final compact = _isCompact(context);
    final padding = rdPagePadding(context);
    final gap = compact ? 12.0 : 18.0;
    final content = <Widget>[
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ];

    final Widget body;
    if (compact) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: SingleChildScrollView(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: content,
              ),
            ),
          ),
        ],
      );
    } else {
      body = SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, SizedBox(height: gap), ...content],
        ),
      );
    }

    // A plain Scaffold only provides a ScaffoldMessenger target and text
    // selection; navigation chrome comes from the shell.
    return Scaffold(
      backgroundColor: RdColors.bg,
      body: Stack(
        children: [
          Positioned.fill(child: body),
          if (overlay != null) overlay!,
        ],
      ),
    );
  }
}

/// Card shell of the plan pages (`#0c1426`, radius 18).
class PlanCard extends StatelessWidget {
  const PlanCard({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return RdCard(
      radius: RdRadii.tile,
      padding: padding ?? EdgeInsets.all(_isCompact(context) ? 14 : 18),
      child: child,
    );
  }
}

/// `rgba(255,255,255,0.03)` block inside a card.
class PlanInset extends StatelessWidget {
  const PlanInset({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = RdRadii.inner,
    this.color = RdColors.white3,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Section heading: bold title + secondary description.
class PlanHeading extends StatelessWidget {
  const PlanHeading({
    required this.title,
    this.description,
    this.large = false,
    super.key,
  });

  final String title;
  final String? description;

  /// 17px (16px on phones) section titles; otherwise 15px.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final compact = _isCompact(context);
    final titleSize = large ? (compact ? 16.0 : 17.0) : 15.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              color: RdColors.text,
            ),
          ),
        ),
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: TextStyle(
              fontSize: large && !compact ? 13 : 12,
              height: 1.45,
              color: RdColors.secondary2,
            ),
          ),
        ],
      ],
    );
  }
}

/// Empty state block (`rgba(255,255,255,0.03)`, radius 16).
class PlanEmptyBox extends StatelessWidget {
  const PlanEmptyBox({
    required this.title,
    required this.description,
    super.key,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return PlanInset(
      padding: EdgeInsets.all(_isCompact(context) ? 16 : 18),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, color: PlanColors.stateTitle),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 13, color: RdColors.secondary2),
          ),
        ],
      ),
    );
  }
}

/// Error state with the raw error message and an optional retry button.
class PlanErrorPanel extends StatelessWidget {
  const PlanErrorPanel({
    required this.title,
    required this.message,
    this.retryLabel,
    this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: PlanCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                color: PlanColors.stateTitle,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              message,
              style: planMono(13, color: RdColors.secondary2),
            ),
            if (onRetry != null && retryLabel != null) ...[
              const SizedBox(height: 10),
              PlanLinkButton(label: retryLabel!, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

/// Outlined accent button of the canvas (retry, open detail).
class PlanLinkButton extends StatelessWidget {
  const PlanLinkButton({
    required this.label,
    required this.onPressed,
    this.height,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final resolvedHeight = height ?? (_isCompact(context) ? 44.0 : 40.0);
    return Material(
      color: RdColors.linkFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RdRadii.control),
        side: const BorderSide(color: RdColors.linkBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(RdRadii.control),
        onTap: onPressed,
        child: Container(
          height: resolvedHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: RdColors.linkText,
            ),
          ),
        ),
      ),
    );
  }
}

/// 44px accent-filled icon button (phone "add operator").
class PlanAccentIconButton extends StatelessWidget {
  const PlanAccentIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: RdColors.accent,
          borderRadius: BorderRadius.circular(RdRadii.control),
          child: InkWell(
            borderRadius: BorderRadius.circular(RdRadii.control),
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 22, color: RdColors.onAccent),
            ),
          ),
        ),
      ),
    );
  }
}

/// Star row (`★` x rarity) in the canvas gold.
class PlanStars extends StatelessWidget {
  const PlanStars({required this.rarity, this.fontSize = 10, super.key});

  final int rarity;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      '★' * math.max(0, rarity),
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSize,
        height: 1,
        letterSpacing: fontSize * 0.04,
        color: RdColors.gold,
        shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 4)],
      ),
    );
  }
}

enum PlanTileMode { open, pick, favorite }

/// Operator tile of the plan grid: portrait (stars overlay), name, and the
/// mode-specific decoration (removal checkbox, favorite badge + add hint).
class PlanOperatorTile extends StatelessWidget {
  const PlanOperatorTile({
    required this.operatorId,
    required this.name,
    required this.rarity,
    required this.mode,
    required this.onTap,
    required this.semanticLabel,
    this.pending = false,
    this.footer,
    super.key,
  });

  final String operatorId;
  final String name;
  final int rarity;
  final PlanTileMode mode;
  final bool pending;
  final VoidCallback onTap;
  final String semanticLabel;

  /// "+ 플랜에 추가" under favorite tiles.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final compact = _isCompact(context);
    final portrait = compact ? 76.0 : 84.0;
    final (Color fill, Color border) = switch (mode) {
      PlanTileMode.open => (RdColors.inner, RdColors.line2),
      PlanTileMode.favorite => (RdColors.inner, const Color(0x5985B6FF)),
      PlanTileMode.pick => pending
          ? (PlanColors.pendingFill, PlanColors.pendingBorder)
          : (const Color(0x05FFFFFF), RdColors.white10),
    };
    final radius = BorderRadius.circular(compact ? 16 : RdRadii.tile);

    Widget? badge;
    if (mode == PlanTileMode.pick) {
      badge = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: pending ? const Color(0xFF4A1A20) : const Color(0xFF0A0F1E),
          border: Border.all(
            color: pending ? const Color(0x80FF7878) : RdColors.white14,
          ),
        ),
        child: Icon(
          Icons.check,
          size: 14,
          color: pending ? PlanColors.shortage : const Color(0xFF8592AA),
        ),
      );
    } else if (mode == PlanTileMode.favorite) {
      badge = Container(
        width: compact ? 22 : 24,
        height: compact ? 22 : 24,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: RdColors.gold,
        ),
        child: const Text(
          '★',
          style: TextStyle(fontSize: 12, color: Color(0xFF1A1205)),
        ),
      );
    }

    return Semantics(
      button: true,
      selected: mode == PlanTileMode.pick ? pending : null,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: compact
                ? const EdgeInsets.fromLTRB(6, 10, 6, 12)
                : const EdgeInsets.fromLTRB(10, 14, 10, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    OperatorPortrait(
                      charId: operatorId,
                      name: name,
                      dimension: portrait,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: compact ? 3 : 4,
                      child: PlanStars(
                        rarity: rarity,
                        fontSize: compact ? 9 : 10,
                      ),
                    ),
                    if (badge != null)
                      Positioned(top: -6, right: -6, child: badge),
                  ],
                ),
                SizedBox(height: compact ? 6 : 8),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: RdColors.text,
                  ),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    footer!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      color: RdColors.link,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Real item icon in a tier-tinted outline; tapping opens the item page.
class PlanItemIconLink extends StatelessWidget {
  const PlanItemIconLink({
    required this.itemId,
    required this.name,
    required this.semanticLabel,
    required this.onTap,
    this.iconId,
    this.size = 48,
    this.tint = const Color(0x2EFFFFFF),
    super.key,
  });

  final String itemId;
  final String? iconId;
  final String name;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double size;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.27);
    return Semantics(
      link: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: RdColors.portrait,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tint),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: ItemIcon(
              itemId: itemId,
              iconId: iconId,
              name: name,
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}

/// EXP / LMD total with its item icon and the LMD shortage line.
class PlanResourceCard extends StatelessWidget {
  const PlanResourceCard({
    required this.label,
    required this.itemId,
    required this.itemName,
    required this.value,
    required this.linkLabel,
    required this.tint,
    this.iconId,
    this.shortageLabel,
    this.inset = false,
    this.onOpenItem,
    super.key,
  });

  final String label;
  final String itemId;
  final String? iconId;
  final String itemName;
  final String value;
  final String linkLabel;
  final Color tint;

  /// Shown only when the owned count does not cover the requirement.
  final String? shortageLabel;

  /// Inset block inside the detail result card instead of its own card.
  final bool inset;
  final VoidCallback? onOpenItem;

  @override
  Widget build(BuildContext context) {
    final compact = _isCompact(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: inset ? 0 : 0.96,
            color: inset ? RdColors.secondary2 : RdColors.muted,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        PlanItemIconLink(
          itemId: itemId,
          iconId: iconId,
          name: itemName,
          semanticLabel: linkLabel,
          size: compact ? 48 : 52,
          tint: tint,
          onTap: onOpenItem,
        ),
        SizedBox(height: compact ? 6 : 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: planMono(compact ? 17 : 19),
        ),
        if (shortageLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            shortageLabel!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: PlanColors.shortage,
            ),
          ),
        ],
      ],
    );
    final padding = EdgeInsets.symmetric(
      horizontal: compact ? 8 : 12,
      vertical: compact ? 12 : 14,
    );
    if (inset) {
      return PlanInset(padding: padding, child: Center(child: content));
    }
    return RdCard(
      radius: RdRadii.tile,
      padding: padding,
      child: Center(child: content),
    );
  }
}

/// Farming row: label (stage code in mono) + runs / sanity chip.
class PlanFarmingRow extends StatelessWidget {
  const PlanFarmingRow({
    required this.label,
    required this.chip,
    this.code,
    this.gold = false,
    this.boxed = false,
    super.key,
  });

  final String label;
  final String? code;
  final String chip;

  /// Gold sanity chip instead of the blue runs chip.
  final bool gold;

  /// Its own inset row (summary) instead of a plain row (detail).
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final compact = _isCompact(context);
    final fontSize = boxed && !compact ? 14.0 : 13.0;
    final row = Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: code == null ? label : '$label ',
              children: [
                if (code != null)
                  TextSpan(
                    text: code,
                    style: planMono(fontSize, color: RdColors.secondary),
                  ),
              ],
            ),
            style: TextStyle(fontSize: fontSize, color: RdColors.secondary),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: gold ? RdColors.goldFill : RdColors.blueFill,
            borderRadius: BorderRadius.circular(RdRadii.pill),
          ),
          child: Text(
            chip,
            style: TextStyle(
              fontSize: 12,
              fontWeight: gold ? FontWeight.w700 : FontWeight.w400,
              color: gold ? RdColors.warnText : RdColors.blueText,
            ),
          ),
        ),
      ],
    );
    if (!boxed) {
      return row;
    }
    return PlanInset(
      padding:
          EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 10 : 12),
      child: row,
    );
  }
}

/// Validation messages (`role="alert"` red block).
class PlanValidationBox extends StatelessWidget {
  const PlanValidationBox({required this.messages, this.title, super.key});

  final String? title;
  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final compact = _isCompact(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          title == null ? 12 : (compact ? 14 : 16),
        ),
        decoration: BoxDecoration(
          color: PlanColors.validationFill,
          borderRadius: BorderRadius.circular(
            title == null ? RdRadii.inner : RdRadii.tile,
          ),
          border: Border.all(color: PlanColors.validationBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: RdColors.text,
                ),
              ),
              const SizedBox(height: 8),
            ],
            for (var i = 0; i < messages.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              Text(
                messages[i],
                style: TextStyle(
                  fontSize: compact && title == null ? 12 : 13,
                  color: PlanColors.validation,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum PlanSaveStatus { idle, saving, saved, failed }

/// Autosave status pill in the operator plan header.
class PlanSaveStatusPill extends StatelessWidget {
  const PlanSaveStatusPill({
    required this.status,
    required this.label,
    super.key,
  });

  final PlanSaveStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final failed = status == PlanSaveStatus.failed;
    final dotColor = switch (status) {
      PlanSaveStatus.idle => RdColors.muted,
      PlanSaveStatus.saving => RdColors.accent,
      PlanSaveStatus.saved => RdColors.success,
      PlanSaveStatus.failed => RdColors.danger,
    };
    final textColor = switch (status) {
      PlanSaveStatus.idle => RdColors.secondary2,
      PlanSaveStatus.failed => PlanColors.dangerText,
      _ => RdColors.text,
    };
    Widget dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
    );
    if (status == PlanSaveStatus.saving) {
      dot = RdPulse(child: dot);
    }
    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        key: const Key('plan-save-status'),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: failed ? PlanColors.toastFill : RdColors.inner2,
          borderRadius: BorderRadius.circular(RdRadii.pill),
          border: Border.all(
            color: failed ? const Color(0x80FF7878) : RdColors.white10,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _isCompact(context) ? 120 : 240,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top-centred error toast (autosave failure message), dismissible.
class PlanErrorToast extends StatelessWidget {
  const PlanErrorToast({
    required this.message,
    required this.dismissLabel,
    required this.onDismiss,
    super.key,
  });

  final String message;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final compact = _isCompact(context);
    return Positioned(
      top: compact ? 72 : 20,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Semantics(
              liveRegion: true,
              child: Material(
                key: const Key('plan-save-error-toast'),
                color: PlanColors.toastFill,
                elevation: 8,
                shadowColor: const Color(0x73000000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RdRadii.control),
                  side: const BorderSide(color: PlanColors.dangerBorder),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 2, 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 18,
                          color: RdColors.danger,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(
                              fontSize: 13,
                              color: PlanColors.dangerText,
                            ),
                          ),
                        ),
                        RdIconButton(
                          icon: Icons.close,
                          tooltip: dismissLabel,
                          filled: false,
                          onPressed: onDismiss,
                        ),
                      ],
                    ),
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

/// Segmented radio group (elite phase, module stage).
class PlanSegmentedPicker<T> extends StatelessWidget {
  const PlanSegmentedPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    required this.semanticLabel,
    this.leadingOf,
    this.segmentKeyOf,
    super.key,
  });

  final List<T> options;
  final T? selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final Widget? Function(T)? leadingOf;
  final Key Function(T)? segmentKeyOf;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final compact = _isCompact(context);
    final height = compact ? 44.0 : 40.0;
    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        padding: EdgeInsets.all(compact ? 3 : 4),
        decoration: BoxDecoration(
          color: RdColors.segmentTrack,
          borderRadius: BorderRadius.circular(RdRadii.control),
        ),
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) SizedBox(width: compact ? 3 : 4),
              Expanded(child: _segment(options[i], height)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(T option, double height) {
    final on = option == selected;
    final leading = leadingOf?.call(option);
    return Semantics(
      key: segmentKeyOf?.call(option),
      button: true,
      selected: on,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: on ? RdColors.segmentOn : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: on ? null : () => onChanged(option),
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 4)],
                Flexible(
                  child: Text(
                    labelOf(option),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? RdColors.onSegment : RdColors.secondary2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skill level 1-10 chips: 1-7 as numbers, 8-10 as the mastery images.
class PlanSkillLevelPicker extends StatelessWidget {
  const PlanSkillLevelPicker({
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
    required this.chipKeyPrefix,
    required this.masteryLabel,
    super.key,
  });

  final int? selected;
  final ValueChanged<int> onChanged;
  final String semanticLabel;

  /// Each chip gets `Key('$chipKeyPrefix-$level')`.
  final String chipKeyPrefix;

  /// Spoken label of mastery chips (`특화 {rank}`).
  final String Function(int rank) masteryLabel;

  @override
  Widget build(BuildContext context) {
    final compact = _isCompact(context);
    final height = compact ? 44.0 : 40.0;
    final gap = compact ? 3.0 : 4.0;
    return Semantics(
      label: semanticLabel,
      container: true,
      child: Row(
        children: [
          for (var level = 1; level <= 10; level++) ...[
            if (level > 1) SizedBox(width: gap),
            Expanded(child: _chip(level, height)),
          ],
        ],
      ),
    );
  }

  Widget _chip(int level, double height) {
    final on = level == selected;
    final mastery = planMasteryAsset(level);
    final (Color fill, Color border, Color text) = on
        ? (RdColors.segmentOn, const Color(0xB385B6FF), RdColors.onSegment)
        : mastery != null
            ? (const Color(0x0FFFCF70), const Color(0x47FFCF70), RdColors.gold)
            : (RdColors.segmentTrack, RdColors.white10, RdColors.secondary);
    return Semantics(
      key: Key('$chipKeyPrefix-$level'),
      button: true,
      selected: on,
      inMutuallyExclusiveGroup: true,
      label: mastery == null
          ? planSkillLevelLabel(level)
          : masteryLabel(level - 7),
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: on ? null : () => onChanged(level),
          child: SizedBox(
            height: height,
            child: Center(
              child: mastery == null
                  ? Text('$level', style: planMono(13, color: text))
                  : Padding(
                      padding: const EdgeInsets.all(2),
                      child: Image.asset(
                        mastery,
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Text(
                          'M${level - 7}',
                          style: planMono(12, color: text),
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

/// `Lv.n` text, or the mastery image for levels 8-10.
class PlanSkillLevelBadge extends StatelessWidget {
  const PlanSkillLevelBadge({
    required this.level,
    required this.masteryLabel,
    this.fontSize = 12,
    super.key,
  });

  final int level;
  final String Function(int rank) masteryLabel;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final asset = planMasteryAsset(level);
    if (asset == null) {
      return Text(
        planSkillLevelLabel(level),
        style: planMono(fontSize, color: RdColors.secondary),
      );
    }
    return Semantics(
      label: masteryLabel(level - 7),
      excludeSemantics: true,
      child: Image.asset(
        asset,
        width: fontSize + 8,
        height: fontSize + 8,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Text(
          'M${level - 7}',
          style: planMono(fontSize, color: RdColors.gold),
        ),
      ),
    );
  }
}

/// Elite phase icon (`assets/icons/elite/N.webp`) used in the elite picker.
class PlanEliteIcon extends StatelessWidget {
  const PlanEliteIcon({required this.elite, this.size = 18, super.key});

  final int elite;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        'assets/icons/elite/$elite.webp',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Level input with -/+ steppers and the `/ cap` hint.
class PlanLevelStepper extends StatelessWidget {
  const PlanLevelStepper({
    required this.value,
    required this.max,
    required this.onChanged,
    required this.decreaseLabel,
    required this.increaseLabel,
    required this.fieldLabel,
    this.inputKey,
    super.key,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  final String decreaseLabel;
  final String increaseLabel;
  final String fieldLabel;
  final Key? inputKey;

  @override
  Widget build(BuildContext context) {
    final compact = _isCompact(context);
    final upper = math.max(1, max);
    return Row(
      children: [
        _StepButton(
          symbol: '−',
          tooltip: decreaseLabel,
          width: compact ? 44 : 40,
          onPressed: value > 1 ? () => onChanged(math.max(1, value - 1)) : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: PlanNumberInput(
            key: inputKey,
            value: value,
            min: 1,
            max: upper,
            semanticLabel: fieldLabel,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 6),
        _StepButton(
          symbol: '+',
          tooltip: increaseLabel,
          width: compact ? 44 : 40,
          onPressed: value < upper
              ? () => onChanged(math.min(upper, value + 1))
              : null,
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: compact ? 34 : 38,
          child: Text(
            '/ $upper',
            maxLines: 1,
            style: planMono(compact ? 11 : 12, color: RdColors.muted),
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.symbol,
    required this.tooltip,
    required this.width,
    required this.onPressed,
  });

  final String symbol;
  final String tooltip;
  final double width;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RdRadii.small),
            side: const BorderSide(color: RdColors.white14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(RdRadii.small),
            onTap: onPressed,
            child: SizedBox(
              width: width,
              height: 44,
              child: Center(
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontSize: 18,
                    color: enabled ? RdColors.secondary : RdColors.placeholder,
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

/// Centered integer input that clamps to [min]..[max] while typing and
/// restores the display value on blur (`el-input-number :controls=false`).
class PlanNumberInput extends StatefulWidget {
  const PlanNumberInput({
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
  State<PlanNumberInput> createState() => _PlanNumberInputState();
}

class _PlanNumberInputState extends State<PlanNumberInput> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.value}');
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(PlanNumberInput oldWidget) {
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
    setState(() {});
  }

  void _restoreDisplay() {
    final text = '${_clamp(widget.value)}';
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  int _clamp(int value) {
    final upper = math.max(widget.min, widget.max);
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
    final focused = _focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 44,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: RdColors.segmentTrack,
        borderRadius: BorderRadius.circular(RdRadii.small),
        border: Border.all(
          color: focused ? RdColors.accent : RdColors.white14,
        ),
      ),
      child: Semantics(
        label: widget.semanticLabel,
        textField: true,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _handleChanged,
          onSubmitted: (_) => _restoreDisplay(),
          cursorColor: RdColors.accent,
          style: planMono(15),
          decoration: const InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
