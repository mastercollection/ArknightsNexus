import { describe, expect, it } from 'vitest';

import { isAllowedOrigin } from '../src/cors';
import { handle } from '../src/index';

const allowed = 'https://mastercollection.github.io, http://localhost:*';

describe('isAllowedOrigin', () => {
  it('allows listed origins and any localhost port', () => {
    expect(isAllowedOrigin('https://mastercollection.github.io', allowed)).toBe(true);
    expect(isAllowedOrigin('http://localhost:53124', allowed)).toBe(true);
    expect(isAllowedOrigin('http://localhost', allowed)).toBe(true);
  });

  it('rejects everything else', () => {
    for (const origin of [
      null,
      '',
      'https://evil.github.io',
      'https://mastercollection.github.io.evil.com',
      'http://mastercollection.github.io',
      'http://localhost.evil.com',
      'http://localhost:80/x',
      'https://localhost:8080',
    ]) {
      expect(isAllowedOrigin(origin, allowed), String(origin)).toBe(false);
    }
    expect(isAllowedOrigin('https://mastercollection.github.io', undefined)).toBe(false);
  });
});

describe('handle', () => {
  const env = { ALLOWED_ORIGINS: allowed };
  const noFetch = () => Promise.reject(new Error('no fetch expected'));

  it('rejects a foreign origin without CORS headers or upstream calls', async () => {
    const response = await handle(
      new Request('https://proxy.test/send-code', {
        method: 'POST',
        headers: { origin: 'https://evil.example' },
        body: '{}',
      }),
      env,
      noFetch,
    );
    expect(response.status).toBe(403);
    expect(response.headers.get('access-control-allow-origin')).toBeNull();
  });

  it('answers a preflight from an allowed origin', async () => {
    const response = await handle(
      new Request('https://proxy.test/import', {
        method: 'OPTIONS',
        headers: { origin: 'http://localhost:5000' },
      }),
      env,
      noFetch,
    );
    expect(response.status).toBe(204);
    expect(response.headers.get('access-control-allow-origin')).toBe(
      'http://localhost:5000',
    );
    expect(response.headers.get('vary')).toBe('Origin');
  });

  it('validates the body before calling upstream', async () => {
    const post = (path: string, body: unknown) =>
      handle(
        new Request(`https://proxy.test${path}`, {
          method: 'POST',
          headers: { origin: 'https://mastercollection.github.io' },
          body: JSON.stringify(body),
        }),
        env,
        noFetch,
      );
    const unknownServer = await post('/send-code', { server: 'cn', email: 'a@b.c' });
    expect(unknownServer.status).toBe(400);
    expect(await unknownServer.json()).toEqual({
      error: 'unknown server',
      step: 'request',
      code: null,
    });
    expect((await post('/import', { server: 'kr', email: 'a@b.c' })).status).toBe(400);
    expect((await post('/send-code', { server: 'kr', email: 'nope' })).status).toBe(400);
    expect((await post('/other', {})).status).toBe(404);
  });
});
