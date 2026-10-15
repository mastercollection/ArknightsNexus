import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'logging_navigator_observer.dart';
import 'providers.dart';
import 'shell.dart';
import '../ui/redesign/rd_tokens.dart';
import '../features/home/home_screen.dart';
import '../features/items/item_detail_screen.dart';
import '../features/items/items_screen.dart';
import '../features/operators/operator_detail_screen.dart';
import '../features/operators/operators_screen.dart';
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
GoRouter createRouter({List<NavigatorObserver> Function()? observers}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    observers: observers?.call(),
    routes: [
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        observers: observers?.call(),
        builder: (context, state, child) =>
            NexusShell(location: state.uri.toString(), child: child),
        routes: [
          GoRoute(
            path: '/',
            name: HomeScreen.routeName,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/operators',
            name: OperatorsScreen.routeName,
            pageBuilder: (context, state) => _operatorsPage(
              context,
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
              state,
              OperatorDetailScreen(
                operatorId: state.pathParameters['operatorId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/items',
            name: ItemsScreen.routeName,
            builder: (context, state) => const ItemsScreen(),
          ),
          GoRoute(
            path: '/items/:itemId',
            name: ItemDetailScreen.routeName,
            builder: (context, state) => ItemDetailScreen(
              itemId: state.pathParameters['itemId']!,
            ),
          ),
          GoRoute(
            path: '/plan',
            name: PlanScreen.routeName,
            builder: (context, state) => const PlanScreen(),
          ),
          GoRoute(
            path: '/plan/:operatorId',
            name: OperatorPlanScreen.routeName,
            builder: (context, state) => OperatorPlanScreen(
              operatorId: state.pathParameters['operatorId']!,
            ),
          ),
          GoRoute(
            path: '/settings',
            name: SettingsScreen.routeName,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}

/// At expanded width `/operators` and `/operators/:id` both render the same
/// master-detail workspace, so switching between them must not animate the
/// whole page; narrower layouts keep the normal push transition.
Page<void> _operatorsPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  if (context.rdLayout == RdLayout.expanded) {
    return NoTransitionPage<void>(key: state.pageKey, child: child);
  }
  return MaterialPage<void>(key: state.pageKey, child: child);
}
