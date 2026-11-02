// Runs the Yostar account login for the web build of ArknightsNexus, whose
// browser cannot call the game servers (they send no CORS headers).
//
// POST /send-code {server, email[, deviceId]} mails a login code.
// POST /import {server, email, code[, deviceId]} signs in and streams the
// raw `account/syncData` body back unchanged. It is never parsed here: the
// free plan allows 10 ms of CPU per request, and waiting on fetch is free.
//
// The app sends `text/plain` bodies so the browser skips the CORS preflight
// and an import costs two requests. Failures are `{error, step, code}`.

import { corsHeaders, isAllowedOrigin } from './cors';
import { importAccount, sendCode, StepError, type Fetcher } from './flow';
import { serverOf, type YostarServer } from './servers';
import { randomDeviceIds, type DeviceIds } from './signing';

export interface Env {
  ALLOWED_ORIGINS?: string;
}

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return handle(request, env, (input, init) => fetch(input, init));
  },
};

export async function handle(
  request: Request,
  env: Env,
  fetcher: Fetcher,
): Promise<Response> {
  const origin = request.headers.get('origin');
  if (!isAllowedOrigin(origin, env.ALLOWED_ORIGINS)) {
    return json({ error: 'origin not allowed', step: 'request', code: null }, 403, {});
  }
  const cors = corsHeaders(origin);
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors });
  }
  const path = new URL(request.url).pathname;
  if (path !== '/send-code' && path !== '/import') {
    return json({ error: 'not found', step: 'request', code: null }, 404, cors);
  }
  if (request.method !== 'POST') {
    return json({ error: 'method not allowed', step: 'request', code: null }, 405, cors);
  }

  try {
    const input = await readInput(request, path === '/import');
    if (path === '/send-code') {
      await sendCode(fetcher, input.server, input.ids, input.email);
      return json({ ok: true }, 200, cors);
    }
    const upstream = await importAccount(
      fetcher,
      input.server,
      input.ids,
      input.email,
      input.code,
    );
    return new Response(upstream.body, {
      status: 200,
      headers: {
        ...cors,
        'content-type': 'application/json',
        'cache-control': 'no-store',
      },
    });
  } catch (error) {
    if (error instanceof StepError) {
      return json(
        { error: error.message, step: error.step, code: error.code },
        error.status,
        cors,
      );
    }
    // Only the error's type: its message could quote a request.
    console.error('unexpected error', error instanceof Error ? error.name : typeof error);
    return json({ error: 'internal error', step: 'proxy', code: null }, 500, cors);
  }
}

interface Input {
  server: YostarServer;
  ids: DeviceIds;
  email: string;
  code: string;
}

async function readInput(request: Request, needsCode: boolean): Promise<Input> {
  const invalid = (message: string) => new StepError('request', message, 400);
  const text = await request.text();
  if (text.length > 1024) {
    throw invalid('body too large');
  }
  let body: Record<string, unknown>;
  try {
    const parsed: unknown = JSON.parse(text);
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      throw new Error();
    }
    body = parsed as Record<string, unknown>;
  } catch {
    throw invalid('body is not a JSON object');
  }

  const server = serverOf(body.server);
  if (!server) {
    throw invalid('unknown server');
  }
  const email = typeof body.email === 'string' ? body.email.trim() : '';
  if (!/^[^\s@]+@[^\s@]+$/.test(email) || email.length > 254) {
    throw invalid('invalid email');
  }
  const code = typeof body.code === 'string' ? body.code.trim() : '';
  if (needsCode && !/^[0-9A-Za-z]{1,16}$/.test(code)) {
    throw invalid('invalid code');
  }
  // The app keeps one device id from send-code to import, as the game
  // client does; anything else gets a random one.
  const deviceId =
    typeof body.deviceId === 'string' && /^[0-9a-f]{32}$/.test(body.deviceId)
      ? body.deviceId
      : undefined;
  return { server, ids: randomDeviceIds(deviceId), email, code };
}

function json(
  body: unknown,
  status: number,
  headers: Record<string, string>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...headers,
      'content-type': 'application/json',
      'cache-control': 'no-store',
    },
  });
}
