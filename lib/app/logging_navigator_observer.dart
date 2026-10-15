import 'package:flutter/widgets.dart';

import '../core/logging/app_logger.dart';

/// Logs route changes for diagnostics.
class LoggingNavigatorObserver extends NavigatorObserver {
  LoggingNavigatorObserver(this._logger);

  final AppLogger _logger;

  void _log(String action, Route<dynamic>? route, Route<dynamic>? previous) {
    final to = route?.settings.name ?? route?.settings.arguments?.toString();
    final from = previous?.settings.name;
    _logger.info('[route] $action to=$to from=$from');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('push', route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('pop', route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _log('replace', newRoute, oldRoute);
  }
}
