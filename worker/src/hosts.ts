// Which hosts the Worker may call. The SDK and ak-conf hosts are fixed in
// servers.ts; the gs/u8/hv URLs come from network_config and must be on one
// of these domains.

const allowedSuffixes = [
  '.arknights.kr',
  '.arknights.global',
  '.arknights.jp',
  '.yo-star.com',
];

/**
 * [url] as a base URL without a trailing slash, or undefined unless it is
 * an https URL on an allowed domain (any port, no credentials).
 */
export function allowedGameUrl(url: unknown): string | undefined {
  if (typeof url !== 'string') {
    return undefined;
  }
  let parsed: URL;
  try {
    // The hv entry is a template; `{0}` is the platform.
    parsed = new URL(url.replaceAll('{0}', 'Android'));
  } catch {
    return undefined;
  }
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password) {
    return undefined;
  }
  const host = parsed.hostname.toLowerCase();
  if (!allowedSuffixes.some((suffix) => host.endsWith(suffix))) {
    return undefined;
  }
  return parsed.href.replace(/\/+$/, '');
}
