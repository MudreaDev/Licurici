"""Build the PECPIT report from one validated WBS data source."""
from pathlib import Path
import json, math
from docx import Document
from docx.shared import Cm, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.section import WD_SECTION_START
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from PIL import Image, ImageDraw, ImageFont
from pecpit_wbs_data import TITLE, ROOT, ROWS, BY_CODE, LEAVES, children, validate

BASE=Path(__file__).resolve().parents[2]
OUT=BASE/'output/docx'
TMP=BASE/'tmp/pecpit'
OUT.mkdir(parents=True,exist_ok=True)
TMP.mkdir(parents=True,exist_ok=True)
STATS=validate()
FONT=Path('C:/Windows/Fonts/times.ttf')
BOLD=Path('C:/Windows/Fonts/timesbd.ttf')
doc=Document()

def section(landscape=False, first=False):
    s=doc.sections[0] if first else doc.add_section(WD_SECTION_START.NEW_PAGE)
    s.page_width=Cm(29.7 if landscape else 21)
    s.page_height=Cm(21 if landscape else 29.7)
    s.top_margin=Cm(1.5 if landscape else 2)
    s.bottom_margin=Cm(1.5 if landscape else 2)
    s.left_margin=Cm(1.5 if landscape else 2.5)
    s.right_margin=Cm(1.5)
    s.footer_distance=Cm(.7)
    return s

section(first=True)
for name in ['Normal','Title','Heading 1','Heading 2','Caption','TOC 1','TOC 2']:
    if name not in doc.styles:
        doc.styles.add_style(name,1)
    sty=doc.styles[name]
    sty.font.name='Times New Roman'
    sty.font.size=Pt(12)
    sty.font.color.rgb=RGBColor(0,0,0)
normal=doc.styles['Normal'].paragraph_format
normal.line_spacing=1.15
normal.space_after=Pt(5)
normal.first_line_indent=Cm(1.25)
for n,size in [('Heading 1',14),('Heading 2',12)]:
    st=doc.styles[n]; st.font.size=Pt(size); st.font.bold=True
    st.paragraph_format.first_line_indent=0
    st.paragraph_format.space_before=Pt(12)
    st.paragraph_format.space_after=Pt(6)
    st.paragraph_format.keep_with_next=True

def p(text='',bold=False,align=None,size=None,indent=True):
    pp=doc.add_paragraph()
    pp.paragraph_format.keep_together=True
    pp.alignment=WD_ALIGN_PARAGRAPH.JUSTIFY if align is None else align
    if not indent: pp.paragraph_format.first_line_indent=0
    rr=pp.add_run(text); rr.bold=bold;rr.font.name='Times New Roman'
    if size: rr.font.size=Pt(size)
    return pp
def h(text,level=1):
    pp=doc.add_paragraph(text,'Heading '+str(level))
    pp.runs[0].font.name='Times New Roman'
    return pp
def field(pp,instruction):
    rr=pp.add_run(); a=OxmlElement('w:fldChar'); a.set(qn('w:fldCharType'),'begin');rr._r.append(a)
    b=OxmlElement('w:instrText');b.set(qn('xml:space'),'preserve');b.text=instruction;rr._r.append(b)
    c=OxmlElement('w:fldChar');c.set(qn('w:fldCharType'),'end');rr._r.append(c)
def caption(text):
    pp=p(text,align=WD_ALIGN_PARAGRAPH.LEFT,size=11,indent=False)
    pp.runs[0].italic=True;pp.paragraph_format.keep_with_next=True
    return pp
def shade(cell,color):
    sh=OxmlElement('w:shd');sh.set(qn('w:fill'),color);cell._tc.get_or_add_tcPr().append(sh)
def table(headers,data,widths,size=10):
    t=doc.add_table(rows=1,cols=len(headers)); t.autofit=False
    for col,w in zip(t.columns,widths): col.width=Cm(w)
    for cell,w in zip(t.rows[0].cells,widths):cell.width=Cm(w)
    pr=t._tbl.tblPr
    borders=OxmlElement('w:tblBorders')
    for side in ['top','left','bottom','right','insideH','insideV']:
        x=OxmlElement('w:'+side);x.set(qn('w:val'),'single');x.set(qn('w:sz'),'4');x.set(qn('w:color'),'AABAD0');borders.append(x)
    pr.append(borders)
    margins=OxmlElement('w:tblCellMar')
    for side in ['top','left','bottom','right']:
        x=OxmlElement('w:'+side);x.set(qn('w:w'),'65');x.set(qn('w:type'),'dxa');margins.append(x)
    pr.append(margins)
    rep=OxmlElement('w:tblHeader');t.rows[0]._tr.get_or_add_trPr().append(rep)
    def fill(row,values,header=False,color=None):
        keep=OxmlElement('w:cantSplit');row._tr.get_or_add_trPr().append(keep)
        for cell,w,val in zip(row.cells,widths,values):
            cell.width=Cm(w)
            pp=cell.paragraphs[0];pp.paragraph_format.first_line_indent=0
            pp.paragraph_format.space_after=Pt(1);pp.paragraph_format.space_before=Pt(1)
            pp.paragraph_format.line_spacing=1
            if color:pp.paragraph_format.keep_with_next=True
            rr=pp.add_run(str(val));rr.font.size=Pt(size);rr.bold=header or bool(color)
            if header:
                shade(cell,'203864');rr.font.color.rgb=RGBColor(255,255,255)
                pp.alignment=WD_ALIGN_PARAGRAPH.CENTER
            elif color:shade(cell,color)
    fill(t.rows[0],headers,True)
    for vals,color in data:
        row=t.add_row();fill(row,vals,color=color)
    return t

# Cover follows the supplied PDF.
s=doc.sections[0];s.different_first_page_header_footer=True
for text,bold,size in [
('MINISTERUL EDUCAȚIEI ȘI CERCETĂRII AL REPUBLICII MOLDOVA',True,12),
('Universitatea Tehnică a Moldovei',True,12),
('Facultatea Calculatoare, Informatică și Microelectronică',False,12),
('Departamentul Ingineria Software și Automatică',False,12)]:
    pp=p(text,bold,WD_ALIGN_PARAGRAPH.CENTER,size,False);pp.paragraph_format.space_after=0;pp.paragraph_format.line_spacing=1.1
pp=p('RAPORT',True,WD_ALIGN_PARAGRAPH.CENTER,20,False)
pp.style=doc.styles['Title'];pp.runs[0].bold=True;pp.runs[0].font.size=Pt(20)
border=OxmlElement('w:pBdr')
bottom=OxmlElement('w:bottom');bottom.set(qn('w:val'),'nil');border.append(bottom)
pp._p.get_or_add_pPr().append(border)
pp.paragraph_format.space_before=Pt(145);pp.paragraph_format.space_after=Pt(4)
p('la lucrarea practică nr. 1',align=WD_ALIGN_PARAGRAPH.CENTER,size=14,indent=False)
p('Disciplina: Planificarea și estimarea costurilor proiectelor IT',align=WD_ALIGN_PARAGRAPH.CENTER,indent=False)
pp=p('Tema: Elaborarea structurii de decompoziție a lucrărilor (WBS)\npentru proiectul de licență',True,WD_ALIGN_PARAGRAPH.CENTER,14,False)
pp.paragraph_format.space_before=Pt(16)
pp=p('A elaborat: st. gr. TI-233, Mudrea Mihail',align=WD_ALIGN_PARAGRAPH.RIGHT,indent=False)
pp.paragraph_format.space_before=Pt(92)
p('A verificat: asist. univ. Cojocaru Svetlana',align=WD_ALIGN_PARAGRAPH.RIGHT,indent=False)
pp=p('Chișinău, 2026',True,WD_ALIGN_PARAGRAPH.CENTER,12,False);pp.paragraph_format.space_before=Pt(138)
footer=s.footer.paragraphs[0];footer.alignment=WD_ALIGN_PARAGRAPH.CENTER;footer.paragraph_format.first_line_indent=0;field(footer,' PAGE ')
doc.add_page_break()
p('CUPRINS',True,WD_ALIGN_PARAGRAPH.CENTER,16,False)
field(p(indent=False),' TOC \\o "1-2" \\h \\z \\u ')
doc.add_page_break()
h('1. Tema proiectului de licență')
p('„'+TITLE+'”',True)
p('Produsul realizat în cadrul proiectului poartă denumirea Licurici. Sistemul reunește aplicația copilului, un panou web pentru părinte și specialist și servicii centrale pentru sincronizare, planificarea activităților și urmărirea progresului. Activitățile sunt în limba română și pot fi utilizate local, fără cont și fără conexiune la internet.')
h('2. Scopul proiectului')
p('Dezvoltarea unui sistem informatic care sprijină adultul în organizarea și personalizarea activităților pentru copii cu tulburări din spectrul autist, oferă copilului exerciții interactive adaptate senzorial și permite urmărirea progresului pe abilități. Sistemul include un asistent AI destinat exclusiv adulților, pentru rezumarea și explicarea statisticilor disponibile. Interpretarea terapeutică și deciziile de intervenție rămân în responsabilitatea specialistului.')
p('Perimetrul de mai jos definește versiunea evaluată în proiectul de licență. WBS-ul acoperă atât lucrările deja începute sau realizate, cât și lucrările necesare pentru finalizare; nu reprezintă un raport care declară toate funcțiile validate.')
p('Include:',True,indent=False)
for text in [
'aplicația Flutter pentru copil, pe Android: profil local, sesiuni offline, jocuri pe arii de dezvoltare, comunicare augmentativă și alternativă (AAC), ilustrații și voce română;',
'personalizarea nivelurilor și a planului de lucru, modul calm, limitele de utilizare, recompensele și acvariul cu pești colorați digital sau importați dintr-o fișă fotografiată;',
'panoul Flutter Web al părintelui și specialistului: planuri, progres, notițe, partajare și controlul datelor;',
'API NestJS, PostgreSQL, Redis, worker BullMQ și stocare compatibilă S3 în Docker; sincronizare, statistici, actualizări live și e-mailuri;',
'asistentul AI pentru adulți, apelat din backend pe baza unui acord separat și a statisticilor agregate fără identificatori direcți;',
'testarea tehnică, evaluarea utilizabilității cu adulți, documentația, mediul de demonstrație și susținerea tezei.'
]:p('– '+text,indent=False)
p('Nu include în versiunea evaluată:',True,indent=False)
for text in [
'diagnosticarea TSA, prescrierea automată a terapiei sau demonstrarea eficacității clinice prin studiu cu copii;',
'chat AI pentru copil, generarea online a sarcinilor copilului sau recunoașterea automată a emoțiilor din imagini ale copiilor;',
'extinderea conținutului pentru clasele 5–12, publicarea comercială în magazine și validarea unui build iOS.'
]:p('– '+text,indent=False)
h('3. WBS-ul proiectului')
p(f'Structura are {STATS["elements"]} de elemente: proiectul-rădăcină, 9 componente majore, 8 activități intermediare de realizare și {STATS["packages"]} de pachete de lucru. Codul 1.0 identifică proiectul, 1.1–1.9 componentele, iar codurile de forma 1.1.1 identifică descompunerile lor. Pentru componenta 1.6 se folosește încă un nivel, de exemplu 1.6.8.2 pentru serviciul AI din backend.')
p('Rădăcina este nivelul 0, componentele sunt nivelul 1, iar pachetele directe nivelul 2. Modulele de realizare de la nivelul 2 sunt descompuse în pachete la nivelul 3. Numai elementele fără subelemente sunt pachete de lucru; componentele-părinte nu se estimează încă o dată peste copiii lor.')
p('WBS-ul definește ce trebuie realizat. Numerotarea nu exprimă succesiunea în timp și nu introduce dependențe. Estimarea duratelor și costurilor, atribuirea responsabilităților și diagramele PERT/Gantt se vor elabora ulterior pe baza acestor coduri.')
h('3.1. Structura ierarhică a WBS-ului',2)
p('1.0 '+ROOT,True,indent=False)
for comp in children('1.0'):
    pp=p(comp['code']+' '+comp['name'],True,indent=False);pp.paragraph_format.keep_with_next=True
    if comp['code']!='1.6':
        text='; '.join(r['code']+' '+r['name'] for r in children(comp['code']))+'.'
        pp=p(text,indent=False);pp.paragraph_format.left_indent=Cm(.45);pp.paragraph_format.line_spacing=1.05
    else:
        for mod in children('1.6'):
            pp=p(mod['code']+' '+mod['name'],True,indent=False);pp.paragraph_format.left_indent=Cm(.45);pp.paragraph_format.keep_with_next=True
            for leaf in children(mod['code']):
                pp=p(leaf['code']+' '+leaf['name'],indent=False);pp.paragraph_format.left_indent=Cm(.9);pp.paragraph_format.space_after=Pt(1);pp.paragraph_format.line_spacing=1
h('3.2. Verificarea completitudinii (regula de 100%)',2)
p('Verificarea pornește de la livrabilele incluse în perimetru, nu doar de la numărul elementelor. Fiecare livrabil are lucrări de definire, modelare, proiectare, realizare, testare și documentare. Pachetele de lucru reunite acoperă integral rezultatul părintelui, fără a include extensiile excluse.')
caption('Tabelul 3.1 – Numărul de elemente pe componente')
counts=[]
for comp in children('1.0'):
    code=comp['code']; n=sum(r['code'].startswith(code+'.') for r in LEAVES)
    counts.append(([code,comp['name'],8 if code=='1.6' else 0,n],None))
counts.append((['','Total',8,len(LEAVES)],'D9E7F3'))
table(['Cod','Componentă','Activități intermediare','Pachete de lucru'],counts,[1.3,9.1,3.1,3.5],11)
p('Trasabilitatea perimetrului se verifică astfel:')
for text in [
'Aplicația copilului și sesiunile locale: 1.6.3; jocurile, AAC și materialele: 1.6.4; recompensele și acvariul: 1.6.5. Inventarul jocurilor se verifică față de catalog, astfel încât fiecare joc să aparțină unui singur pachet de realizare.',
'Panoul adulților și planurile: 1.6.6; serviciile centrale și controlul accesului: 1.6.2; sincronizarea, statisticile și notificările: 1.6.7; asistentul AI: 1.6.8; mediile și livrarea: 1.6.1.',
'Cerințele și proiectarea sunt acoperite de 1.1–1.5, verificările transversale de 1.7, documentele de 1.8, iar coordonarea și susținerea de 1.9. Testele din 1.7 verifică rezultatele implementării și nu reprezintă o a doua implementare.'
]:p('– '+text,indent=False)
p('Pentru evitarea dublei contabilizări, API-ul de confidențialitate se realizează în 1.6.2.4, iar interfața lui în 1.6.6.4. Salvarea locală aparține 1.6.3.4, transferul aparține 1.6.7.1, iar agregarea centrală aparține 1.6.7.2. Conținutul vizual și vocal se produce în 1.6.4.6 și este reutilizat de jocuri. Proiectarea definește contractele, implementarea le execută, testarea furnizează dovezi, iar documentarea le explică.')
p('Consultările și verificările cu adulți sunt activități planificate. Nu se afirmă că au avut deja loc și nu se deduc rezultate clinice din statisticile jocurilor. Orice modificare ulterioară de perimetru impune revizuirea structurii și a criteriilor aferente.')

section(True)
h('4. Descrierea activităților WBS')
p('Tabelul 4.1 precizează lucrarea, rezultatul și criteriul de finalizare. Rândurile albastre reprezintă proiectul, componentele și activitățile intermediare; criteriile acestora se verifică prin pachetele subordonate. Criteriile sunt ținte de acceptare, nu rezultate de testare deja obținute.',indent=False)
caption('Tabelul 4.1 – Descrierea elementelor WBS')
data=[]
for r in ROWS:
    color=('B8CEE3' if r['code']=='1.0' else 'D9E7F3') if children(r['code']) else None
    data.append(([r[k] for k in ['code','name','work','result','done']],color))
table(['Cod','Element WBS','Ce trebuie realizat','Rezultat așteptat','Criteriu de finalizare'],data,[1.5,4.3,8.1,5.4,7.4],10)

def wrap(draw,text,font,width):
    lines=[];cur=''
    for word in text.split():
        test=(cur+' '+word).strip()
        if cur and draw.textlength(test,font=font)>width:lines.append(cur);cur=word
        else:cur=test
    if cur:lines.append(cur)
    return lines

def diagram(groups,root_code,name):
    W=2600;H=1650
    img=Image.new('RGB',(W,H),'white');d=ImageDraw.Draw(img)
    font=ImageFont.truetype(str(FONT),32);bold=ImageFont.truetype(str(BOLD),34)
    def box(x,y,w,text,fill,font=font,fg='#17263D'):
        lines=wrap(d,text,font,w-28);height=24+len(lines)*39
        d.rounded_rectangle((x,y,x+w,y+height),radius=8,fill=fill,outline='#657A96',width=2)
        for i,line in enumerate(lines): d.text((x+14,y+10+i*39),line,font=font,fill=fg)
        return height
    rw=1250;rx=(W-rw)//2
    rh=box(rx,10,rw,root_code+'  '+BY_CODE[root_code]['name'],'#203864',bold,'white')
    gap=30;cw=(W-40-(len(groups)-1)*gap)/len(groups);top=190
    centers=[20+i*(cw+gap)+cw/2 for i in range(len(groups))]
    d.line((W/2,10+rh,W/2,top-30),fill='#657A96',width=3)
    d.line((centers[0],top-30,centers[-1],top-30),fill='#657A96',width=3)
    bottom=0
    for i,g in enumerate(groups):
        x=20+i*(cw+gap);center=centers[i]
        d.line((center,top-30,center,top),fill='#657A96',width=3)
        hh=box(x,top,cw,g['code']+' '+g['name'],'#3474B4',bold,'white')
        yy=top+hh+30;line_x=x+10
        childitems=children(g['code']); ys=[]
        for child in childitems:
            cc='#DAE9F7' if children(child['code']) else '#FFFFFF'
            bh=box(x+32,yy,cw-32,child['code']+' '+child['name'],cc)
            ys.append(yy+bh/2);d.line((line_x,yy+bh/2,x+32,yy+bh/2),fill='#657A96',width=3)
            yy+=bh+18
        if ys:d.line((line_x,top+hh,line_x,ys[-1]),fill='#657A96',width=3)
        bottom=max(bottom,yy)
    assert bottom<H,(name,bottom)
    img=img.crop((0,0,W,int(bottom+15)))
    path=TMP/(name+'.png');img.save(path);return path

doc.add_page_break()
h('5. Reprezentarea grafică a WBS')
p('Diagramele sunt generate din aceeași structură de date ca lista și tabelul, păstrând codurile și relațiile părinte–copil. Pentru lizibilitate, vederea de ansamblu este împărțită în figurile 5.1–5.2, iar componenta 1.6 este detaliată până la pachetele de lucru în figurile 5.3–5.4. Împărțirea este doar grafică; toate figurile aparțin aceluiași WBS.',indent=False)
groups=children('1.0');mods=children('1.6')
figs=[
(groups[:5],'1.0','wbs-overview-a','Figura 5.1 – WBS: componentele 1.1–1.5 și pachetele subordonate'),
(groups[5:],'1.0','wbs-overview-b','Figura 5.2 – WBS: componentele 1.6–1.9 și descompunerea lor'),
(mods[:4],'1.6','wbs-implementation-a','Figura 5.3 – Realizarea soluției: modulele 1.6.1–1.6.4'),
(mods[4:],'1.6','wbs-implementation-b','Figura 5.4 – Realizarea soluției: modulele 1.6.5–1.6.8')]
for i,(group,code,name,label) in enumerate(figs):
    if i:doc.add_page_break()
    path=diagram(group,code,name)
    pp=doc.add_paragraph();pp.paragraph_format.first_line_indent=0
    pp.paragraph_format.space_after=0;pp.alignment=WD_ALIGN_PARAGRAPH.CENTER
    pp.add_run().add_picture(str(path),width=Cm(26.7))
    pp=p(label,align=WD_ALIGN_PARAGRAPH.CENTER,size=11,indent=False);pp.runs[0].italic=True
    p('Legendă: albastru închis – rădăcina vederii; albastru – componente sau module; albastru deschis – activități detaliate în altă figură; alb – pachete de lucru.',size=10,indent=False)

section(False)
h('6. Concluzii')
p(f'WBS-ul elaborat descompune proiectul „{TITLE}” în {len(LEAVES)} de pachete de lucru verificabile. Structura leagă analiza nevoilor copilului, părintelui și specialistului de realizarea aplicațiilor, a serviciilor centrale și a materialelor necesare susținerii tezei.')
p(f'Componenta 1.6 cuprinde {STATS["implementation_packages"]} de pachete de realizare grupate în opt module. Această descompunere face vizibile lucrările specifice Licurici: sesiuni offline, accesibilitate senzorială, comunicare AAC, acvariu, planuri individualizate, sincronizare fără dubluri și asistent AI pentru adulți. Numărul pachetelor descrie structura, dar nu permite încă estimarea ponderii de efort sau a costurilor.')
p('Delimitarea responsabilităților dintre stocarea locală, sincronizare și calculul statisticilor evită suprapunerile. Separarea API-ului de interfața panoului și a contextului AI de serviciul extern clarifică rezultatele care trebuie livrate. Criteriile de finalizare permit verificarea fiecărui pachet printr-un document, un modul executabil sau un raport de testare.')
p('Regula de 100% a fost verificată prin raportarea ramurilor la perimetrul declarat și prin includerea lucrărilor de testare, documentare și management. Evaluarea tehnică și feedbackul adulților sunt tratate separat de eficacitatea clinică, care nu face parte din obiectivele acestei lucrări.')
p('În etapele următoare, codurile pachetelor vor fi utilizate pentru estimarea duratelor și costurilor, atribuirea responsabilităților și stabilirea dependențelor. Pe această bază se vor construi rețeaua PERT și diagrama Gantt, fără a estima separat componentele-părinte peste pachetele pe care le conțin.')

for s in doc.sections[1:]:s.different_first_page_header_footer=False
settings=doc.settings.element
for tag in list(settings):
    if tag.tag==qn('w:updateStyles'):settings.remove(tag)
update_styles=OxmlElement('w:updateStyles');update_styles.set(qn('w:val'),'false');settings.append(update_styles)
update=OxmlElement('w:updateFields');update.set(qn('w:val'),'true');settings.append(update)
path=OUT/'PECPIT_lab1_Mudrea_Mihail_Licurici.docx'
doc.save(path)
(TMP/'wbs.json').write_text(json.dumps({'stats':STATS,'rows':ROWS},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(STATS));print(path)
