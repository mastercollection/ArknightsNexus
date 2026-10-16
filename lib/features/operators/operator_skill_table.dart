import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/operator.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'operator_detail_view_model.dart';

/// Skill level comparison table: horizontally scrollable, the item column
/// stays pinned on the left, the selected level column is highlighted and
/// the table scrolls so that column sits right next to the pinned one
/// (`scrollSkillTableToSelectedLevel`). Levels 8-10 show the M1-M3 icons.
class OperatorSkillTable extends StatefulWidget {
  const OperatorSkillTable({
    required this.skill,
    required this.rows,
    required this.selectedLevel,
    required this.itemLabel,
    this.internalLabel = '',
    this.compact = false,
    this.masteryLabel,
    super.key,
  });

  final OperatorSkill skill;
  final List<SkillComparisonRow> rows;
  final int selectedLevel;
  final String itemLabel;

  /// Heading of the [SkillRowKind.internal] rows.
  final String internalLabel;

  /// Phone widths: 116px item column, 52px minimum level columns.
  final bool compact;

  /// Semantic label of a mastery icon (`M1`...), from the mastery rank.
  final String Function(int rank)? masteryLabel;

  @override
  State<OperatorSkillTable> createState() => _OperatorSkillTableState();
}

const _fontSize = 13.0;
const _cellPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);
const _firstPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

/// Room under the table for the scrollbar when it overflows.
const _scrollbarGap = 12.0;

/// The section card behind the table ([RdInset.section]).
const _stickyFill = RdColors.surface2;
const _rowLine = RdColors.white8;

class _OperatorSkillTableState extends State<OperatorSkillTable> {
  final _controller = ScrollController();
  double _dataColumnWidth = 58;

  @override
  void initState() {
    super.initState();
    // Initial render: jump without animation (`behavior: 'auto'`).
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToSelected(animate: false));
  }

  @override
  void didUpdateWidget(OperatorSkillTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLevel != widget.selectedLevel) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToSelected({bool animate = true}) {
    if (!mounted || !_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final index =
        widget.skill.levels.indexWhere((l) => l.level == widget.selectedLevel);
    final target = widget.selectedLevel <= 1 || index < 0
        ? 0.0
        : (index * _dataColumnWidth).clamp(0.0, position.maxScrollExtent);
    if (animate) {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _controller.jumpTo(target);
    }
  }

  double _measure(String text, FontWeight weight, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: _fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final levels = widget.skill.levels;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final horizontal = _cellPadding.horizontal;
        // Item column: as wide as its longest label, between the old fixed
        // width and half the table; longer labels wrap to two lines.
        var labelWidth = _measure(widget.itemLabel, FontWeight.w600, scaler);
        for (final row in widget.rows) {
          labelWidth = math.max(
            labelWidth,
            _measure(row.label, FontWeight.w600, scaler),
          );
        }
        final double firstWidth =
            (labelWidth + _firstPadding.horizontal + 1).ceilToDouble().clamp(
                  math.min(widget.compact ? 116.0 : 150.0, available * 0.45),
                  math.max(available * 0.5, widget.compact ? 116.0 : 150.0),
                );
        var dataWidth = widget.compact ? 52.0 : 58.0;
        for (final level in levels) {
          dataWidth = math.max(
            dataWidth,
            _measure('Lv.${level.level}', FontWeight.w600, scaler) + horizontal,
          );
        }
        for (final row in widget.rows) {
          for (final value in row.values) {
            dataWidth = math.max(
              dataWidth,
              _measure(value, FontWeight.w400, scaler) + horizontal,
            );
          }
        }
        dataWidth = dataWidth.ceilToDouble();
        // `min-width: 100%`: spare width goes to the level columns.
        final natural = firstWidth + dataWidth * levels.length;
        if (natural < available && levels.isNotEmpty) {
          dataWidth = (available - firstWidth) / levels.length;
        }
        _dataColumnWidth = dataWidth;
        final tableWidth = firstWidth + dataWidth * levels.length;

        final table = _buildTable(firstWidth, dataWidth);
        final overflows = tableWidth > available + 0.5;
        return Semantics(
          container: true,
          child: Stack(
            children: [
              // Mice drag the table sideways too (desktop and web scroll
              // views ignore mouse drags by default), and the scrollbar
              // stays visible while columns are hidden.
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: PointerDeviceKind.values.toSet(),
                ),
                child: Scrollbar(
                  controller: _controller,
                  thumbVisibility: overflows,
                  child: SingleChildScrollView(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(
                      bottom: overflows ? _scrollbarGap : 0,
                    ),
                    child: SizedBox(width: tableWidth, child: table),
                  ),
                ),
              ),
              // Sticky first column: an identical copy clipped to its width.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: firstWidth,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final offset =
                        _controller.hasClients ? _controller.offset : 0.0;
                    return offset > 0 ? child! : const SizedBox.shrink();
                  },
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          minWidth: tableWidth,
                          maxWidth: tableWidth,
                          child: table,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTable(double firstWidth, double dataWidth) {
    final levels = widget.skill.levels;
    final selected = widget.selectedLevel;

    Widget firstCell(
      String text, {
      required bool header,
      SkillRowKind kind = SkillRowKind.base,
    }) {
      final style = TextStyle(
        fontSize: _fontSize,
        fontWeight:
            kind == SkillRowKind.internal ? FontWeight.w500 : FontWeight.w600,
        color: header || kind == SkillRowKind.internal
            ? RdColors.text2
            : RdColors.text,
      );
      // The value's place in a described label, in the accent colour.
      final slot = text.indexOf(skillValueSlot);
      return Container(
        width: firstWidth,
        padding: _firstPadding,
        alignment: Alignment.centerLeft,
        decoration: const BoxDecoration(
          color: _stickyFill,
          border: Border(bottom: BorderSide(color: _rowLine)),
        ),
        child: Text.rich(
          slot < 0
              ? TextSpan(text: text)
              : TextSpan(
                  children: [
                    TextSpan(text: text.substring(0, slot)),
                    const TextSpan(
                      text: skillValueSlot,
                      style: TextStyle(color: RdColors.accentHover),
                    ),
                    TextSpan(
                      text: text.substring(slot + skillValueSlot.length),
                    ),
                  ],
                ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      );
    }

    Widget sectionRow(String text) {
      return Container(
        key: const ValueKey('skill-table-internal'),
        width: firstWidth + dataWidth * levels.length,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _rowLine)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: RdColors.text3,
          ),
        ),
      );
    }

    Widget dataCell({
      required Widget child,
      required bool isSelected,
      required Color selectedFill,
    }) {
      return Container(
        width: dataWidth,
        padding: _cellPadding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? selectedFill : null,
          border: const Border(bottom: BorderSide(color: _rowLine)),
        ),
        child: child,
      );
    }

    final header = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          firstCell(widget.itemLabel, header: true),
          for (final level in levels)
            dataCell(
              isSelected: level.level == selected,
              selectedFill: RdColors.accentSoft,
              child: rdMasteryAsset(level.level) != null
                  ? RdMasteryIcon(
                      level.level,
                      semanticLabel: widget.masteryLabel?.call(level.level - 7),
                    )
                  : Text(
                      'Lv.${level.level}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _fontSize,
                        fontWeight: FontWeight.w600,
                        color: level.level == selected
                            ? RdColors.accentText
                            : RdColors.secondary2,
                      ),
                    ),
            ),
        ],
      ),
    );

    return Column(
      key: const ValueKey('skill-table'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        for (final (index, row) in widget.rows.indexed) ...[
          if (row.kind == SkillRowKind.internal &&
              (index == 0 ||
                  widget.rows[index - 1].kind != SkillRowKind.internal))
            sectionRow(widget.internalLabel),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                firstCell(row.label, header: false, kind: row.kind),
                for (var i = 0; i < row.values.length; i++)
                  dataCell(
                    isSelected:
                        i < levels.length && levels[i].level == selected,
                    selectedFill: RdColors.accentSoft,
                    child: Text(
                      row.values[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _fontSize,
                        color: i < levels.length && levels[i].level == selected
                            ? RdColors.accentText
                            : RdColors.body,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
