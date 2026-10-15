import 'dart:async';
import 'dart:isolate';

Future<R> runInBackground<R>(FutureOr<R> Function() computation) =>
    Isolate.run(computation);
