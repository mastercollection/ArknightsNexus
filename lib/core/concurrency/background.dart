import 'dart:async';

import 'background_web.dart' if (dart.library.io) 'background_io.dart' as impl;

/// Runs [computation] off the UI isolate where the platform has isolates
/// (`Isolate.run` on native builds). The web build has none, so there it
/// runs on the event loop after yielding once, which lets a pending frame
/// (for example a sync progress line) paint first.
///
/// [computation] should be a top-level function or a closure that captures
/// only its inputs, since on native builds it is sent to another isolate.
Future<R> runInBackground<R>(FutureOr<R> Function() computation) =>
    impl.runInBackground(computation);
