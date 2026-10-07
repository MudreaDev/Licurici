import { createHmac, randomBytes } from 'node:crypto';

/**
 * Autentificarea în doi pași cu coduri TOTP (RFC 6238: HMAC-SHA1, pas de 30 s, 6 cifre) —
 * compatibilă cu orice aplicație de autentificare (Google Authenticator, Microsoft Authenticator,
 * Aegis…). Fără pachete externe: doar `node:crypto`.
 */

const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export function base32Encode(bytes: Buffer): string {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const b of bytes) {
    value = (value << 8) | b;
    bits += 8;
    while (bits >= 5) {
      out += ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += ALPHABET[(value << (5 - bits)) & 31];
  return out;
}

export function base32Decode(text: string): Buffer {
  const clean = text.replace(/[\s=-]/g, '').toUpperCase();
  let bits = 0;
  let value = 0;
  const out: number[] = [];
  for (const ch of clean) {
    const i = ALPHABET.indexOf(ch);
    if (i < 0) throw new Error('cheie base32 invalidă');
    value = (value << 5) | i;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}

/** O cheie nouă: 20 de octeți aleatori (160 de biți, cât recomandă RFC 4226), în base32. */
export function newTotpSecret(): string {
  return base32Encode(randomBytes(20));
}

/** Codul pentru momentul [at] (implicit 6 cifre). */
export function totpCode(secret: Buffer, at: Date, digits = 6, stepSeconds = 30): string {
  const counter = Math.floor(at.getTime() / 1000 / stepSeconds);
  const msg = Buffer.alloc(8);
  msg.writeBigUInt64BE(BigInt(counter));
  const h = createHmac('sha1', secret).update(msg).digest();
  const offset = h[h.length - 1] & 0xf;
  const bin = ((h[offset] & 0x7f) << 24) | (h[offset + 1] << 16) | (h[offset + 2] << 8) | h[offset + 3];
  return String(bin % 10 ** digits).padStart(digits, '0');
}

/** Verifică un cod, acceptând și pasul dinainte și cel de după (ceasuri ușor decalate). */
export function verifyTotp(secretBase32: string, code: string, now: Date): boolean {
  if (!/^\d{6}$/.test(code)) return false;
  const secret = base32Decode(secretBase32);
  for (const drift of [0, -1, 1]) {
    if (totpCode(secret, new Date(now.getTime() + drift * 30_000)) === code) return true;
  }
  return false;
}

/** Legătura pe care o înțeleg aplicațiile de autentificare (de introdus și ca text). */
export function otpauthUrl(secretBase32: string, account: string): string {
  const label = encodeURIComponent(`Licurici:${account}`);
  return `otpauth://totp/${label}?secret=${secretBase32}&issuer=Licurici&algorithm=SHA1&digits=6&period=30`;
}
