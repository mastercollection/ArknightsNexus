import 'dart:io';

import 'package:flutter/foundation.dart';

/// Steps of [writeFileAtomically], reported to [AtomicWriteHooks.onStep] so
/// tests can simulate a crash between any two of them.
enum AtomicWriteStep {
  /// The temp file holds the complete new content (flushed).
  tempWritten,

  /// Fallback path only: the previous target was moved to its `.prev` file.
  previousMovedAside,

  /// The new content is in place under the target name.
  replaced,
}

/// Test seams for [writeFileAtomically].
@visibleForTesting
class AtomicWriteHooks {
  const AtomicWriteHooks({this.onStep, this.rename});

  /// Called after each [AtomicWriteStep]; throwing simulates a crash there.
  final Future<void> Function(AtomicWriteStep step)? onStep;

  /// Replaces [File.rename], e.g. to simulate a locked target.
  final Future<File> Function(File source, String newPath)? rename;
}

int _tempCounter = 0;

/// Where the fallback path parks the previous content while it swaps files.
File previousFileFor(File target) => File('${target.path}.prev');

/// Replaces [target] with [contents] so that a crash at any point leaves
/// either the old or the new content readable.
///
/// The content goes to a uniquely named temp file (so concurrent writers
/// never share one), is flushed, and is then renamed over the target. That
/// rename replaces an existing file on every supported platform (on Windows
/// Dart uses `MoveFileEx` with `MOVEFILE_REPLACE_EXISTING`), but it fails
/// while another handle has the target open, so it is retried briefly. If it
/// keeps failing, the old file is moved to [previousFileFor] first and only
/// removed once the new file is in place; [recoverAtomicFile] restores it if
/// the process dies in between.
///
/// Writes to the same path from this process run one after another, since
/// two renames racing onto one target fail on Windows.
Future<void> writeFileAtomically(
  File target,
  String contents, {
  @visibleForTesting AtomicWriteHooks hooks = const AtomicWriteHooks(),
}) {
  final key = File(target.path).absolute.path;
  final previous = _pendingWrites[key];
  final write = previous == null
      ? _writeFileAtomically(target, contents, hooks)
      : previous.then((_) => _writeFileAtomically(target, contents, hooks));
  final settled = write.then<void>((_) {}, onError: (Object _) {});
  _pendingWrites[key] = settled;
  settled.whenComplete(() {
    if (identical(_pendingWrites[key], settled)) {
      _pendingWrites.remove(key);
    }
  });
  return write;
}

/// Last queued write per absolute path.
final _pendingWrites = <String, Future<void>>{};

Future<void> _writeFileAtomically(
  File target,
  String contents,
  AtomicWriteHooks hooks,
) async {
  Future<File> rename(File source, String newPath) =>
      hooks.rename?.call(source, newPath) ?? source.rename(newPath);
  Future<void> step(AtomicWriteStep value) async => hooks.onStep?.call(value);

  await target.parent.create(recursive: true);
  final temp = File(
    '${target.path}.${pid}_${DateTime.now().microsecondsSinceEpoch}_'
    '${_tempCounter++}.tmp',
  );
  try {
    await temp.writeAsString(contents, flush: true);
    await step(AtomicWriteStep.tempWritten);

    Object? lastError;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await rename(temp, target.path);
        await step(AtomicWriteStep.replaced);
        return;
      } on FileSystemException catch (error) {
        lastError = error;
        await Future<void>.delayed(Duration(milliseconds: 20 << attempt));
      }
    }

    if (!await target.exists()) {
      throw lastError!;
    }
    final previous = previousFileFor(target);
    await rename(target, previous.path);
    await step(AtomicWriteStep.previousMovedAside);
    try {
      await rename(temp, target.path);
    } catch (_) {
      await rename(previous, target.path);
      rethrow;
    }
    await step(AtomicWriteStep.replaced);
    await previous.delete();
  } finally {
    if (await temp.exists()) {
      try {
        await temp.delete();
      } on FileSystemException {
        // A leftover temp file is harmless; the target is what matters.
      }
    }
  }
}

/// Restores [target] from the `.prev` file a crashed fallback write left
/// behind. Returns whether [target] exists afterwards.
Future<bool> recoverAtomicFile(File target) async {
  if (await target.exists()) {
    return true;
  }
  final previous = previousFileFor(target);
  if (!await previous.exists()) {
    return false;
  }
  try {
    await previous.rename(target.path);
  } on FileSystemException {
    // Another reader restored it first.
  }
  return target.exists();
}
