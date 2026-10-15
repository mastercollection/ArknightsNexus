import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/building_formula.dart';
import '../../domain/item.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/plan_cost_service.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'plan_widgets.dart';

/// Port of `components/PlanMaterialsGrid.vue` in the redesign look.
///
/// Materials are grouped by tier (descending, `기타` last); LMD is hidden
/// because it has its own resource card. The first tier header carries the
/// "expand crafting formulas" toggle when workshop formulas exist. Shortage
/// is `required - owned` from the item inventory.
///
/// PC: column tiles in [columns] fixed tracks, or auto-fill tracks of at
/// least 124px. Phones: two columns of row tiles.
class PlanMaterialsGrid extends ConsumerWidget {
  const PlanMaterialsGrid({
    required this.materials,
    required this.emptyLabel,
    this.formulas,
    this.itemsById = const {},
    this.excludeItemIds = const {lmdItemId},
    this.columns,
    this.expanded = false,
    this.showShortage = false,
    this.onToggleExpand,
    super.key,
  });

  final List<PlanMaterialTotal> materials;
  final String emptyLabel;
  final BuildingFormulaBundle? formulas;
  final Map<String, ItemEntry> itemsById;
  final Set<String> excludeItemIds;

  /// Fixed PC column count; `null` = auto-fill (min 124px).
  final int? columns;
  final bool expanded;
  final bool showShortage;
  final VoidCallback? onToggleExpand;

  static int tierOf(String? rarity) {
    final matched = RegExp(r'\d+').firstMatch(rarity ?? '');
    return matched == null ? 0 : int.parse(matched.group(0)!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final costService = ref.watch(planCostServiceProvider);
    final compact = context.rdLayout == RdLayout.compact;
    final bundle = formulas;
    final canExpandRecipes = bundle?.workshopFormulas.isNotEmpty ?? false;
    final displayed = expanded && bundle != null
        ? costService.expandPlanMaterials(materials, bundle, itemsById)
        : materials;
    final filtered = displayed
        .where((material) => !excludeItemIds.contains(material.id))
        .toList(growable: false);

    final grouped = <int, List<PlanMaterialTotal>>{};
    for (final material in filtered) {
      grouped.putIfAbsent(tierOf(material.rarity), () => []).add(material);
    }
    final tiers = grouped.keys.toList()..sort((a, b) => b - a);

    if (tiers.isEmpty) {
      return Text(
        emptyLabel,
        style: const TextStyle(fontSize: 13, color: RdColors.secondary2),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < tiers.length; index++) ...[
          if (index > 0) SizedBox(height: compact ? 12 : 16),
          Column(
            key: ValueKey(
              '${expanded ? 'expanded' : 'collapsed'}:${tiers[index]}',
            ),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: compact ? 44 : 32),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tiers[index] > 0
                            ? 'T${tiers[index]}'
                            : i18n.t('planPage.summary.miscTier'),
                        style: planMono(13, color: RdColors.stateTitle),
                      ),
                    ),
                    if (canExpandRecipes && index == 0)
                      _ExpandToggle(
                        label: expanded
                            ? i18n.t('planPage.summary.showOriginalMaterials')
                            : i18n.t('planPage.summary.expandRecipes'),
                        value: expanded,
                        height: compact ? 44 : 36,
                        onTap: onToggleExpand,
                      ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              RdAutoGrid(
                columns: compact ? 2 : columns,
                minTileWidth: compact || columns != null ? null : 124,
                gap: compact ? 8 : (columns == null ? 10 : 8),
                children: [
                  for (final material in grouped[tiers[index]]!)
                    _MaterialTile(
                      material: material,
                      tier: tiers[index],
                      compact: compact,
                      shortage: showShortage
                          ? planShortage(
                              material.count,
                              itemsById[material.id]?.ownedCount,
                            )
                          : 0,
                      i18n: i18n,
                    ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Label + switch button that toggles the recipe expansion.
class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({
    required this.label,
    required this.value,
    required this.height,
    required this.onTap,
  });

  final String label;
  final bool value;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(RdRadii.small),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: RdColors.stateTitle,
                  ),
                ),
                const SizedBox(width: 10),
                PlanRecipeSwitch(value: value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 38x20 switch drawn next to the expand label (visual only; the
/// surrounding button handles the tap).
class PlanRecipeSwitch extends StatelessWidget {
  const PlanRecipeSwitch({required this.value, super.key});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 38,
      height: 20,
      decoration: BoxDecoration(
        color: value ? const Color(0xE62890FF) : RdColors.white8,
        borderRadius: BorderRadius.circular(RdRadii.pill),
        border: Border.all(color: const Color(0x4D7A90B8)),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            left: value ? 19 : 2,
            top: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x47000000),
                    offset: Offset(0, 1),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({
    required this.material,
    required this.tier,
    required this.compact,
    required this.shortage,
    required this.i18n,
  });

  final PlanMaterialTotal material;
  final int tier;
  final bool compact;
  final double shortage;
  final NexusI18n i18n;

  @override
  Widget build(BuildContext context) {
    final icon = PlanItemIconLink(
      itemId: material.id,
      iconId: material.iconId,
      name: material.name,
      semanticLabel: i18n.t('rd.plan.itemDetail', {'name': material.name}),
      size: compact ? 44 : 48,
      tint: PlanColors.tierTint(tier),
      onTap: () => context.push('/items/${material.id}'),
    );
    final required = i18n.t('planPage.summary.requiredCount', {
      'count': formatPlanNumber(material.count),
    });
    final shortageLabel = shortage > 0
        ? i18n.t('planPage.summary.shortageOnly', {
            'shortage': formatPlanNumber(shortage),
          })
        : null;
    final name = Text(
      material.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: compact ? TextAlign.start : TextAlign.center,
      style: TextStyle(
        fontSize: compact ? 12 : 13,
        fontWeight: FontWeight.w700,
        color: RdColors.text,
      ),
    );

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: RdColors.card,
          borderRadius: BorderRadius.circular(RdRadii.inner),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  name,
                  const SizedBox(height: 2),
                  Text(
                    required,
                    style: const TextStyle(
                      fontSize: 11,
                      color: RdColors.secondary2,
                    ),
                  ),
                  if (shortageLabel != null)
                    Text(
                      shortageLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: PlanColors.shortage,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RdInset(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, child: name),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: required,
              children: [
                if (shortageLabel != null) ...[
                  const TextSpan(
                    text: ' / ',
                    style: TextStyle(color: PlanColors.faint),
                  ),
                  TextSpan(
                    text: shortageLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: PlanColors.shortage,
                    ),
                  ),
                ],
              ],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: RdColors.secondary2),
          ),
        ],
      ),
    );
  }
}
