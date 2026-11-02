// CORS for the origins in ALLOWED_ORIGINS. An entry ending in `:*` allows
// any port of that origin (`http://localhost:*`).

export function isAllowedOrigin(
  origin: string | null,
  allowedOrigins: string | undefined,
): origin is string {
  if (!origin || !allowedOrigins) {
    return false;
  }
  return allowedOrigins
    .split(',')
    .map((entry) => entry.trim().replace(/\/+$/, ''))
    .filter((entry) => entry.length > 0)
    .some((entry) => {
      if (entry.endsWith(':*')) {
        const base = entry.slice(0, -2);
        return (
          origin === base ||
          (origin.startsWith(base) &&
            /^:\d{1,5}$/.test(origin.slice(base.length)))
        );
      }
      return origin === entry;
    });
}

export function corsHeaders(origin: string): Record<string, string> {
  return {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'POST, OPTIONS',
    'access-control-allow-headers': 'content-type',
    'access-control-max-age': '86400',
    vary: 'Origin',
  };
}
