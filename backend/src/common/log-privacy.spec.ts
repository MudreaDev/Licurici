import { logSerializers, truncateIp } from './log-privacy';

describe('jurnalul cererilor fără date personale', () => {
  it('IP-ul se trunchiază', () => {
    expect(truncateIp('203.0.113.77')).toBe('203.0.113.0');
    expect(truncateIp('::ffff:198.51.100.9')).toBe('198.51.100.0');
    expect(truncateIp('2001:db8:85a3:8d3:1319:8a2e:370:7348')).toBe('2001:db8:85a3::');
    expect(truncateIp('2001:db8::1')).toBe('2001:db8::');
    expect(truncateIp(undefined)).toBeUndefined();
  });

  it('cererea: fără antete, fără parametri din URL', () => {
    const out = logSerializers.req({
      id: 7,
      method: 'GET',
      url: '/api/v1/children?token=secret',
      remoteAddress: '203.0.113.77',
      ...{ headers: { authorization: 'Bearer x', 'user-agent': 'y' } },
    } as never);
    expect(out).toEqual({ id: 7, method: 'GET', url: '/api/v1/children', ip: '203.0.113.0' });
    expect(JSON.stringify(out)).not.toContain('Bearer');
  });
});
