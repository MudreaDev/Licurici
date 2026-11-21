"""Generate the PERT report and network illustrations from the checked model."""
from pathlib import Path
import math, json
from PIL import Image, ImageDraw, ImageFont
from docx import Document
from docx.shared import Cm, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from pecpit2_model import build, serializable

ROOT=Path(__file__).resolve().parents[2]; TMP=ROOT/'tmp/pecpit2';TMP.mkdir(parents=True,exist_ok=True)
M=build(); R=M['rows']; B={r['code']:r for r in R}; S=M['stats']
def num(v):return f'{float(v):,.2f}'.replace(',',' ').replace('.',',')
groups=[list(range(1,10)),list(range(10,19))+[36],list(range(19,31)),[n for n in range(31,43) if n!=36],list(range(43,49))]
critical_edges=set(zip(M['paths'][0]['nodes'],M['paths'][0]['nodes'][1:]))
for ix,ns in enumerate(groups,1):
    codes=[f'P{n:02}' for n in ns]; levels={}
    for c in codes: levels[c]=1+max((levels[p] for p in B[c]['pred'] if p in levels),default=-1)
    height=(max(levels.values())+1)*170+100
    im=Image.new('RGB',(1400,height),'white');d=ImageDraw.Draw(im)
    f=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25);fb=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',30)
    pos={}
    for level in set(levels.values()):
        layer=[c for c in codes if levels[c]==level]
        for j,c in enumerate(layer):pos[c]=(1400*(j+1)/(len(layer)+1),75+level*170)
    def arrow(a,b,color):
        dx,dy=b[0]-a[0],b[1]-a[1];ln=math.hypot(dx,dy);ux,uy=dx/ln,dy/ln
        start=(a[0]+ux*53,a[1]+uy*53);end=(b[0]-ux*55,b[1]-uy*55)
        d.line([start,end],fill=color,width=4)
        d.polygon([end,(end[0]-ux*16-uy*8,end[1]-uy*16+ux*8),(end[0]-ux*16+uy*8,end[1]-uy*16-ux*8)],fill=color)
    for c in codes:
        for p in B[c]['pred']:
            if p in pos:arrow(pos[p],pos[c],'#BC3046' if (p,c) in critical_edges else '#88919B')
    for c in codes:
        x,y=pos[c];r=B[c];color='#F4CFF4' if r['critical'] else '#DCEAF5'
        d.ellipse((x-54,y-54,x+54,y+54),fill=color,outline='#BC3046' if r['critical'] else '#527594',width=3)
        d.text((x,y-17),c,font=fb,anchor='mm',fill='#172B46');d.text((x,y+20),num(r['te']),font=f,anchor='mm',fill='#172B46')
        incoming=[p for p in r['pred'] if p not in pos];outgoing=[s for s in r['succ'] if s not in pos]
        if incoming:d.text((x-67,y-18),'Din '+', '.join(incoming)+' →',font=f,anchor='rm',fill='#444444')
        if outgoing:d.text((x+67,y+20),'→ Spre '+', '.join(outgoing),font=f,anchor='lm',fill='#444444')
        if c=='P01':d.text((x+70,y),'START',font=f,anchor='lm',fill='#444444')
        if c=='P48':d.text((x+70,y),'FINAL',font=f,anchor='lm',fill='#444444')
    im.save(TMP/f'network-{ix}.png')

doc=Document();sec=doc.sections[0];sec.page_width=Cm(21);sec.page_height=Cm(29.7)
sec.top_margin=Cm(2);sec.bottom_margin=Cm(2);sec.left_margin=Cm(2.5);sec.right_margin=Cm(1.5)
sec.different_first_page_header_footer=True
for name in ['Normal','Heading 1','Heading 2']:
    st=doc.styles[name];st.font.name='Times New Roman';st.font.size=Pt(12);st.font.color.rgb=RGBColor(0,0,0)
normal=doc.styles['Normal'].paragraph_format;normal.line_spacing=1.5;normal.first_line_indent=Cm(1.25);normal.space_after=Pt(6)
def p(text='',bold=False,center=False,size=12):
    q=doc.add_paragraph();q.alignment=WD_ALIGN_PARAGRAPH.CENTER if center else WD_ALIGN_PARAGRAPH.JUSTIFY
    if center:q.paragraph_format.first_line_indent=0
    a=q.add_run(text);a.bold=bold;a.font.name='Times New Roman';a.font.size=Pt(size);return q
def heading(text,new=True):
    if new:doc.add_page_break()
    q=p(text,True,True,12);q.paragraph_format.keep_with_next=True
def table(head,rows,widths,size=9):
    t=doc.add_table(rows=1,cols=len(head));t.autofit=False
    for col,w in zip(t.columns,widths):col.width=Cm(w)
    borders=OxmlElement('w:tblBorders')
    for side in ['top','bottom','left','right','insideH','insideV']:
        e=OxmlElement('w:'+side);e.set(qn('w:val'),'single');e.set(qn('w:sz'),'4');e.set(qn('w:color'),'AAAAAA');borders.append(e)
    t._tbl.tblPr.append(borders)
    repeat=OxmlElement('w:tblHeader');t.rows[0]._tr.get_or_add_trPr().append(repeat)
    for i,vals in enumerate([head]+rows):
        row=t.rows[0] if i==0 else t.add_row();row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
        for cell,w,v in zip(row.cells,widths,vals):
            cell.width=Cm(w);q=cell.paragraphs[0];q.paragraph_format.first_line_indent=0;q.paragraph_format.line_spacing=1;q.paragraph_format.space_after=Pt(4);q.paragraph_format.space_before=Pt(4)
            a=q.add_run(str(v));a.font.name='Times New Roman';a.font.size=Pt(size);a.bold=i==0
            if i==0:
                e=OxmlElement('w:shd');e.set(qn('w:fill'),'F4CFF4');cell._tc.get_or_add_tcPr().append(e)
    return t
footer=sec.footer.paragraphs[0];footer.alignment=WD_ALIGN_PARAGRAPH.CENTER
e=OxmlElement('w:fldSimple');e.set(qn('w:instr'),'PAGE');footer._p.append(e)
for text in ['MINISTERUL EDUCAȚIEI ȘI CERCETĂRII AL REPUBLICII MOLDOVA','Universitatea Tehnică a Moldovei','Facultatea Calculatoare, Informatică și Microelectronică','Departamentul Ingineria Software și Automatică']:
    q=p(text,True,True);q.paragraph_format.line_spacing=1;q.paragraph_format.space_after=Pt(2)
q=p(M['title'],True,True,16);q.paragraph_format.space_before=Pt(110)
p('Planificarea și estimarea costurilor proiectelor IT',False,True)
p('Laborator 2: Estimarea duratelor și planificarea activităților proiectului de licență prin metoda PERT',True,True,14)
q=p('Student: _____________ Mudrea Mihail, TI-233',center=True);q.paragraph_format.space_before=Pt(65)
p('Coordonator: _____________ Cojocaru Svetlana',center=True)
q=p('Chișinău, 2026',center=True);q.paragraph_format.space_before=Pt(65)
heading('1. SCOPUL LUCRĂRII ȘI PERIMETRUL PROIECTULUI')
p('Scopul lucrării este estimarea în trei puncte a activităților proiectului Licurici, stabilirea dependențelor logice, construirea rețelei PERT și determinarea tuturor traseelor complete și a drumului critic.')
p('Sistemul cuprinde aplicația Flutter pentru copil, jocuri și comunicare augmentativă și alternativă (AAC), acvariu, panourile părintelui și specialistului, servicii NestJS cu PostgreSQL, Redis, BullMQ și stocare S3, sincronizare offline, rapoarte și asistent AI destinat adulților. Sunt incluse testarea, documentarea, managementul și susținerea tezei. Nu sunt incluse conținutul pentru clasele 5–12, studiul clinic și comercializarea prin magazine.')
p('Estimarea privește întregul proiect, de la analiză până la susținere, nu numai lucrările rămase la data redactării. Valorile reprezintă ipoteze de planificare ale autorului, nu măsurători ale timpului deja consumat și nu estimări preluate din exemplul altui student.')
p('Cele 69 de pachete terminale din WBS-ul laboratorului 1 sunt acoperite prin 48 de activități PERT. Pachetele apropiate sunt grupate într-o activitate cu rezultat comun. Numai 1.9.2 este împărțit în trei porțiuni distincte: revizuirea cerințelor (P09), a proiectării (P17) și a rezultatului final (P42). Estimările lor se adună; nu se estimează încă o dată întregul pachet. Nu sunt estimate noduri-părinte peste propriii descendenți.')
heading('2. METODA DE ESTIMARE ȘI IPOTEZE')
p('O este durata optimistă, M durata cea mai probabilă, iar P durata pesimistă. Toate sunt exprimate în ore de lucru și respectă 0 < O ≤ M ≤ P. Media PERT se calculează fără rotunjiri intermediare:')
p('te = (O + 4M + P) / 6',True,True)
p('O presupune cerințe stabile și reutilizare reușită. M include implementarea obișnuită și verificări locale. P include dificultăți de integrare, adaptări și refaceri. Riscurile sunt mai mari la jocuri, conținut multimedia, sincronizare și AI; justificarea fiecărui interval este inclusă în anexa A și în Excel.')
p('Pentru P25, te = (80 + 4 × 128 + 200) / 6 = 132,00 ore. Pentru P26, te = (96 + 4 × 160 + 260) / 6 = 166,00 ore. Afișarea la două zecimale nu modifică precizia calculelor.')
p('Modelul folosește dependențe final–început, fără decalaje. ES = max(EF ale predecesorilor), EF = ES + te. Pentru activitatea finală LF = durata proiectului; pentru celelalte LF = min(LS ale succesorilor). LS = LF − te, iar rezerva totală RT = LS − ES. Activitățile cu RT = 0 sunt critice.')
p('Fiecare activitate presupune un executant. Rețeaua nu impune o limită globală de resurse, deci admite suprapunerea ramurilor independente. Pentru un singur student, aceasta este o limită teoretică a duratei pe dependențe; un calendar realist necesită disponibilitatea pe zi, pauzele și nivelarea resurselor. Așteptarea programărilor și data comisiei nu sunt incluse în orele de lucru.')
p('Varianța orientativă din Excel este σ² = ((P − O) / 6)², în ore². Nu se transformă într-o promisiune de termen sau într-un interval de încredere clinic ori operațional.')
for start in range(0,48,12):
    heading('3. TABELUL ACTIVITĂȚILOR PERT'+(' — continuare' if start else ''))
    p('Unitate: ore. Codurile WBS enumerate sunt pachete terminale; „—” indică lipsa predecesorului.',size=10)
    table(['PERT','WBS','Activitate','Predecesori','O','M','P','te'],[[r['code'],', '.join(r['wbs']),r['name'],', '.join(r['pred']) or '—',r['O'],r['M'],r['P'],num(r['te'])] for r in R[start:start+12]],[1,2,5.1,2,1,1,1,1.9])
for i in range(1,6):
    heading(f'4. REȚEAUA PERT — FIGURA {i}/5')
    p('Nod: cod PERT și te (ore). Roz și săgeți roșii: drumul critic; albastru și gri: ramuri necritice. „Din/Spre” continuă aceeași muchie în altă figură; nu reprezintă activități suplimentare.',size=10)
    im=Image.open(TMP/f'network-{i}.png');width=min(17,19*im.width/im.height)
    q=doc.add_paragraph();q.paragraph_format.first_line_indent=0;q.alignment=WD_ALIGN_PARAGRAPH.CENTER;q.add_run().add_picture(str(TMP/f'network-{i}.png'),width=Cm(width))
    p(f'Figura {i}. '+['Inițializarea și analiza','Proiectarea, infrastructura și planul de test','Ramurile de implementare','Integrarea, AI și verificarea','Livrarea și susținerea'][i-1],center=True,size=10)
heading('5. TRASEELE COMPLETE ȘI DURATELE LOR')
p('Un traseu complet începe în P01 și se termină în P48. Durata sa este suma te a activităților vizitate. Enumerarea tuturor succesorilor în rețeaua aciclică produce 78 de trasee distincte. În tabel, codurile numerice scurte 01, 02 etc. înseamnă P01, P02 etc.; toate traseele sunt scrise integral, fără omiterea activităților comune.')
p('Ordinea T01–T78 este descrescătoare după durata estimată inițială. T01 este singurul traseu critic. În Excel, duratele și marcajul critic se recalculează la modificarea estimărilor; ordinea rândurilor rămâne fixă.')
for start,end in [(0,10),(10,24),(24,38),(38,52),(52,66),(66,78)]:
    if start:heading('5. TRASEELE COMPLETE — continuare')
    table(['ID','Succesiunea completă (prefix P)','Ore','Critic'],[[x['id'],' → '.join(c[1:] for c in x['nodes']),num(x['duration']),'DA' if x['critical'] else 'NU'] for x in M['paths'][start:end]],[1.1,12,2,1.9],9)
heading('6. DRUMUL CRITIC ȘI REZERVELE')
p('Drumul critic este traseul cu durata maximă, nu traseul cu cele mai multe activități și nici suma tuturor ramurilor. Pentru estimările inițiale, T01 are 36 de activități și durata de '+num(S['duration'])+' ore.')
p(' → '.join(M['paths'][0]['nodes']),True,size=10)
table(['Indicator','Rezultat'],[['Durata pe drumul critic',num(S['duration'])+' ore'],['Efort total, toate activitățile',num(S['effort'])+' ore-om'],['Trasee complete / critice','78 / 1'],['Al doilea traseu ca durată',num(S['second_path'])+' ore'],['Diferența față de T01',num(S['duration']-S['second_path'])+' ore']],[10,7],11)
p('P25 și P26 concentrează 298,00 ore pe drumul critic. Reducerea duratei unei activități necritice nu scurtează automat proiectul. Ramura de proiectare prin P16 și ramura de testare prin P39 sunt aproape critice, cu rezerve de numai 4,67 ore. Recalcularea este necesară după orice schimbare a estimărilor.')
p('Pentru execuție strict individuală și fără suprapunerea muncii, cele '+num(S['effort'])+' ore-om sunt reperul de încărcare. Împărțirea la 8 produce '+num(S['effort']/8)+' zile echivalente de lucru, nu o dată de predare. Exemplul de 8 ore/zi nu constituie o disponibilitate confirmată.')
for start in range(0,48,24):
    heading('6.1. CALCULUL TERMENELOR ȘI REZERVELOR'+(' — continuare' if start else ''))
    table(['Cod','te','ES','EF','LS','LF','RT','Critic'],[[r['code']]+[num(r[k]) for k in ['te','ES','EF','LS','LF','float']]+['DA' if r['critical'] else 'NU'] for r in R[start:start+24]],[1.2,2.1,2.3,2.3,2.3,2.3,2.3,1.2],9)
heading('7. CONCLUZII ȘI UTILIZAREA FIȘIERULUI EXCEL')
p('Planificarea leagă integral WBS-ul Licurici de o rețea cu 48 de activități, 78 de trasee și un singur drum critic de 1 133,33 ore. Ramura jocurilor și a conținutului, integrarea datelor, AI și verificarea finală influențează direct durata estimată. Efortul total este 1 536,67 ore-om; aceste valori nu trebuie confundate.')
p('Dependențele rezultă din livrabile. Analiza produselor și consultarea actorilor se reunesc înaintea definirii problemei; proiectarea interfeței și proiectarea API se reunesc la revizuire; modulele copilului și panourile adulților se reunesc la sincronizare. Lotul al doilea de jocuri urmează lotului inițial pentru reutilizarea mecanicilor verificate. Documentele finale consolidează materialul pregătit pe parcurs.')
p('Fișierul Excel conține foile Sinteza, PERT, WBS, Trasee și Retea. În PERT se modifică numai celulele albastre din coloanele E:G (O, M, P). Formulele recalculează mediile, varianțele, termenele, rezervele și criticitatea; verificarea O≤M≤P trebuie să fie OK. Codurile și dependențele definesc structura fixă a modelului: simpla editare a textului predecesorilor nu reconstruiește formulele.')
p('Diagramele grafice reprezintă estimarea inițială și trebuie regenerate dacă se schimbă datele sau structura. Tabelul din Retea și foile de calcul rămân sursa numerică. Pentru un calendar de execuție sunt necesare disponibilitatea reală și nivelarea resurselor; eventualele întârzieri de acces la participanți trebuie introduse separat.')
p('Surse: cerința laboratorului „Estimarea duratelor și planificarea activităților proiectului de licență prin metoda PERT”; materialul Canva indicat de coordonator; laboratorul 1 PECPIT al autorului și documentația README a proiectului Licurici. Fișierele Laborator_2_PECPIT_Leahovici_Iulia.pdf/.xlsx au servit exclusiv ca repere de formatare.')
p('Material de curs: https://www.canva.com/design/DAGW3aWkpuA/cI3-Fdx6ZeSmHTIuMDSe0Q/view',size=9)
for start in range(0,48,8):
    heading('ANEXA A. JUSTIFICAREA ESTIMĂRILOR ȘI DEPENDENȚELOR'+(' — continuare' if start else ''))
    table(['ID','Baza estimării O/M/P','Logica dependențelor'],[[r['code'],r['basis'],r['logic']] for r in R[start:start+8]],[1.3,7.85,7.85],10)
e=OxmlElement('w:updateStyles');e.set(qn('w:val'),'false');doc.settings.element.append(e)
out=ROOT/'output/docx/PECPIT_lab2_Mudrea_Mihail_Licurici.docx';out.parent.mkdir(parents=True,exist_ok=True);doc.save(out)
(TMP/'model.json').write_text(json.dumps(serializable(M),ensure_ascii=False,indent=2),encoding='utf-8')
print(out)
