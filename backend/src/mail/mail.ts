import { createTransport, type Transporter } from 'nodemailer';

import type { MailKind } from '../auth/email-flows';
import { digestLines, type WeeklyDigest } from '../reports/weekly';

export interface Mail {
  to: string;
  subject: string;
  text: string;
  html: string;
}

/** Adapter (README §9): azi SMTP — Mailpit în dezvoltare, releul SMTP Brevo în producție. */
export interface MailProvider {
  send(mail: Mail): Promise<void>;
}

export class SmtpMailProvider implements MailProvider {
  private readonly transport: Transporter;

  constructor(
    url: string,
    private readonly from: string,
  ) {
    this.transport = createTransport(url);
  }

  async send(mail: Mail): Promise<void> {
    await this.transport.sendMail({ from: this.from, ...mail });
  }
}

const entities: Record<string, string> = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
const escape = (s: string) => s.replace(/[&<>"']/g, (c) => entities[c]);

/** Legătura din e-mail duce în panou, care trimite tokenul la API. */
export function mailLink(appUrl: string, kind: MailKind, token: string): string {
  const path = kind === 'verify-email' ? 'confirmare' : 'parola-noua';
  return `${appUrl.replace(/\/+$/, '')}/#/${path}?token=${encodeURIComponent(token)}`;
}

/** Textele e-mailurilor (română, scurte, fără date despre copil). */
export function renderMail(kind: MailKind, to: string, link: string): Mail {
  const [subject, intro, button, outro] =
    kind === 'verify-email'
      ? [
          'Confirmă adresa de e-mail — Licurici',
          'Bine ai venit în Licurici! Confirmă adresa de e-mail ca să-ți poți recupera parola dacă o uiți.',
          'Confirmă adresa',
          'Legătura e valabilă 48 de ore. Dacă nu tu ți-ai făcut cont, ignoră acest mesaj.',
        ]
      : [
          'Parolă nouă — Licurici',
          'Cineva (sperăm că tu) a cerut o parolă nouă pentru contul tău Licurici.',
          'Alege o parolă nouă',
          'Legătura e valabilă o oră și merge o singură dată. După schimbare, sesiunile deschise se închid. ' +
            'Dacă nu tu ai cerut-o, ignoră acest mesaj — parola rămâne aceeași.',
        ];
  const text = `${intro}\n\n${button}: ${link}\n\n${outro}\n`;
  const html =
    `<div style="font-family:Arial,sans-serif;max-width:520px;color:#2b2d42">` +
    `<p>${escape(intro)}</p>` +
    `<p><a href="${escape(link)}" style="display:inline-block;background:#3c8dbc;color:#fff;padding:12px 20px;` +
    `border-radius:10px;text-decoration:none">${escape(button)}</a></p>` +
    `<p style="color:#6b6f80;font-size:13px">${escape(outro)}</p></div>`;
  return { to, subject, text, html };
}

/** Raportul săptămânal (consimțământul `WEEKLY_REPORT`): câteva rânduri calde pe copil și
 *  legătura spre panou. Doar cifre agregate și obiective — fără răspunsuri, fără timpi pe încercare. */
export function renderWeekly(to: string, digests: WeeklyDigest[], appUrl: string): Mail {
  const link = `${appUrl.replace(/\/+$/, '')}/#/parinte`;
  const blocks = digests.map(digestLines);
  const outro =
    'Primești acest e-mail pentru că ți-ai dat acordul pentru raportul săptămânal. ' +
    'Îl poți opri oricând din panou → „Contul meu”.';
  const body = blocks.map((b) => b.join('\n')).join('\n\n');
  const text = `Săptămâna aceasta în Licurici:\n\n${body}\n\nPanoul: ${link}\n\n${outro}\n`;
  const html =
    `<div style="font-family:Arial,sans-serif;max-width:560px;color:#2b2d42">` +
    `<p>Săptămâna aceasta în Licurici:</p>` +
    blocks
      .map(
        ([head, ...rest]) =>
          `<p style="margin:16px 0 4px"><b>${escape(head)}</b></p>` +
          rest.map((l) => `<div style="margin:2px 0">${escape(l)}</div>`).join(''),
      )
      .join('') +
    `<p style="margin-top:20px"><a href="${escape(link)}" style="display:inline-block;background:#527d79;color:#fff;` +
    `padding:12px 20px;border-radius:10px;text-decoration:none">Deschide panoul</a></p>` +
    `<p style="color:#6b6f80;font-size:13px">${escape(outro)}</p></div>`;
  const names = digests.map((d) => d.nickname).join(', ');
  return { to, subject: `Săptămâna lui ${names} în Licurici`, text, html };
}

