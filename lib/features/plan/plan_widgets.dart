import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/nexus_media.dart';
import '../../ui/redesign/rd_widgets.dart';

export '../shared/number_format.dart' show formatPlanNumber;

/// Colours of the redesigned plan pages that `RdColors` does not name.
class PlanColors {
  const PlanColors._();

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

/// `max(0, required - owned)`: owned counts come from the item inventory.
double planShortage(num required, int? owned) =>
    math.max(0, required.toDouble() - (owned ?? 0));

/// Skill levels 1-7 read `Lv.n`; 8-10 are masteries M1-M3.
String planSkillLevelLabel(int level) =>
    level <= 7 ? 'Lv.$level' : 'Rank ${level - 7}';

/// Mastery badge images the user asked for wherever M1-M3 is shown.
String? rdMasteryAsset(int level) =>
    level >= 8 && level <= 10 ? 'assets/icons/skill/$level.png' : null;

bool _isCompact(BuildContext context) => context.rdLayout == RdLayout.compact;

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
                    RdPortrait(
                      charId: operatorId,
                      name: name,
                      size: portrait,
                      radius: 24,
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
          style: RdText.mono(fontSize: compact ? 17 : 19),
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
      return RdInset(padding: padding, child: Center(child: content));
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
                    style: RdText.mono(
                      fontSize: fontSize,
                      color: RdColors.secondary,
                    ),
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
    return RdInset(
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
    final mastery = rdMasteryAsset(level);
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
                  ? Text(
                      '$level',
                      style: RdText.mono(fontSize: 13, color: text),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(2),
                      child: RdMasteryIcon(
                        level,
                        size: 24,
                        fallbackStyle: RdText.mono(fontSize: 12, color: text),
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
    if (rdMasteryAsset(level) == null) {
      return Text(
        planSkillLevelLabel(level),
        style: RdText.mono(fontSize: fontSize, color: RdColors.secondary),
      );
    }
    return RdMasteryIcon(
      level,
      size: fontSize + 8,
      semanticLabel: masteryLabel(level - 7),
      fallbackStyle: RdText.mono(fontSize: fontSize, color: RdColors.gold),
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
        RdStepButton(
          increase: false,
          tooltip: decreaseLabel,
          width: compact ? 44 : 40,
          height: 44,
          onPressed: value > 1 ? () => onChanged(math.max(1, value - 1)) : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RdNumberInput(
            key: inputKey,
            value: value,
            min: 1,
            max: upper,
            semanticLabel: fieldLabel,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 6),
        RdStepButton(
          increase: true,
          tooltip: increaseLabel,
          width: compact ? 44 : 40,
          height: 44,
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
            style:
                RdText.mono(fontSize: compact ? 11 : 12, color: RdColors.muted),
          ),
        ),
      ],
    );
  }
}
