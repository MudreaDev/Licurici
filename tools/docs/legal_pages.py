"""Paginile publice ale panoului din documentele GDPR (Markdown → HTML static).

Rulare: python tools/docs/legal_pages.py
Scrie: apps/dashboard/web/confidentialitate.html și termeni.html (intră în build-ul web al panoului,
deci sunt servite la https://panou.<domeniu>/confidentialitate.html — URL-ul cerut de Google Play).
Convertorul acoperă doar ce folosesc documentele: titluri, paragrafe, liste, tabele, citate,
**îngroșat**, *cursiv*, `cod` și legături.
"""
import html
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, 'docs', 'gdpr')
OUT = os.path.join(ROOT, 'apps', 'dashboard', 'web')

PAGES = {'politica-confidentialitate.md': 'confidentialitate.html', 'termeni.md': 'termeni.html'}


def inline(text):
    t = html.escape(text, quote=False)
    t = re.sub(r'`([^`]+)`', r'<code>\1</code>', t)
    t = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', t)
    t = re.sub(r'(?<![*\w])\*([^*]+)\*(?!\*)', r'<em>\1</em>', t)

    def link(m):
        label, href = m.group(1), m.group(2)
        # Legăturile interne din docs/ nu există pe site: rămâne doar textul.
        if href.endswith('.md') or href.startswith('../') or href.startswith('README'):
            return label
        return f'<a href="{html.escape(href)}">{label}</a>'

    return re.sub(r'\[([^\]]+)\]\(([^)]+)\)', link, t)


def convert(md):
    out, para, items, table, quote = [], [], [], [], []

    def flush():
        nonlocal para, items, table, quote
        if para:
            out.append('<p>' + inline(' '.join(para)) + '</p>')
        if items:
            out.append('<ul>' + ''.join(f'<li>{inline(i)}</li>' for i in items) + '</ul>')
        if table:
            rows = [r for r in table if not re.fullmatch(r'\|?[\s:|-]+\|?', r)]
            cells = [[c.strip() for c in r.strip('|').split('|')] for r in rows]
            head, body = cells[0], cells[1:]
            out.append(
                '<div class="t"><table><thead><tr>' + ''.join(f'<th>{inline(c)}</th>' for c in head) + '</tr></thead><tbody>'
                + ''.join('<tr>' + ''.join(f'<td>{inline(c)}</td>' for c in r) + '</tr>' for r in body)
                + '</tbody></table></div>'
            )
        if quote:
            out.append('<blockquote>' + inline(' '.join(quote)) + '</blockquote>')
        para, items, table, quote = [], [], [], []

    for raw in md.splitlines():
        line = raw.rstrip()
        if not line.strip():
            flush()
            continue
        if m := re.match(r'(#{1,4})\s+(.*)', line):
            flush()
            n = len(m.group(1))
            out.append(f'<h{n}>{inline(m.group(2))}</h{n}>')
        elif line.lstrip().startswith('|'):
            if para or items or quote:
                flush()
            table.append(line.strip())
        elif re.match(r'\s*[-*]\s+', line):
            if para or table or quote:
                flush()
            items.append(re.sub(r'^\s*[-*]\s+', '', line))
        elif re.match(r'\s*\d+\.\s+', line):
            if para or table or quote:
                flush()
            items.append(re.sub(r'^\s*\d+\.\s+', '', line))
        elif line.startswith('>'):
            if para or items or table:
                flush()
            quote.append(line.lstrip('> ').strip())
        elif items and raw.startswith('  '):
            items[-1] += ' ' + line.strip()
        else:
            if items or table or quote:
                flush()
            para.append(line.strip())
    flush()
    return '\n'.join(out)


PAGE = """<!doctype html>
<html lang="ro"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
body{{margin:0;background:#f5f3ed;color:#2b2d42;font:16px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}}
main{{max-width:820px;margin:0 auto;padding:32px 16px 64px}}
h1{{font-size:28px;line-height:1.25;color:#2f5552}}h2{{margin-top:32px;font-size:21px;color:#2f5552}}h3{{font-size:18px}}
a{{color:#2f6f69}}code{{background:#e8efe9;padding:1px 5px;border-radius:4px;font-size:14px}}
blockquote{{margin:16px 0;padding:10px 16px;background:#fff6dc;border-left:4px solid #e3b94f;border-radius:6px}}
.t{{overflow-x:auto}}table{{border-collapse:collapse;width:100%;margin:12px 0;font-size:14px;background:#fffdf8}}
th,td{{border:1px solid #d9e2dc;padding:6px 8px;text-align:left;vertical-align:top}}th{{background:#e8efe9}}
footer{{margin-top:40px;font-size:13px;color:#6b6f80}}
</style></head><body><main>
{body}
<footer>Licurici · <a href="confidentialitate.html">Confidențialitate</a> · <a href="termeni.html">Termeni</a></footer>
</main></body></html>
"""


def main():
    for src, dst in PAGES.items():
        md = open(os.path.join(SRC, src), encoding='utf-8').read()
        body = convert(md)
        title = re.search(r'<h1>(.*?)</h1>', body)
        title = re.sub('<[^>]+>', '', title.group(1)) if title else 'Licurici'
        with open(os.path.join(OUT, dst), 'w', encoding='utf-8', newline='\n') as f:
            f.write(PAGE.format(title=html.escape(title), body=body))
        print('scris', dst)


if __name__ == '__main__':
    main()
