import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  final logger = container.read(appLoggerProvider);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logger.severe(
      '[flutter-error] ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.severe('[platform-error] $error', error, stack);
    return false;
  };

  logger.info('[app] started');

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ArknightNexusApp(),
    ),
  );
}
