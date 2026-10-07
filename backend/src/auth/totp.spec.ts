import { base32Decode, base32Encode, newTotpSecret, otpauthUrl, totpCode, verifyTotp } from './totp';

describe('TOTP (RFC 6238)', () => {
  // Vectorii de test din RFC 6238, anexa B (SHA1, cheia ASCII „12345678901234567890”, 8 cifre).
  const key = Buffer.from('12345678901234567890', 'ascii');
  it.each([
    [59, '94287082'],
    [1111111109, '07081804'],
    [1111111111, '14050471'],
    [1234567890, '89005924'],
    [2000000000, '69279037'],
  ])('la %s s → %s', (seconds, code) => {
    expect(totpCode(key, new Date(seconds * 1000), 8)).toBe(code);
  });

  it('base32 dus-întors; cheile noi au 160 de biți', () => {
    expect(base32Decode(base32Encode(key)).equals(key)).toBe(true);
    expect(base32Encode(key)).toBe('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    expect(base32Decode(newTotpSecret())).toHaveLength(20);
  });

  it('verificarea acceptă pasul vecin, refuză codurile vechi și formatul greșit', () => {
    const secret = base32Encode(key);
    const now = new Date(1111111111 * 1000);
    const code = totpCode(key, now);
    expect(verifyTotp(secret, code, now)).toBe(true);
    expect(verifyTotp(secret, code, new Date(now.getTime() + 30_000))).toBe(true);
    expect(verifyTotp(secret, code, new Date(now.getTime() + 120_000))).toBe(false);
    expect(verifyTotp(secret, '12345', now)).toBe(false);
    expect(verifyTotp(secret, 'abcdef', now)).toBe(false);
  });

  it('legătura otpauth', () => {
    expect(otpauthUrl('ABC', 'dr@clinica.md')).toBe(
      'otpauth://totp/Licurici%3Adr%40clinica.md?secret=ABC&issuer=Licurici&algorithm=SHA1&digits=6&period=30',
    );
  });
});
