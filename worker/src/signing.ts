// Request signing, ported from `YostarAccountClient.sdkAuthorization` and
// `YostarAccountClient.u8Sign`.

import { hex, md5Hex } from './md5';
import { sdkSignKey, u8SignKey, type YostarServer } from './servers';

/** Device ids sent with a login; one random set per import. */
export interface DeviceIds {
  deviceId: string;
  deviceId2: string;
  deviceId3: string;
}

export function randomDeviceIds(deviceId?: string): DeviceIds {
  const digits = (length: number, radix: number) =>
    Array.from(crypto.getRandomValues(new Uint8Array(length)), (byte) =>
      (byte % radix).toString(radix),
    ).join('');
  return {
    deviceId: deviceId ?? digits(32, 16),
    deviceId2: `86${digits(13, 10)}`,
    deviceId3: digits(32, 16),
  };
}

/** The `Authorization` header of an SDK call with [body]. */
export function sdkAuthorization(
  server: YostarServer,
  deviceId: string,
  body: string,
  nowMs: number = Date.now(),
): string {
  const head = {
    PID: server.pid,
    Channel: 'googleplay',
    Platform: 'android',
    Version: '4.10.0',
    GVersionNo: '2000112',
    GBuildNo: '',
    Lang: server.lang,
    DeviceID: deviceId,
    DeviceModel: 'F9',
    UID: '',
    Token: '',
    Time: Math.floor(nowMs / 1000),
  };
  const headJson = JSON.stringify(head);
  const sign = md5Hex(`${headJson}${body}${sdkSignKey}`).toUpperCase();
  return JSON.stringify({ Head: head, Sign: sign });
}

/** Dart's `Uri.encodeQueryComponent`: only `A-Za-z0-9-._~` stay as is. */
export function encodeQueryComponent(value: string): string {
  return encodeURIComponent(value)
    .replace(
      /[!'()*]/g,
      (char) => `%${char.charCodeAt(0).toString(16).toUpperCase()}`,
    )
    .replace(/%20/g, '+');
}

/** HMAC-SHA1 of the key-sorted, form-encoded [body] (`sign` of u8 calls). */
export async function u8Sign(body: Record<string, unknown>): Promise<string> {
  const query = Object.keys(body)
    .sort()
    .map(
      (key) =>
        `${encodeQueryComponent(key)}=${encodeQueryComponent(`${body[key]}`)}`,
    )
    .join('&');
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(u8SignKey),
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(query));
  return hex(new Uint8Array(signature));
}
