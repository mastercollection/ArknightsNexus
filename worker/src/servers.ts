// Per-server constants, ported from `YostarServer` in
// lib/services/account/yostar_account_client.dart. Keep the two in step.

export interface YostarServer {
  sdkHost: string;
  configHost: string;
  pid: string;
  lang: string;
}

export const servers: Record<string, YostarServer> = {
  kr: {
    // There is no kr-sdk-api host; the KR client signs in through JP's.
    sdkHost: 'https://jp-sdk-api.yostarplat.com',
    configHost: 'https://ak-conf.arknights.kr',
    pid: 'KR-ARKNIGHTS',
    lang: 'ko',
  },
  en: {
    sdkHost: 'https://en-sdk-api.yostarplat.com',
    configHost: 'https://ak-conf.arknights.global',
    pid: 'US-ARKNIGHTS',
    lang: 'en',
  },
  jp: {
    sdkHost: 'https://jp-sdk-api.yostarplat.com',
    configHost: 'https://ak-conf.arknights.jp',
    pid: 'JP-AK',
    lang: 'jp',
  },
};

export function serverOf(name: unknown): YostarServer | undefined {
  return typeof name === 'string' && Object.hasOwn(servers, name)
    ? servers[name]
    : undefined;
}

export const sdkSignKey = '886c085e4a8d30a703367b120dd8353948405ec2';
export const u8SignKey = '91240f70c09a08a6bc72af1a5c8d4670';

export const gameHeaders: Record<string, string> = {
  'content-type': 'application/json',
  'x-unity-version': '2017.4.39f1',
  'user-agent':
    'Dalvik/2.1.0 (Linux; U; Android 11; KB2000 Build/RP1A.201005.001)',
};
