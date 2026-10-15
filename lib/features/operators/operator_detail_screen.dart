import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/redesign/rd_widgets.dart';
import 'operator_detail_view.dart';
import 'operators_list_controller.dart';
import 'operators_workspace.dart';

export 'operator_detail_view.dart' show DetailSection, showOperatorTermSheet;

/// `/operators/:operatorId` (port of `src/pages/operators/[operatorId].vue`,
/// redesigned).
///
/// Expanded width: the PC master-detail [OperatorsWorkspace] with this
/// operator selected. Narrower: the full detail page with section tabs.
class OperatorDetailScreen extends ConsumerWidget {
  const OperatorDetailScreen({
    required this.operatorId,
    super.key,
  });

  static const routeName = 'operator-detail';

  final String operatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (context.rdLayout == RdLayout.expanded) {
      // Keeps the shared list state alive while the workspace is shown.
      ref.watch(operatorsListControllerProvider.select((_) => 0));
      return OperatorsWorkspace(selectedId: operatorId);
    }
    return Material(
      color: RdColors.bg,
      child: OperatorDetailView(
        operatorId: operatorId,
        mode: OperatorDetailMode.page,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/operators');
          }
        },
      ),
    );
  }
}
