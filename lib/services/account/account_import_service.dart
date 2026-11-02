import '../../data_sources/region_code.dart';
import '../user_data_service.dart';
import 'account_source.dart';
import 'account_sync_parser.dart';
import 'yostar_account_client.dart';

/// Signs in to a game account (email code) and copies it into the user data.
///
/// One instance per login attempt: [sendCode] and [importAccount] must use
/// the same device ids, so keep it between the two steps and [close] it
/// afterwards.
class AccountImportService {
  AccountImportService(
    this.server,
    this._userData, {
    AccountSource? source,
    DateTime Function()? now,
  })  : _source = source ?? AccountSource.forServer(server),
        _now = now ?? DateTime.now;

  final YostarServer server;
  final UserDataService _userData;
  final AccountSource _source;
  final DateTime Function() _now;

  /// Region codes whose accounts can be imported (the Yostar servers).
  static List<RegionCode> get regions =>
      [for (final server in YostarServer.values) server.region];

  Future<void> sendCode(String email) => _source.sendCode(email.trim());

  /// Opens a game session (ending the in-game one), reads the account and
  /// saves it.
  Future<AccountImportResult> importAccount(String email, String code) async {
    final data = await _source.fetchSyncData(email.trim(), code.trim());
    final sync = parseAccountSync(
      data,
      region: server.region.value,
      syncedAt: _now(),
    );
    final applied = await _userData.saveAccount(sync.profile, sync.itemCounts);
    return AccountImportResult(
      operators: sync.profile.operators.length,
      itemKinds: applied.itemKinds,
      updatedPlans: applied.updatedPlans,
    );
  }

  void close() => _source.close();
}

class AccountImportResult {
  const AccountImportResult({
    required this.operators,
    required this.itemKinds,
    required this.updatedPlans,
  });

  final int operators;
  final int itemKinds;
  final int updatedPlans;
}
