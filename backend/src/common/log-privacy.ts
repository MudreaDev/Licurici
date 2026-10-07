/**
 * Ce intră în jurnalul cererilor (README §13.4, politica de retenție): fără antete (token,
 * cookie, user-agent), fără parametri din URL, fără corp; IP-ul doar trunchiat.
 */

/** IPv4 → ultimul octet 0 (1.2.3.4 → 1.2.3.0); IPv6 → primele 3 grupuri (/48). */
export function truncateIp(ip: string | undefined): string | undefined {
  if (!ip) return undefined;
  const v4 = ip.replace(/^::ffff:/, '');
  if (/^\d{1,3}(\.\d{1,3}){3}$/.test(v4)) return v4.replace(/\.\d{1,3}$/, '.0');
  if (ip.includes(':')) {
    const head = ip.split('::')[0].split(':').filter(Boolean).slice(0, 3);
    return `${head.join(':')}::`;
  }
  return undefined;
}

export const logSerializers = {
  req: (req: { id?: unknown; method?: string; url?: string; remoteAddress?: string }) => ({
    id: req.id,
    method: req.method,
    url: req.url?.split('?')[0],
    ip: truncateIp(req.remoteAddress),
  }),
  res: (res: { statusCode?: number }) => ({ statusCode: res.statusCode }),
};
