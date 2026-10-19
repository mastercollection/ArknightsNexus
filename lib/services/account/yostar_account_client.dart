/// Logs in to a Yostar (KR/EN/JP) Arknights account with an email code and
/// reads the account's `syncData` from the game server.
///
/// The flow follows the game client (as documented by ArkPRTS):
///
/// 1. `yostar/send-code` mails a code, `yostar/get-auth` trades it for an
///    email token and `user/login` for the Yostar uid/token (SDK host).
/// 2. `user/v1/getToken` on u8 trades those for the game uid/token.
/// 3. `account/login` on gs opens a game session (`secret`); every later gs
///    call sends `uid`, `secret` and an increasing `seqnum`.
///
/// Opening a session ends the account's in-game session, since the game
/// allows one per account.
///
/// Pure Dart: `tool/account_probe.dart` runs it outside Flutter.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../core/errors/app_failure.dart';
import '../../data_sources/region_code.dart';

/// A Yostar server and the constants its client sends.
enum YostarServer {
  kr(
    region: RegionCode.kr,
    // There is no kr-sdk-api host; the KR client signs in through JP's.
    sdkHost: 'https://jp-sdk-api.yostarplat.com',
    configHost: 'https://ak-conf.arknights.kr',
    pid: 'KR-ARKNIGHTS',
    lang: 'ko',
  ),
  en(
    region: RegionCode.en,
    sdkHost: 'https://en-sdk-api.yostarplat.com',
    configHost: 'https://ak-conf.arknights.global',
    pid: 'US-ARKNIGHTS',
    lang: 'en',
  ),
  jp(
    region: RegionCode.jp,
    sdkHost: 'https://jp-sdk-api.yostarplat.com',
    configHost: 'https://ak-conf.arknights.jp',
    pid: 'JP-AK',
    lang: 'jp',
  );

  const YostarServer({
    required this.region,
    required this.sdkHost,
    required this.configHost,
    required this.pid,
    required this.lang,
  });

  final RegionCode region;
  final String sdkHost;
  final String configHost;
  final String pid;
  final String lang;

  /// The Yostar server of [region], or null for CN/TW (other publishers).
  static YostarServer? ofRegion(RegionCode region) {
    for (final server in values) {
      if (server.region == region) {
        return server;
      }
    }
    return null;
  }
}

/// Device ids sent with every login; one random set per client.
class YostarDeviceIds {
  const YostarDeviceIds(this.deviceId, this.deviceId2, this.deviceId3);

  factory YostarDeviceIds.random([Random? random]) {
    final rng = random ?? Random.secure();
    String hex(int length) => List.generate(
          length,
          (_) => rng.nextInt(16).toRadixString(16),
        ).join();
    final imei = '86${List.generate(13, (_) => rng.nextInt(10)).join()}';
    return YostarDeviceIds(hex(32), imei, hex(32));
  }

  final String deviceId;
  final String deviceId2;
  final String deviceId3;
}

class YostarAccountClient {
  YostarAccountClient(
    this.server, {
    http.Client? client,
    YostarDeviceIds? deviceIds,
    DateTime Function()? now,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        deviceIds = deviceIds ?? YostarDeviceIds.random(),
        _now = now ?? DateTime.now;

  static const _sdkSignKey = '886c085e4a8d30a703367b120dd8353948405ec2';
  static const _u8SignKey = '91240f70c09a08a6bc72af1a5c8d4670';

  static const gameHeaders = {
    'content-type': 'application/json',
    'x-unity-version': '2017.4.39f1',
    'user-agent':
        'Dalvik/2.1.0 (Linux; U; Android 11; KB2000 Build/RP1A.201005.001)',
  };

  final YostarServer server;
  final YostarDeviceIds deviceIds;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _now;

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// Mails a login code to [email].
  Future<void> sendCode(String email) async {
    await _sdkPost('yostar/send-code', {
      'Account': email,
      'Randstr': '',
      'Ticket': '',
    });
  }

  /// Signs in with the mailed [code] and opens a game session.
  Future<YostarGameSession> login(String email, String code) async {
    final auth = await _sdkPost('yostar/get-auth', {
      'Account': email,
      'Code': code,
    });
    final emailToken = _string(auth, 'Token', 'yostar/get-auth');

    final user = await _sdkPost('user/login', {
      'CheckAccount': 0,
      'Geetest': {
        'CaptchaID': null,
        'CaptchaOutput': null,
        'GenTime': null,
        'LotNumber': null,
        'PassToken': null,
      },
      'OpenID': email,
      'Secret': '',
      'Token': emailToken,
      'Type': 'yostar',
      'UserName': email,
    });
    final userInfo = _map(user['UserInfo'], 'user/login UserInfo');
    final yostarUid = '${userInfo['ID']}';
    final yostarToken = _string(userInfo, 'Token', 'user/login');

    final network = await loadNetwork();
    final version = await loadVersion(network);
    final u8 = await _u8Token(network, yostarUid, yostarToken);

    final session = YostarGameSession._(
      this,
      gsHost: network['gs']!,
      uid: u8.uid,
    );
    await session._login(u8.token, version);
    return session;
  }

  /// The server's network map (`gs`, `u8`, `hv`, ...).
  Future<Map<String, String>> loadNetwork() async {
    final uri =
        Uri.parse('${server.configHost}/config/prod/official/network_config');
    final body = await _getJson(uri);
    final content = jsonDecode(_string(body, 'content', 'network_config'));
    final configs = _map(content['configs'], 'network_config configs');
    final current = _map(configs[content['funcVer']], 'network_config funcVer');
    final network = _map(current['network'], 'network_config network');
    return {
      for (final entry in network.entries)
        if (entry.value is String) entry.key: entry.value as String,
    };
  }

  /// The current `resVersion` and `clientVersion` of the Android client.
  Future<({String resVersion, String clientVersion})> loadVersion(
    Map<String, String> network,
  ) async {
    final template = network['hv'];
    if (template == null) {
      throw const AccountFailure('network_config has no version URL');
    }
    final body =
        await _getJson(Uri.parse(template.replaceAll('{0}', 'Android')));
    return (
      resVersion: _string(body, 'resVersion', 'version'),
      clientVersion: _string(body, 'clientVersion', 'version'),
    );
  }

  Future<({String uid, String token})> _u8Token(
    Map<String, String> network,
    String yostarUid,
    String yostarToken,
  ) async {
    final u8 = network['u8'];
    if (u8 == null) {
      throw const AccountFailure('network_config has no u8 host');
    }
    final body = <String, Object?>{
      'appId': '1',
      'platform': 1,
      'channelId': '3',
      'subChannel': '3',
      'worldId': '3',
      'extension': jsonEncode({
        'type': 1,
        'uid': yostarUid,
        'token': yostarToken,
      }),
      'deviceId': deviceIds.deviceId,
      'deviceId2': deviceIds.deviceId2,
      'deviceId3': deviceIds.deviceId3,
    };
    body['sign'] = u8Sign(body);
    final data = await _gamePost(
      Uri.parse('$u8/user/v1/getToken'),
      body,
      const {},
    );
    _checkResult(data, 'user/v1/getToken');
    return (
      uid: '${data['uid']}',
      token: _string(data, 'token', 'user/v1/getToken'),
    );
  }

  /// HMAC-SHA1 of the key-sorted, form-encoded [body] (`sign` of u8 calls).
  static String u8Sign(Map<String, Object?> body) {
    final keys = body.keys.toList()..sort();
    final query = keys
        .map(
          (key) => '${Uri.encodeQueryComponent(key)}='
              '${Uri.encodeQueryComponent('${body[key]}')}',
        )
        .join('&');
    return Hmac(sha1, utf8.encode(_u8SignKey))
        .convert(utf8.encode(query))
        .toString();
  }

  /// The `Authorization` header of an SDK call with [body].
  String sdkAuthorization(String body) {
    final head = {
      'PID': server.pid,
      'Channel': 'googleplay',
      'Platform': 'android',
      'Version': '4.10.0',
      'GVersionNo': '2000112',
      'GBuildNo': '',
      'Lang': server.lang,
      'DeviceID': deviceIds.deviceId,
      'DeviceModel': 'F9',
      'UID': '',
      'Token': '',
      'Time': _now().millisecondsSinceEpoch ~/ 1000,
    };
    final headJson = jsonEncode(head);
    final sign = md5
        .convert(utf8.encode('$headJson$body$_sdkSignKey'))
        .toString()
        .toUpperCase();
    return jsonEncode({'Head': head, 'Sign': sign});
  }

  Future<Map<String, Object?>> _sdkPost(
    String path,
    Map<String, Object?> body,
  ) async {
    final encoded = jsonEncode(body);
    final uri = Uri.parse('${server.sdkHost}/$path');
    final response = await _send(
      () => _client.post(
        uri,
        headers: {
          'authorization': sdkAuthorization(encoded),
          'content-type': 'application/json',
        },
        body: encoded,
      ),
      'POST $path',
    );
    final data = _decode(response, path);
    if (data['Code'] != 200) {
      throw AccountFailure(
        '$path failed: ${data['Msg'] ?? data['Code']}',
        code: data['Code'],
      );
    }
    return _map(data['Data'] ?? const {}, '$path Data');
  }

  Future<Map<String, Object?>> _gamePost(
    Uri uri,
    Map<String, Object?> body,
    Map<String, String> headers,
  ) async {
    final response = await _send(
      () => _client.post(
        uri,
        headers: {...gameHeaders, ...headers},
        body: jsonEncode(body),
      ),
      'POST ${uri.path}',
    );
    return _decode(response, uri.path);
  }

  Future<Map<String, Object?>> _getJson(Uri uri) async {
    final response = await _send(
      () => _client.get(uri, headers: gameHeaders),
      'GET $uri',
    );
    return _decode(response, uri.path);
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request,
    String label,
  ) async {
    try {
      return await request();
    } catch (error) {
      throw NetworkFailure('$label failed: $error');
    }
  }

  static Map<String, Object?> _decode(http.Response response, String label) {
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw NetworkFailure('$label failed with HTTP ${response.statusCode}');
    }
    if (data is! Map<String, Object?>) {
      throw NetworkFailure('$label returned no JSON object');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountFailure(
        '$label failed with HTTP ${response.statusCode}: '
        '${data['error'] ?? data['msg'] ?? data['message'] ?? ''}',
        code: data['statusCode'] ?? response.statusCode,
      );
    }
    return data;
  }
}

/// An open game session; [syncData] reads the whole account.
class YostarGameSession {
  YostarGameSession._(this._owner, {required this.gsHost, required this.uid});

  final YostarAccountClient _owner;
  final String gsHost;
  final String uid;
  String _secret = '';
  int _seqnum = 1;

  Future<void> _login(
    String u8Token,
    ({String resVersion, String clientVersion}) version,
  ) async {
    final ids = _owner.deviceIds;
    final data = await _owner._gamePost(
      Uri.parse('$gsHost/account/login'),
      {
        'platform': 1,
        'networkVersion': '1',
        'assetsVersion': version.resVersion,
        'clientVersion': version.clientVersion,
        'token': u8Token,
        'uid': uid,
        'deviceId': ids.deviceId,
        'deviceId2': ids.deviceId2,
        'deviceId3': ids.deviceId3,
      },
      {'secret': '', 'seqnum': '1', 'uid': uid},
    );
    _checkResult(data, 'account/login');
    _secret = _string(data, 'secret', 'account/login');
  }

  /// The raw `syncData` response; the account is under `user`.
  Future<Map<String, Object?>> syncData() =>
      post('account/syncData', {'platform': 1});

  Future<Map<String, Object?>> post(
    String path,
    Map<String, Object?> body,
  ) {
    _seqnum += 1;
    return _owner._gamePost(
      Uri.parse('$gsHost/$path'),
      body,
      {'secret': _secret, 'seqnum': '$_seqnum', 'uid': uid},
    );
  }
}

void _checkResult(Map<String, Object?> data, String label) {
  final result = data['result'];
  if (result != null && result != 0) {
    throw AccountFailure('$label failed with result $result', code: result);
  }
}

Map<String, Object?> _map(Object? value, String label) {
  if (value is Map<String, Object?>) {
    return value;
  }
  throw ParseFailure('$label is not an object');
}

String _string(Map<String, Object?> data, String key, String label) {
  final value = data[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw ParseFailure('$label has no $key');
}
