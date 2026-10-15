import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/operator.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/nexus_media.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'plan_widgets.dart';

/// Lets the plan page refresh or close the open picker.
class PlanPickerController {
  PlanPickerController(this.context, this.refresh);

  final BuildContext context;
  final VoidCallback refresh;
}

/// Opens the operator picker: a centred dialog on PC/tablet, a bottom sheet
/// on phones. Completes when it closes.
Future<void> showPlanOperatorPicker({
  required BuildContext context,
  required ValueChanged<PlanPickerController> onAttach,
  required String Function() query,
  required ValueChanged<String> onQueryChanged,
  required List<OperatorSummary> Function() operators,
  required Future<void> Function(String operatorId) onAdd,
}) {
  final size = MediaQuery.sizeOf(context);
  PlanOperatorPicker panel(bool compact) => PlanOperatorPicker(
        compact: compact,
        onAttach: onAttach,
        query: query,
        onQueryChanged: onQueryChanged,
        operators: operators,
        onAdd: onAdd,
      );

  if (context.rdLayout == RdLayout.compact) {
    final height = math.min(600.0, size.height * 0.88);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: RdColors.sheet,
      barrierColor: const Color(0x80000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      constraints: BoxConstraints(
        minHeight: height,
        maxHeight: height,
        maxWidth: double.infinity,
      ),
      builder: (_) => panel(true),
    );
  }

  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x8C000000),
    builder: (dialogContext) {
      final maxHeight = math.min(640.0, size.height - 72 - 24);
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 72, 16, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 640, maxHeight: maxHeight),
            child: Material(
              color: RdColors.sheet,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: Color(0x14FFFFFF)),
              ),
              clipBehavior: Clip.antiAlias,
              child: panel(false),
            ),
          ),
        ),
      );
    },
  );
}

/// Picker body: eyebrow + title + close, search, and the addable operators.
/// Tapping a row adds the operator and keeps the picker open (the row then
/// leaves the list), as in the Vue drawer.
class PlanOperatorPicker extends ConsumerStatefulWidget {
  const PlanOperatorPicker({
    required this.compact,
    required this.onAttach,
    required this.query,
    required this.onQueryChanged,
    required this.operators,
    required this.onAdd,
    super.key,
  });

  final bool compact;
  final ValueChanged<PlanPickerController> onAttach;
  final String Function() query;
  final ValueChanged<String> onQueryChanged;
  final List<OperatorSummary> Function() operators;
  final Future<void> Function(String operatorId) onAdd;

  @override
  ConsumerState<PlanOperatorPicker> createState() => _PlanOperatorPickerState();
}

class _PlanOperatorPickerState extends ConsumerState<PlanOperatorPicker> {
  late final _controller = TextEditingController(text: widget.query());

  @override
  void initState() {
    super.initState();
    widget.onAttach(PlanPickerController(context, _refresh));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final operators = widget.operators();
    final compact = widget.compact;
    final closeLabel = i18n.t('rd.plan.close');

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                i18n.t('rd.plan.pickerEyebrow'),
                style: RdText.eyebrow.copyWith(fontSize: compact ? 11 : 12),
              ),
              SizedBox(height: compact ? 2 : 4),
              Semantics(
                header: true,
                child: Text(
                  i18n.t('planPage.picker.title'),
                  style: TextStyle(
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    color: RdColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
        RdIconButton(
          key: const Key('plan-picker-close'),
          icon: Icons.close,
          tooltip: closeLabel,
          filled: false,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );

    final search = RdSearchField(
      controller: _controller,
      hintText: i18n.t('planPage.picker.searchPlaceholder'),
      height: compact ? 44 : 46,
      onChanged: (value) {
        widget.onQueryChanged(value);
        setState(() {});
      },
    );

    final Widget list = operators.isEmpty
        ? PlanEmptyBox(
            title: i18n.t('planPage.picker.emptyTitle'),
            description: i18n.t('planPage.picker.emptyDescription'),
          )
        : ListView.separated(
            shrinkWrap: !compact,
            padding: EdgeInsets.zero,
            itemCount: operators.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final operator = operators[index];
              return _PickerRow(
                operator: operator,
                professionLabel: i18n.profession(operator.profession),
                addLabel: i18n.t('planPage.picker.add'),
                semanticLabel: i18n.t('rd.plan.addNamedToPlan', {
                  'name': operator.name,
                }),
                compact: compact,
                onTap: () async {
                  await widget.onAdd(operator.id);
                  _refresh();
                },
              );
            },
          );

    return SafeArea(
      top: false,
      child: Padding(
        padding: compact
            ? const EdgeInsets.fromLTRB(16, 12, 16, 24)
            : const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact) ...[
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
              const SizedBox(height: 12),
            ],
            header,
            SizedBox(height: compact ? 12 : 14),
            search,
            SizedBox(height: compact ? 12 : 14),
            if (operators.isEmpty)
              list
            else if (compact)
              Expanded(child: list)
            else
              Flexible(child: list),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.operator,
    required this.professionLabel,
    required this.addLabel,
    required this.semanticLabel,
    required this.compact,
    required this.onTap,
  });

  final OperatorSummary operator;
  final String professionLabel;
  final String addLabel;
  final String semanticLabel;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(RdRadii.inner);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: RdColors.sheetOption,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: Color(0x14FFFFFF)),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 60 : 0),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: compact ? 8 : 10,
              ),
              child: Row(
                children: [
                  OperatorPortrait(
                    charId: operator.id,
                    name: operator.name,
                    size: PortraitSize.sm,
                    dimension: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          operator.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: RdColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          professionLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: RdColors.secondary2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: RdColors.chipOnFill,
                      borderRadius: BorderRadius.circular(RdRadii.pill),
                      border: Border.all(color: PlanColors.linkBorder),
                    ),
                    child: Text(
                      addLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PlanColors.linkText,
                      ),
                    ),
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

/// `pickerOperators`: not yet in the plan and matching the query against the
/// name, raw and translated profession, teams, nations and groups.
List<OperatorSummary> filterPlanPickerOperators({
  required List<OperatorSummary> operators,
  required List<String> selectedIds,
  required String query,
  required NexusI18n i18n,
}) {
  final needle = query.trim().toLowerCase();
  return operators.where((operator) {
    if (selectedIds.contains(operator.id)) {
      return false;
    }
    if (needle.isEmpty) {
      return true;
    }
    return [
      operator.name,
      operator.profession,
      i18n.profession(operator.profession),
      ...operator.teams,
      ...operator.nations,
      ...operator.groups,
    ].any((value) => value.toLowerCase().contains(needle));
  }).toList();
}
