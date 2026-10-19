import { describe, expect, it } from 'vitest';

import { md5Hex } from '../src/md5';
import { servers } from '../src/servers';
import { encodeQueryComponent, sdkAuthorization, u8Sign } from '../src/signing';

// Expected values come from YostarAccountClient in the Dart app, with the
// inputs of test/services/account/account_import_test.dart.
describe('sdkAuthorization', () => {
  it('matches the Dart client for KR', () => {
    expect(
      sdkAuthorization(servers.kr, 'device', '{"Account":"a@b.c"}', 1760000000000),
    ).toBe(
      '{"Head":{"PID":"KR-ARKNIGHTS","Channel":"googleplay","Platform":"android",' +
        '"Version":"4.10.0","GVersionNo":"2000112","GBuildNo":"","Lang":"ko",' +
        '"DeviceID":"device","DeviceModel":"F9","UID":"","Token":"",' +
        '"Time":1760000000},"Sign":"875E487EA2BB3F1B1C2BB0E6A7D3FCF4"}',
    );
  });

  it('matches the Dart client for EN with non-ASCII input', () => {
    const header = JSON.parse(
      sdkAuthorization(
        servers.en,
        'device',
        '{"Account":"한@b.c","Randstr":"","Ticket":""}',
        1760000000999,
      ),
    );
    expect(header.Head.PID).toBe('US-ARKNIGHTS');
    expect(header.Head.Time).toBe(1760000000);
    expect(header.Sign).toBe('39D1F167ADB9B00DD43F0B6D84C9CAB9');
  });
});

describe('md5Hex', () => {
  it('hashes the RFC 1321 test suite', () => {
    expect(md5Hex('')).toBe('d41d8cd98f00b204e9800998ecf8427e');
    expect(md5Hex('abc')).toBe('900150983cd24fb0d6963f7d28e17f72');
    expect(md5Hex('message digest')).toBe('f96b697d7cb7938d525a2f31aaf161d0');
    expect(md5Hex('1234567890'.repeat(8))).toBe('57edf4a22be3c955ac49da2e2107b67a');
  });
});

describe('u8Sign', () => {
  it('matches the Dart client over the sorted form encoding', async () => {
    expect(await u8Sign({ b: 2, a: 'x y' })).toBe(
      '30cc744c34fc09afd8c3c3fb8be59fe9bcb4d3ef',
    );
  });

  it('encodes like Uri.encodeQueryComponent', async () => {
    expect(encodeQueryComponent("a b*~!'()é-._")).toBe(
      'a+b%2A~%21%27%28%29%C3%A9-._',
    );
    expect(
      await u8Sign({
        appId: '1',
        platform: 1,
        extension: '{"type":1,"uid":"42","token":"t*k~n(é)"}',
        deviceId: 'd!',
      }),
    ).toBe('e3092cdd24155c207b2debf5144b93b3fc1c858f');
  });
});
