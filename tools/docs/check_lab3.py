"""Check the authored DOCX and the native Word PDF used for visual QA."""
from pathlib import Path
from zipfile import ZipFile
import json, re, collections, xml.etree.ElementTree as ET
import pymupdf as fitz
from PIL import Image, ImageDraw
import lab3_diagrams as model

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'output/docx/Laborator_3_PSI_Mudrea_Mihail_Licurici.docx'
PDF=ROOT/'tmp/lab3/word-preview.pdf'
OUT=ROOT/'tmp/lab3/render'
NS={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
model.validate_models()
z=ZipFile(DOC);xml=ET.fromstring(z.read('word/document.xml'))
def val(el,k):return el.get('{'+NS['w']+'}'+k)
sections=xml.findall('.//w:sectPr',NS)
for section in sections:
    m=section.find('w:pgMar',NS)
    assert [val(m,k) for k in ('top','left','bottom','right')]==['1134','1134','1134','567']
    sz=section.find('w:pgSz',NS)
    assert abs(int(val(sz,'w'))-11906)<=1 and abs(int(val(sz,'h'))-16838)<=1
tables=xml.findall('.//w:tbl',NS)
assert len(tables)==11,len(tables)
for t in tables:
    assert t.find('.//w:tblHeader',NS) is not None
    for r in t.findall('.//w:r',NS):
        if r.find('w:t',NS) is not None:
            sz=r.find('w:rPr/w:sz',NS)
            assert sz is not None and val(sz,'val')=='22'
assert len(xml.findall('.//{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}inline'))==9
d=fitz.open(PDF)
assert len(d)==25,len(d)
alltext='\n'.join(p.get_text() for p in d)
assert 'Crivoi' not in alltext and 'FitNet' not in alltext
fonts=collections.Counter()
for i,p in enumerate(d):
    content=p.get_text().strip()
    assert len(content)>200,(i,len(content))
    for b in p.get_text('dict')['blocks']:
        if 'lines' not in b:continue
        for line in b['lines']:
            for s in line['spans']:
                if s['text'].strip():
                    fonts[(s['font'],round(s['size'],1))]+=1
                    assert s['font'].startswith('TimesNewRoman'),(i,s)
                    # Word's PDF text boxes include a trailing space beyond the line end.
                    assert s['bbox'][0]>=55 and s['bbox'][2]<=570,(i,s)
    # Front matter has no footer number; body has its physical page number.
    footer=p.get_text(clip=fitz.Rect(0,790,596,842)).strip()
    assert footer==('' if i<3 else str(i+1)),(i,footer)
for figure in ['2.1','2.2','2.3','2.4','2.5','2.6','3.1','4.1','4.2']:
    assert 'Figura '+figure in alltext
    assert re.search(r'figur[ai] '+re.escape(figure),alltext,re.I)
assert any('fonts/font' in n for n in z.namelist())
OUT.mkdir(parents=True,exist_ok=True)
for i,p in enumerate(d):p.get_pixmap(matrix=fitz.Matrix(1.5,1.5)).save(OUT/f'page-{i+1:02}.png')
for start in range(0,len(d),5):
    sheet=Image.new('RGB',(1500,848),'#aaa')
    for j in range(start,min(start+5,len(d))):
        im=Image.open(OUT/f'page-{j+1:02}.png');im.thumbnail((300,424));sheet.paste(im,((j-start)*300,0))
        # Lower half enlarged in a second strip for checking bottom text and footers.
        orig=Image.open(OUT/f'page-{j+1:02}.png');bottom=orig.crop((0,orig.height//2,orig.width,orig.height));bottom.thumbnail((300,424));sheet.paste(bottom,((j-start)*300,424))
    sheet.save(OUT/f'group-{start//5+1}.png')
report={'pages':len(d),'figures':9,'tables':len(tables),'major_functions':4,'subfunctions':14,'front_matter_without_page_numbers':3,'font_sizes':{str(k):v for k,v in fonts.items()},'status':'passed'}
(ROOT/'tmp/lab3/checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
