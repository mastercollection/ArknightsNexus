/// Builds the pre-normalized region snapshots published on GitHub Pages.
///
/// ```sh
/// dart run tool/build_snapshots.dart --out build/site/data \
///   [--regions kr,en] [--previous-manifest URL] [--fingerprint HASH]
/// ```
///
/// Every snapshot also lists the operators its region has not released yet,
/// taken from EN, then CN (see `src/unreleased_operators.dart`), so EN and
/// CN are read even when `--regions` leaves them out.
///
/// `--previous-manifest` points at the currently published `manifest.json`.
/// A region whose upstream `VersionControl`, schema and unreleased operator
/// sources' `VersionControl`s are unchanged is then copied from the
/// published site (after checking its SHA-256) instead of being
/// regenerated, but only when `--fingerprint` equals the previous
/// manifest's fingerprint, i.e. the generator inputs did not change. When a
/// region fails to generate, its previous copy is kept; without one the tool
/// exits with code 1 so the workflow does not deploy a site missing it.
///
/// Pure Dart: it must not import Flutter (see `lib/services/region_source.dart`).
library;

import 'dart:io';

import 'package:arknight_nexus/core/http/package_http_client.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';

import 'src/snapshot_builder.dart';

Future<void> main(List<String> arguments) async {
  final Map<String, String> options;
  try {
    options = _parse(arguments);
  } on FormatException catch (error) {
    stderr
      ..writeln(error.message)
      ..writeln(_usage);
    exitCode = 64;
    return;
  }

  final out = options['out'];
  if (out == null) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }
  final regions = options['regions'] == null
      ? RegionCode.values
      : [
          for (final value in options['regions']!.split(','))
            if (value.trim().isNotEmpty) RegionCode.parse(value),
        ];
  final previous = options['previous-manifest'];

  final httpClient = PackageHttpClient();
  final stopwatch = Stopwatch()..start();
  try {
    final result = await SnapshotBuilder(
      httpClient: httpClient,
      outDir: Directory(out),
      fingerprint: options['fingerprint'],
    ).build(
      regions: regions,
      previousManifestUri: previous == null ? null : Uri.parse(previous),
    );
    stdout.writeln(
      'Wrote ${result.manifest.regions.length} region(s) to $out in '
      '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
    );
    if (result.hasFailures) {
      stderr.writeln('Some regions failed without a previous copy.');
      exitCode = 1;
    }
  } finally {
    httpClient.close();
  }
}

const _usage = 'Usage: dart run tool/build_snapshots.dart --out DIR '
    '[--regions kr,en,...] [--previous-manifest URL] [--fingerprint HASH]';

const _known = {'out', 'regions', 'previous-manifest', 'fingerprint'};

Map<String, String> _parse(List<String> arguments) {
  final options = <String, String>{};
  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    if (!argument.startsWith('--')) {
      throw FormatException('Unexpected argument: $argument');
    }
    final body = argument.substring(2);
    final equals = body.indexOf('=');
    final String name;
    final String value;
    if (equals >= 0) {
      name = body.substring(0, equals);
      value = body.substring(equals + 1);
    } else {
      if (i + 1 >= arguments.length) {
        throw FormatException('Missing value for --$body');
      }
      name = body;
      value = arguments[++i];
    }
    if (!_known.contains(name)) {
      throw FormatException('Unknown option: --$name');
    }
    options[name] = value;
  }
  return options;
}
