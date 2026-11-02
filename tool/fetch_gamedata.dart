/// Downloads the upstream tables and level files the full-data tests read
/// (`test/full_data/`) into `build/gamedata`.
///
/// ```sh
/// dart run tool/fetch_gamedata.dart [--regions kr,en] [--out build/gamedata]
/// ```
///
/// A shallow, sparse clone of the upstream repository: only the listed
/// files of each region are downloaded (about 300 MB per region). Running it
/// again updates the checkout to the latest upstream commit.
library;

import 'dart:io';

import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/data_sources/source_descriptor.dart';

/// The default output directory, also where the full-data tests look.
const defaultOut = 'build/gamedata';

const _excelFiles = [
  'stage_table.json',
  'zone_table.json',
  'enemy_handbook_table.json',
];

Future<void> main(List<String> arguments) async {
  var regions = RegionCode.values;
  var out = defaultOut;
  for (var i = 0; i < arguments.length; i++) {
    final value = i + 1 < arguments.length ? arguments[i + 1] : null;
    switch (arguments[i]) {
      case '--regions' when value != null:
        regions = value.split(',').map(RegionCode.parse).toList();
        i++;
      case '--out' when value != null:
        out = value;
        i++;
      default:
        stderr.writeln(
          'Usage: dart run tool/fetch_gamedata.dart '
          '[--regions kr,en] [--out $defaultOut]',
        );
        exitCode = 64;
        return;
    }
  }

  final patterns = [
    for (final region in regions) ...[
      for (final file in _excelFiles) '/${region.value}/gamedata/excel/$file',
      '/${region.value}/gamedata/levels/',
    ],
  ];

  final dir = Directory(out);
  if (!Directory('$out/.git').existsSync()) {
    dir.createSync(recursive: true);
    await _git(
      [
        'clone',
        '--depth',
        '1',
        '--filter=blob:none',
        '--no-checkout',
        '--branch',
        SourceDescriptor.defaultBranch,
        '${SourceDescriptor.repository}.git',
        '.',
      ],
      out,
    );
  } else {
    await _git(
      ['fetch', '--depth', '1', 'origin', SourceDescriptor.defaultBranch],
      out,
    );
  }
  await _git(['sparse-checkout', 'set', '--no-cone', ...patterns], out);
  await _git(
    ['checkout', '--force', 'origin/${SourceDescriptor.defaultBranch}'],
    out,
  );
  stdout.writeln(
    'Fetched ${regions.map((region) => region.value).join(', ')} into $out',
  );
}

Future<void> _git(List<String> arguments, String workingDirectory) async {
  stdout.writeln('git ${arguments.join(' ')}');
  final process = await Process.start(
    'git',
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) {
    stderr.writeln('git exited with code $code');
    exit(code);
  }
}
