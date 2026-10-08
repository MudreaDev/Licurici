import { mailLink, renderMail } from './mail';

describe('e-mailurile tranzacționale', () => {
  it('legătura duce în panou, cu tokenul codificat', () => {
    expect(mailLink('https://panou.licurici.ro/', 'verify-email', 'a+b/c')).toBe(
      'https://panou.licurici.ro/#/confirmare?token=a%2Bb%2Fc',
    );
    expect(mailLink('http://localhost:8080', 'reset-password', 'x')).toBe('http://localhost:8080/#/parola-noua?token=x');
  });

  it('textul are legătura; HTML-ul e escapat', () => {
    const m = renderMail('reset-password', 'ana@example.md', 'http://x/#/parola-noua?token=a&b="c"');
    expect(m.to).toBe('ana@example.md');
    expect(m.subject).toContain('Parolă nouă');
    expect(m.text).toContain('token=a&b="c"');
    expect(m.html).toContain('token=a&amp;b=&quot;c&quot;');
    expect(m.html).not.toContain('"c"');
    expect(renderMail('verify-email', 'a@b.md', 'http://x').subject).toContain('Confirmă');
  });
});
