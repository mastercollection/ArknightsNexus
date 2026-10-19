/// Tries the Yostar account login on this machine and saves the account's
/// `syncData` for inspection.
///
/// ```sh
/// dart run tool/account_probe.dart [--server kr|en|jp] [--offline]
/// ```
///
/// Asks for the account email, mails a code, asks for the code, then writes
/// `build/account_probe/<server>-syncData.json` and prints a summary.
/// Signing in ends the account's in-game session. `--offline` only checks
/// the network and version configs, without signing in.
///
/// The email and code are not stored; the saved file holds the account data
/// and stays in the git-ignored `build/` folder.
library;

import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/services/account/yostar_account_client.dart';

Future<void> main(List<String> args) async {
  final serverName = _option(args, '--server') ?? 'kr';
  final server = YostarServer.values.firstWhere(
    (value) => value.name == serverName,
    orElse: () => throw ArgumentError('Unknown server: $serverName'),
  );
  final client = YostarAccountClient(server);
  try {
    final network = await client.loadNetwork();
    final version = await client.loadVersion(network);
    stdout.writeln('gs: ${network['gs']}  u8: ${network['u8']}');
    stdout.writeln(
      'client ${version.clientVersion}, resources ${version.resVersion}',
    );
    if (args.contains('--offline')) {
      return;
    }

    final email = _ask('Yostar account email: ');
    await client.sendCode(email);
    stdout.writeln('Code sent to $email.');
    final code = _ask('Code: ');

    final session = await client.login(email, code);
    stdout.writeln('Signed in as game uid ${session.uid}.');
    final data = await session.syncData();

    final file = File('build/account_probe/${server.name}-syncData.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
    _printSummary(data);
    stdout.writeln('Saved ${file.path}');
  } finally {
    client.close();
  }
}

void _printSummary(Map<String, Object?> data) {
  final user = data['user'];
  if (user is! Map) {
    stdout.writeln('No "user" in syncData; top-level keys: ${data.keys}');
    return;
  }
  final status = user['status'] as Map? ?? const {};
  final chars = (user['troop'] as Map?)?['chars'] as Map? ?? const {};
  final inventory = user['inventory'] as Map? ?? const {};
  stdout.writeln(
    '${status['nickName']}#${status['nickNumber']}  Lv.${status['level']}',
  );
  stdout.writeln('operators: ${chars.length}, inventory items: '
      '${inventory.length}');
  stdout.writeln('user keys: ${user.keys.join(', ')}');
}

String _ask(String prompt) {
  stdout.write(prompt);
  final line = stdin.readLineSync()?.trim() ?? '';
  if (line.isEmpty) {
    stderr.writeln('Nothing entered.');
    exit(64);
  }
  return line;
}

String? _option(List<String> args, String name) {
  final index = args.indexOf(name);
  return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
}
