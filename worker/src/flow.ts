// The Yostar login, ported from `YostarAccountClient.login` and
// `YostarGameSession`. Each failure names its step so the app can show
// where the login stopped. Nothing here logs bodies, emails, codes or tokens.

import { allowedGameUrl } from './hosts';
import { gameHeaders, type YostarServer } from './servers';
import { sdkAuthorization, u8Sign, type DeviceIds } from './signing';

export type Fetcher = (input: string, init?: RequestInit) => Promise<Response>;

/** A failed step, sent to the app as `{error, step, code}`. */
export class StepError extends Error {
  constructor(
    readonly step: string,
    message: string,
    readonly status: number,
    readonly code: unknown = null,
  ) {
    super(message);
  }
}

type Json = Record<string, unknown>;

/** Mails a login code to [email]. */
export async function sendCode(
  fetcher: Fetcher,
  server: YostarServer,
  ids: DeviceIds,
  email: string,
): Promise<void> {
  await sdkPost(fetcher, server, ids, 'send-code', 'yostar/send-code', {
    Account: email,
    Randstr: '',
    Ticket: '',
  });
}

/**
 * Signs in with the mailed [code], opens a game session and returns the
 * upstream `account/syncData` response, body unread.
 */
export async function importAccount(
  fetcher: Fetcher,
  server: YostarServer,
  ids: DeviceIds,
  email: string,
  code: string,
): Promise<Response> {
  const auth = await sdkPost(fetcher, server, ids, 'get-auth', 'yostar/get-auth', {
    Account: email,
    Code: code,
  });
  const emailToken = string(auth, 'Token', 'get-auth');

  const user = await sdkPost(fetcher, server, ids, 'user-login', 'user/login', {
    CheckAccount: 0,
    Geetest: {
      CaptchaID: null,
      CaptchaOutput: null,
      GenTime: null,
      LotNumber: null,
      PassToken: null,
    },
    OpenID: email,
    Secret: '',
    Token: emailToken,
    Type: 'yostar',
    UserName: email,
  });
  const userInfo = object(user.UserInfo, 'user-login');
  const yostarUid = `${userInfo.ID}`;
  const yostarToken = string(userInfo, 'Token', 'user-login');

  const network = await loadNetwork(fetcher, server);
  const version = await getJson(fetcher, 'version', network.hv);
  const resVersion = string(version, 'resVersion', 'version');
  const clientVersion = string(version, 'clientVersion', 'version');

  const u8Body: Json = {
    appId: '1',
    platform: 1,
    channelId: '3',
    subChannel: '3',
    worldId: '3',
    extension: JSON.stringify({ type: 1, uid: yostarUid, token: yostarToken }),
    deviceId: ids.deviceId,
    deviceId2: ids.deviceId2,
    deviceId3: ids.deviceId3,
  };
  u8Body.sign = await u8Sign(u8Body);
  const u8 = await gamePost(fetcher, 'u8-token', `${network.u8}/user/v1/getToken`, u8Body, {});
  const uid = `${u8.uid}`;
  const u8Token = string(u8, 'token', 'u8-token');

  const login = await gamePost(
    fetcher,
    'game-login',
    `${network.gs}/account/login`,
    {
      platform: 1,
      networkVersion: '1',
      assetsVersion: resVersion,
      clientVersion,
      token: u8Token,
      uid,
      deviceId: ids.deviceId,
      deviceId2: ids.deviceId2,
      deviceId3: ids.deviceId3,
    },
    { secret: '', seqnum: '1', uid },
  );
  const secret = string(login, 'secret', 'game-login');

  const response = await send(fetcher, 'sync-data', `${network.gs}/account/syncData`, {
    method: 'POST',
    headers: { ...gameHeaders, secret, seqnum: '2', uid },
    body: JSON.stringify({ platform: 1 }),
  });
  if (!response.ok) {
    // Error bodies are small; only a successful syncData is streamed.
    await decode(response, 'sync-data');
    throw new StepError('sync-data', `HTTP ${response.status}`, 502, response.status);
  }
  return response;
}

/** The gs, u8 and hv URLs of [server]'s network_config, each allowlisted. */
async function loadNetwork(
  fetcher: Fetcher,
  server: YostarServer,
): Promise<{ gs: string; u8: string; hv: string }> {
  const step = 'network-config';
  const body = await getJson(
    fetcher,
    step,
    `${server.configHost}/config/prod/official/network_config`,
  );
  let content: Json;
  try {
    content = object(JSON.parse(string(body, 'content', step)), step);
  } catch (error) {
    if (error instanceof StepError) throw error;
    throw new StepError(step, 'content is not JSON', 502);
  }
  const configs = object(content.configs, step);
  const current = object(configs[`${content.funcVer}`], step);
  const network = object(current.network, step);
  const url = (key: string) => {
    const allowed = allowedGameUrl(network[key]);
    if (!allowed) {
      throw new StepError(step, `${key} is missing or not an allowed host`, 502);
    }
    return allowed;
  };
  return { gs: url('gs'), u8: url('u8'), hv: url('hv') };
}

async function sdkPost(
  fetcher: Fetcher,
  server: YostarServer,
  ids: DeviceIds,
  step: string,
  path: string,
  body: Json,
): Promise<Json> {
  const encoded = JSON.stringify(body);
  const response = await send(fetcher, step, `${server.sdkHost}/${path}`, {
    method: 'POST',
    headers: {
      authorization: sdkAuthorization(server, ids.deviceId, encoded),
      'content-type': 'application/json',
    },
    body: encoded,
  });
  const data = await decode(response, step);
  if (data.Code !== 200) {
    throw new StepError(step, `${data.Msg ?? data.Code}`, 422, data.Code ?? null);
  }
  return object(data.Data ?? {}, step);
}

async function gamePost(
  fetcher: Fetcher,
  step: string,
  url: string,
  body: Json,
  headers: Record<string, string>,
): Promise<Json> {
  const response = await send(fetcher, step, url, {
    method: 'POST',
    headers: { ...gameHeaders, ...headers },
    body: JSON.stringify(body),
  });
  const data = await decode(response, step);
  const result = data.result;
  if (result != null && result !== 0) {
    throw new StepError(step, `result ${result}`, 422, result);
  }
  return data;
}

async function getJson(fetcher: Fetcher, step: string, url: string): Promise<Json> {
  return decode(await send(fetcher, step, url, { headers: gameHeaders }), step);
}

async function send(
  fetcher: Fetcher,
  step: string,
  url: string,
  init: RequestInit,
): Promise<Response> {
  try {
    // A redirect could leave the allowed hosts, so none is followed.
    return await fetcher(url, { ...init, redirect: 'manual' });
  } catch {
    throw new StepError(step, 'network error', 502);
  }
}

async function decode(response: Response, step: string): Promise<Json> {
  let data: unknown;
  try {
    data = await response.json();
  } catch {
    throw new StepError(step, `HTTP ${response.status}`, 502, response.status);
  }
  if (typeof data !== 'object' || data === null || Array.isArray(data)) {
    throw new StepError(step, 'no JSON object', 502, response.status);
  }
  const json = data as Json;
  if (response.status < 200 || response.status >= 300) {
    const message = json.error ?? json.msg ?? json.message ?? '';
    throw new StepError(
      step,
      `HTTP ${response.status}: ${message}`,
      502,
      json.statusCode ?? response.status,
    );
  }
  return json;
}

function object(value: unknown, step: string): Json {
  if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
    return value as Json;
  }
  throw new StepError(step, 'unexpected response', 502);
}

function string(data: Json, key: string, step: string): string {
  const value = data[key];
  if (typeof value === 'string' && value.length > 0) {
    return value;
  }
  throw new StepError(step, `no ${key}`, 502);
}
