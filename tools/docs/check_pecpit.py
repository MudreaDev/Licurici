"""Structural PDF checks and page renderings for manual visual review."""
from pathlib import Path
import re,json
import pymupdf
from PIL import Image, ImageDraw
from pecpit_wbs_data import ROWS, TITLE, validate
root=Path(__file__).resolve().parents[2]
pdf=pymupdf.open(root/'output/pdf/PECPIT_lab1_Mudrea_Mihail_Licurici.pdf')
out=root/'tmp/pecpit/qa';out.mkdir(parents=True,exist_ok=True)
texts=[p.get_text() for p in pdf]
combined='\n'.join(texts)
assert 'Mudrea Mihail' in combined
assert 'Crivoi' not in combined and 'FitNet' not in combined
assert 'Error!' not in combined and 'Bookmark not defined' not in combined
assert ' '.join(TITLE.split()) in ' '.join(combined.split())
for r in ROWS:
    assert len(re.findall(r'(?<![\d.])'+re.escape(r['code'])+r'(?![\d.])',combined))>=2,r['code']
for i,p in enumerate(pdf):
    assert len(texts[i].strip())>40,('blank',i+1)
    p.get_pixmap(matrix=pymupdf.Matrix(1.3,1.3)).save(str(out/f'page-{i+1:02}.png'))
    print(i+1,round(p.rect.width),round(p.rect.height),len(texts[i]),repr(texts[i][:100]))
for start in range(0,len(pdf),6):
    sheet=Image.new('RGB',(1500,1280),'#dddddd');draw=ImageDraw.Draw(sheet)
    for j in range(start,min(start+6,len(pdf))):
        im=Image.open(out/f'page-{j+1:02}.png');im.thumbnail((480,595))
        x=(j-start)%3*500+(500-im.width)//2;y=(j-start)//3*640+30
        sheet.paste(im,(x,y));draw.text((x,y-20),f'Pagina {j+1}',fill='black')
    sheet.save(out/f'contact-{start//6+1}.png')
(out/'text.txt').write_text('\n\n'.join(f'PAGE {i+1}\n{t}' for i,t in enumerate(texts)),encoding='utf-8')
print(json.dumps({'pages':len(pdf),**validate()}))
