import 'account_proxy_client.dart';
import 'yostar_account_client.dart';

/// Where [AccountImportService] gets a game account from: the game servers
/// directly (native builds) or the account proxy Worker (`worker/`), for the
/// web build whose browser cannot reach the game servers.
///
/// One instance per login attempt, like [YostarAccountClient].
abstract interface class AccountSource {
  /// The web build uses the proxy when `NEXUS_ACCOUNT_PROXY_URL` is set;
  /// native builds always call the game servers.
  factory AccountSource.forServer(YostarServer server) =>
      _isWeb && AccountProxyClient.configured
          ? AccountProxyClient(server, Uri.parse(AccountProxyClient.baseUrl))
          : DirectAccountSource(YostarAccountClient(server));

  /// Mails a login code to [email].
  Future<void> sendCode(String email);

  /// Signs in with the mailed [code] and returns the raw `syncData`
  /// response (the account is under `user`).
  Future<Map<String, Object?>> fetchSyncData(String email, String code);

  void close();
}

const _isWeb = bool.fromEnvironment('dart.library.js_util');

/// Calls the game servers itself through [YostarAccountClient].
class DirectAccountSource implements AccountSource {
  DirectAccountSource(this.client);

  final YostarAccountClient client;

  @override
  Future<void> sendCode(String email) => client.sendCode(email);

  @override
  Future<Map<String, Object?>> fetchSyncData(String email, String code) async {
    final session = await client.login(email, code);
    return session.syncData();
  }

  @override
  void close() => client.close();
}
