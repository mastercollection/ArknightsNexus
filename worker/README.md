# Account proxy Worker

A Cloudflare Worker that runs the Yostar (KR/EN/JP) account login for the
web build of ArknightsNexus. The game servers send no CORS headers, so a
browser cannot call them; the Windows and Android apps still call them
directly and never use this Worker.

The Worker does the whole login itself rather than forwarding single calls:

| Endpoint | Body | Does |
| --- | --- | --- |
| `POST /send-code` | `{server, email}` | `yostar/send-code` (mails the code) |
| `POST /import` | `{server, email, code}` | `yostar/get-auth`, `user/login`, `network_config`, the version file, u8 `user/v1/getToken`, gs `account/login`, then streams the raw gs `account/syncData` body back |

`server` is `kr`, `en` or `jp`. The app also sends an optional `deviceId`
(32 hex digits) with both calls so the login keeps one device id, as the
game client does; without it the Worker picks a random one. Failures answer
`{error, step, code}` with an HTTP status: 400 for a bad request, 403 for an
origin that is not allowed, 422 when a game server refused (`code` is its
result code, for example a wrong mail code at `get-auth`) and 502 when a
game server could not be reached or answered something unexpected.

The protocol is a port of `lib/services/account/yostar_account_client.dart`;
change both together. `npm test` checks the signing against the Dart
client's values.

## Security

- Only fixed hosts are called: the Yostar SDK and `ak-conf` hosts are in
  `src/servers.ts`. The gs, u8 and version URLs from `network_config` are
  used only when they are `https` on `*.arknights.kr`, `*.arknights.global`,
  `*.arknights.jp` or `*.yo-star.com`, and redirects are not followed.
- Only the origins in `ALLOWED_ORIGINS` get an answer.
- Nothing is stored, and nothing is logged: no bodies, emails, codes or
  tokens. Workers Logs are turned off in `wrangler.toml`.
- The syncData body is passed through without being parsed (the free plan
  allows 10 ms of CPU per request; time spent waiting on fetch is free).

## Deploy

Needs Node.js 20 or later and a Cloudflare account.

```sh
cd worker
npm i
npm test
npx wrangler login
npx wrangler deploy
```

`wrangler deploy` prints the Worker's URL, such as
`https://arknights-nexus-account-proxy.<account>.workers.dev`.

`ALLOWED_ORIGINS` is set in `wrangler.toml`: comma-separated origins, where
an entry ending in `:*` allows any port (`http://localhost:*` covers
`flutter run -d chrome`). For a fork, change it to your GitHub Pages origin
(`https://<owner>.github.io`, no path) before deploying, or override it in
the Cloudflare dashboard (Worker → Settings → Variables).

Then turn the import on in the web build:

- **GitHub Pages:** set the repository variable `NEXUS_ACCOUNT_PROXY_URL`
  (Settings → Secrets and variables → Actions → Variables) to the Worker's
  URL and rerun the Pages workflow. Without the variable the web build
  shows its "not supported" notice.
- **Locally:** `flutter run -d chrome --dart-define=NEXUS_ACCOUNT_PROXY_URL=https://...workers.dev`.

`npm run dev` serves the Worker on `http://localhost:8787` for testing.

## Cost

The free plan allows 100,000 requests per day. One import is 2 requests
(the app sends `text/plain` bodies, so the browser sends no CORS
preflight), so about 50,000 imports per day are free. The 7 game server
calls of an import are subrequests, well under the free plan's 50 per
request, and do not count as requests. Over the daily limit the Worker
answers with errors until the next day (UTC); nothing is billed. The Paid
plan is $5 per month for 10 million requests.

## Shared IP risk

Every web import reaches the game servers from Cloudflare's addresses
instead of the player's own. If Yostar rate-limits or blocks those
addresses, the web import stops working for everyone until the block
lifts; the native apps are not affected. There is no workaround in the
Worker: use the Windows or Android app in that case.
