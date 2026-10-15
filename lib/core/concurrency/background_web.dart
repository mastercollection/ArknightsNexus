import 'dart:async';

Future<R> runInBackground<R>(FutureOr<R> Function() computation) async {
  await Future<void>.delayed(Duration.zero);
  return computation();
}
