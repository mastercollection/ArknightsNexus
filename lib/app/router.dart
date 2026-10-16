import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'logging_navigator_observer.dart';
import 'page_transitions.dart';
import 'providers.dart';
import 'shell.dart';
import '../features/home/home_screen.dart';
import '../features/items/item_detail_screen.dart';
import '../features/items/items_screen.dart';
import '../features/operators/operator_detail_screen.dart';
import '../features/operators/operators_screen.dart';
import '../features/operators/operators_workspace.dart';
import '../features/plan/operator_plan_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/settings/settings_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rootNavigator',
);

/// Navigator of the pages inside [NexusShell]; dialogs and sheets still use
/// [rootNavigatorKey] so they cover the rail / tab bar.
final shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellNavigator',
);

final routerProvider = Provider<GoRouter>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return createRouter(observers: () => [LoggingNavigatorObserver(logger)]);
});

/// [observers] is called once per navigator (root and shell), since an
/// observer can only watch one navigator.
///
/// Rail / sidebar / tab bar switches go through one [SectionSwitchSignal]
/// shared by the shell and the pages, so they appear without a transition;
/// every other navigation uses the platform's push transition.
GoRouter createRouter({List<NavigatorObserver> Function()? observers}) {
  final sectionSwitch = SectionSwitchSignal();
  Page<void> page(
    GoRouterState state,
    Widget child, {
    NexusPageTransition? transition,
  }) =>
      NexusPage<void>(
        key: state.pageKey,
        name: state.name,
        sectionSwitch: sectionSwitch,
        transition: transition,
        child: child,
      );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    observers: observers?.call(),
    routes: [
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        observers: observers?.call(),
        builder: (context, state, child) => NexusShell(
          location: state.uri.toString(),
          sectionSwitch: sectionSwitch,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/',
            name: HomeScreen.routeName,
            pageBuilder: (context, state) => page(
              state,
              const HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/operators',
            name: OperatorsScreen.routeName,
            pageBuilder: (context, state) => _operatorsPage(
              context,
              page,
              state,
              OperatorsScreen(
                initialQuery: state.uri.queryParameters['q'],
              ),
            ),
          ),
          GoRoute(
            path: '/operators/:operatorId',
            name: OperatorDetailScreen.routeName,
            pageBuilder: (context, state) => _operatorsPage(
              context,
              page,
              state,
              OperatorDetailScreen(
                operatorId: state.pathParameters['operatorId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/items',
            name: ItemsScreen.routeName,
            pageBuilder: (context, state) => page(
              state,
              const ItemsScreen(),
            ),
          ),
          GoRoute(
            path: '/items/:itemId',
            name: ItemDetailScreen.routeName,
            pageBuilder: (context, state) => page(
              state,
              ItemDetailScreen(
                itemId: state.pathParameters['itemId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/plan',
            name: PlanScreen.routeName,
            pageBuilder: (context, state) => page(
              state,
              const PlanScreen(),
            ),
          ),
          GoRoute(
            path: '/plan/:operatorId',
            name: OperatorPlanScreen.routeName,
            pageBuilder: (context, state) => page(
              state,
              OperatorPlanScreen(
                operatorId: state.pathParameters['operatorId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/settings',
            name: SettingsScreen.routeName,
            pageBuilder: (context, state) => page(
              state,
              const SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}

/// From [operatorsMasterDetailWidth] `/operators` and `/operators/:id` both
/// render the same master-detail workspace, so switching between them must
/// not animate the whole page; narrower layouts use the push transition like every route.
///
/// Both cases are a [NexusPage], so the routes delegate the same exit
/// transition as their neighbours (a different one would rebuild the page
/// below from scratch on every push) and a window resize keeps the route.
Page<void> _operatorsPage(
  BuildContext context,
  Page<void> Function(
    GoRouterState state,
    Widget child, {
    NexusPageTransition? transition,
  }) page,
  GoRouterState state,
  Widget child,
) {
  return page(
    state,
    child,
    transition:
        operatorsMasterDetail(context) ? NexusPageTransition.none : null,
  );
}
