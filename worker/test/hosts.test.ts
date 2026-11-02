import { describe, expect, it } from 'vitest';

import { allowedGameUrl } from '../src/hosts';

describe('allowedGameUrl', () => {
  it('accepts https URLs on the game domains', () => {
    expect(allowedGameUrl('https://gs.arknights.kr:8443')).toBe(
      'https://gs.arknights.kr:8443',
    );
    expect(allowedGameUrl('https://passport.arknights.global/')).toBe(
      'https://passport.arknights.global',
    );
    expect(allowedGameUrl('https://gs.arknights.jp:8443')).toBe(
      'https://gs.arknights.jp:8443',
    );
    expect(
      allowedGameUrl(
        'https://ark-us-static-online.yo-star.com/assetbundle/official/{0}/version',
      ),
    ).toBe('https://ark-us-static-online.yo-star.com/assetbundle/official/Android/version');
  });

  it('rejects other hosts, schemes and credentials', () => {
    for (const url of [
      'http://gs.arknights.kr',
      'https://arknights.kr.evil.com',
      'https://evilarknights.kr',
      'https://arknights.kr',
      'https://gs.arknights.kr@evil.com',
      'https://user:pass@gs.arknights.kr',
      'https://yo-star.com.evil.com/x',
      'ftp://gs.arknights.jp',
      'not a url',
      42,
      undefined,
    ]) {
      expect(allowedGameUrl(url), String(url)).toBeUndefined();
    }
  });
});
