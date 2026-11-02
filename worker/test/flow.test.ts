import { describe, expect, it } from 'vitest';

import { handle } from '../src/index';

const origin = 'https://mastercollection.github.io';
const env = { ALLOWED_ORIGINS: origin };
const syncBody = '{"result":0,"user":{"status":{"nickName":"Doctor"}}}';

function network(overrides: Record<string, string> = {}) {
  return {
    content: JSON.stringify({
      funcVer: 'V001',
      configs: {
        V001: {
          network: {
            gs: 'https://gs.arknights.kr:8443',
            u8: 'https://passport.arknights.kr',
            hv: 'https://ark-kr-static-online.yo-star.com/assetbundle/official/{0}/version',
            ...overrides,
          },
        },
      },
    }),
  };
}

/** A fake game backend; records each call's URL and headers. */
function fakeBackend(networkJson = network(), sdkCode = 200) {
  const calls: { url: string; headers: Headers; body: string }[] = [];
  const fetcher = async (url: string, init?: RequestInit) => {
    const headers = new Headers(init?.headers);
    calls.push({ url, headers, body: `${init?.body ?? ''}` });
    const reply = (body: unknown) => new Response(JSON.stringify(body));
    const path = new URL(url).pathname;
    switch (path) {
      case '/yostar/send-code':
        return reply({ Code: sdkCode, Msg: 'bad', Data: {} });
      case '/yostar/get-auth':
        return reply({ Code: sdkCode, Msg: 'bad code', Data: { Token: 'email-token' } });
      case '/user/login':
        return reply({ Code: 200, Data: { UserInfo: { ID: 42, Token: 'yostar-token' } } });
      case '/config/prod/official/network_config':
        return reply(networkJson);
      case '/assetbundle/official/Android/version':
        return reply({ resVersion: 'res', clientVersion: 'client' });
      case '/user/v1/getToken':
        return reply({ result: 0, uid: 7, token: 'u8-token' });
      case '/account/login':
        return reply({ result: 0, secret: 'secret' });
      case '/account/syncData':
        return new Response(syncBody);
    }
    throw new Error(`unexpected ${url}`);
  };
  return { calls, fetcher };
}

function post(path: string, body: unknown, fetcher: Parameters<typeof handle>[2]) {
  return handle(
    new Request(`https://proxy.test${path}`, {
      method: 'POST',
      headers: { origin, 'content-type': 'text/plain;charset=utf-8' },
      body: JSON.stringify(body),
    }),
    env,
    fetcher,
  );
}

const deviceId = '0123456789abcdef0123456789abcdef';

describe('import', () => {
  it('runs the login and streams syncData unchanged', async () => {
    const { calls, fetcher } = fakeBackend();
    const response = await post(
      '/import',
      { server: 'kr', email: 'a@b.c', code: '123456', deviceId },
      fetcher,
    );
    expect(response.status).toBe(200);
    expect(response.headers.get('access-control-allow-origin')).toBe(origin);
    expect(await response.text()).toBe(syncBody);

    expect(calls.map((call) => call.url)).toEqual([
      'https://jp-sdk-api.yostarplat.com/yostar/get-auth',
      'https://jp-sdk-api.yostarplat.com/user/login',
      'https://ak-conf.arknights.kr/config/prod/official/network_config',
      'https://ark-kr-static-online.yo-star.com/assetbundle/official/Android/version',
      'https://passport.arknights.kr/user/v1/getToken',
      'https://gs.arknights.kr:8443/account/login',
      'https://gs.arknights.kr:8443/account/syncData',
    ]);
    const auth = JSON.parse(calls[0].headers.get('authorization')!);
    expect(auth.Head.DeviceID).toBe(deviceId);
    const u8 = JSON.parse(calls[4].body);
    expect(u8.deviceId).toBe(deviceId);
    expect(u8.sign).toMatch(/^[0-9a-f]{40}$/);
    expect(JSON.parse(u8.extension)).toEqual({ type: 1, uid: '42', token: 'yostar-token' });
    const sync = calls[6].headers;
    expect(sync.get('secret')).toBe('secret');
    expect(sync.get('seqnum')).toBe('2');
    expect(sync.get('uid')).toBe('7');
    expect(sync.get('x-unity-version')).toBe('2017.4.39f1');
    expect(sync.get('user-agent')).toMatch(/^Dalvik\//);
  });

  it('refuses network_config hosts outside the allowlist', async () => {
    const { calls, fetcher } = fakeBackend(network({ gs: 'https://evil.example' }));
    const response = await post(
      '/import',
      { server: 'kr', email: 'a@b.c', code: '123456' },
      fetcher,
    );
    expect(response.status).toBe(502);
    expect(await response.json()).toMatchObject({ step: 'network-config' });
    expect(calls.some((call) => call.url.includes('evil'))).toBe(false);
  });

  it('names the failed step with the SDK code', async () => {
    const { fetcher } = fakeBackend(network(), 100403);
    const response = await post(
      '/import',
      { server: 'en', email: 'a@b.c', code: '000000' },
      fetcher,
    );
    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({
      error: 'bad code',
      step: 'get-auth',
      code: 100403,
    });
  });
});

describe('send-code', () => {
  it('calls the SDK host of the server', async () => {
    const { calls, fetcher } = fakeBackend();
    const response = await post('/send-code', { server: 'en', email: 'a@b.c' }, fetcher);
    expect(response.status).toBe(200);
    expect(calls.map((call) => call.url)).toEqual([
      'https://en-sdk-api.yostarplat.com/yostar/send-code',
    ]);
    expect(JSON.parse(calls[0].body)).toEqual({ Account: 'a@b.c', Randstr: '', Ticket: '' });
  });
});
