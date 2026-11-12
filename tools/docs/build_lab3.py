"""Generate the requested Word laboratory using the supplied UTM writing rules."""
from pathlib import Path
import sys, re, json, zipfile, uuid
from docx import Document
from docx.shared import Cm, Pt
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.enum.section import WD_SECTION_START
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
import lab3_diagrams as dg
dg.main()

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/docx/Laborator_3_PSI_Mudrea_Mihail_Licurici.docx'
FONT='Times New Roman'
doc=Document()
next_page=False
sec=doc.sections[0]
sec.page_width=Cm(21);sec.page_height=Cm(29.7)
sec.top_margin=Cm(2);sec.bottom_margin=Cm(2);sec.left_margin=Cm(2);sec.right_margin=Cm(1)
sec.header_distance=Cm(0.8);sec.footer_distance=Cm(1)

def fonts(obj,size,bold=False):
    obj.font.name=FONT;obj.font.size=Pt(size);obj.font.bold=bold;obj.font.color.rgb=__import__('docx').shared.RGBColor(0,0,0)
    rp=obj._element.get_or_add_rPr()
    rf=rp.find(qn('w:rFonts'))
    if rf is None:rf=OxmlElement('w:rFonts');rp.insert(0,rf)
    for k in ('ascii','hAnsi','eastAsia','cs'):rf.set(qn('w:'+k),FONT)
    for k in list(rf.attrib):
        if 'Theme' in k:del rf.attrib[k]

for name in ['Normal','Body Text','Caption','Title','Heading 1','Heading 2','Heading 3','TOC 1','TOC 2','TOC 3']:
    if name not in doc.styles:
        from docx.enum.style import WD_STYLE_TYPE
        doc.styles.add_style(name,WD_STYLE_TYPE.PARAGRAPH)
    st=doc.styles[name];fonts(st,13 if name=='Heading 1' else 12,name.startswith('Heading'))
    pf=st.paragraph_format;pf.space_before=Pt(0);pf.space_after=Pt(0);pf.line_spacing=1.5
    pf.first_line_indent=Cm(1.25);pf.alignment=WD_ALIGN_PARAGRAPH.JUSTIFY
    if name.startswith('Heading'):
        pf.first_line_indent=Cm(0);pf.keep_with_next=True;pf.space_after=Pt(6)
        pf.alignment=WD_ALIGN_PARAGRAPH.CENTER if name=='Heading 1' else WD_ALIGN_PARAGRAPH.LEFT
    if name.startswith('TOC'):
        pf.line_spacing=1;pf.first_line_indent=Cm(0);pf.space_after=Pt(4)
    if name in ['Title','Caption']:pf.first_line_indent=Cm(0)

# The bundled Word template may carry a decorative blue border on Title.
# The supplied UTM rules require a plain page, so strip inherited paragraph rules.
for st in doc.styles:
    for border in list(st.element.iter(qn('w:pBdr'))):
        border.getparent().remove(border)

settings=doc.settings.element
lang=OxmlElement('w:themeFontLang');lang.set(qn('w:val'),'ro-RO');settings.append(lang)
update=OxmlElement('w:updateFields');update.set(qn('w:val'),'true');settings.append(update)
doc.core_properties.author='Mudrea Mihail'
doc.core_properties.title='Laborator 3 — Modelarea procesului educativ Licurici'
doc.core_properties.subject='Proiectarea sistemelor informaționale — IDEF0, IDEF3 și DFD'
doc.core_properties.keywords='Licurici, IDEF0, IDEF3, DFD, TI-233'

def text(t,bold=False,style=None,align=None,indent=True):
    global next_page
    p=doc.add_paragraph(style=style)
    if next_page:p.paragraph_format.page_break_before=True;next_page=False
    if align is not None:p.alignment=align
    if not indent:p.paragraph_format.first_line_indent=Cm(0)
    # **...** marks semantic emphasis only, never changes font or size.
    for i,chunk in enumerate(re.split(r'\*\*(.*?)\*\*',t)):
        if chunk: r=p.add_run(chunk);fonts(r,12,bold or i%2==1)
    return p

def h(t,level=2,new=False):
    global next_page
    if new:page()
    p=doc.add_paragraph(t,style='Heading '+str(level))
    if next_page:p.paragraph_format.page_break_before=True;next_page=False
    if t=='CUPRINS':
        p.style=doc.styles['Normal'];p.alignment=WD_ALIGN_PARAGRAPH.CENTER;p.paragraph_format.first_line_indent=Cm(0)
        p.paragraph_format.space_after=Pt(6)
        for r in p.runs:fonts(r,13,True)
    return p
def page():
    global next_page
    next_page=True
def paras(*xs):
    for x in xs:text(x)
def bullets(xs):
    for i,s in enumerate(xs):
        s=s.rstrip('; .')+('.' if i==len(xs)-1 else ';')
        p=text('– '+s,indent=False);p.paragraph_format.left_indent=Cm(1.25);p.paragraph_format.first_line_indent=Cm(-0.5)
def cap(t,table=False):
    p=text(t,bold=not table,align=WD_ALIGN_PARAGRAPH.RIGHT if table else WD_ALIGN_PARAGRAPH.CENTER,indent=False)
    p.paragraph_format.line_spacing=1;p.paragraph_format.space_before=Pt(4);p.paragraph_format.space_after=Pt(5)
    p.paragraph_format.keep_with_next=table
    return p
def table(headers,rows,widths=None):
    t=doc.add_table(rows=1,cols=len(headers));t.alignment=WD_TABLE_ALIGNMENT.CENTER;t.autofit=False
    widths=widths or [18/len(headers)]*len(headers)
    for j,w in enumerate(widths):t.columns[j].width=Cm(w)
    pr=t._tbl.tblPr
    borders=OxmlElement('w:tblBorders')
    for edge in ['top','left','bottom','right','insideH','insideV']:
        e=OxmlElement('w:'+edge);e.set(qn('w:val'),'single');e.set(qn('w:sz'),'4');e.set(qn('w:color'),'777777');borders.append(e)
    pr.append(borders)
    margins=OxmlElement('w:tblCellMar')
    for edge,value in [('top',45),('bottom',45),('left',65),('right',65)]:
        e=OxmlElement('w:'+edge);e.set(qn('w:w'),str(value));e.set(qn('w:type'),'dxa');margins.append(e)
    pr.append(margins)
    for i,vals in enumerate([headers]+list(rows)):
        row=t.rows[0] if i==0 else t.add_row()
        cant=OxmlElement('w:cantSplit');row._tr.get_or_add_trPr().append(cant)
        if i==0:
            rep=OxmlElement('w:tblHeader');row._tr.get_or_add_trPr().append(rep)
        for j,v in enumerate(vals):
            c=row.cells[j];c.width=Cm(widths[j]);c.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
            if i==0:
                sh=OxmlElement('w:shd');sh.set(qn('w:fill'),'E7E6E6');c._tc.get_or_add_tcPr().append(sh)
            p=c.paragraphs[0];p.paragraph_format.first_line_indent=Cm(0);p.paragraph_format.line_spacing=1
            p.paragraph_format.space_before=Pt(0);p.paragraph_format.space_after=Pt(0)
            p.alignment=WD_ALIGN_PARAGRAPH.CENTER if i==0 else WD_ALIGN_PARAGRAPH.LEFT
            r=p.add_run(str(v));fonts(r,11,i==0)
    return t
def figure(name,title):
    global next_page
    p=doc.add_paragraph();p.paragraph_format.first_line_indent=Cm(0);p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    if next_page:p.paragraph_format.page_break_before=True;next_page=False
    p.paragraph_format.line_spacing=1;p.paragraph_format.keep_with_next=True
    pic=p.add_run().add_picture(str(dg.OUT/(name+'.png')),width=Cm(18))
    pic._inline.docPr.set('descr',title)
    cap(title)
def icom_table(num,functions,title):
    cap(f'Tabelul {num} – {title}',True)
    table(['Funcția','Intrări (I)','Controale (C)','Ieșiri (O)','Mecanisme (M)'],
      [[f['code']+' '+f['name']]+['; '.join(f[k]) for k in ('I','C','O','M')] for f in functions],[6.1,2.8,3.1,2.8,3.2])

# Cover preserves the supplied institutional identity; the user confirmed all details.
for s in ['MINISTERUL EDUCAȚIEI ȘI CERCETĂRII AL REPUBLICII MOLDOVA','Universitatea Tehnică a Moldovei','Facultatea Calculatoare, Informatică și Microelectronică','Departamentul Ingineria Software și Automatică']:
    p=text(s,True,align=WD_ALIGN_PARAGRAPH.CENTER,indent=False);p.paragraph_format.line_spacing=1.15
p=text('Dezvoltarea unui sistem informatic pentru activități educative adaptate copiilor',True,style='Title',align=WD_ALIGN_PARAGRAPH.CENTER,indent=False)
p.paragraph_format.space_before=Pt(110);p.paragraph_format.line_spacing=1.15
for r in p.runs:fonts(r,16,True)
p=text('Laborator 3: Modelarea și analiza procesului de gestionare a sesiunilor educative și a progresului copilului în Licurici prin notațiile IDEF0, IDEF3 și DFD',True,align=WD_ALIGN_PARAGRAPH.CENTER,indent=False)
p.paragraph_format.space_before=Pt(8);p.paragraph_format.line_spacing=1.15
for r in p.runs:fonts(r,14,True)
p=text('Student:              _____________  Mudrea Mihail, TI-233',True,indent=False);p.paragraph_format.left_indent=Cm(4);p.paragraph_format.space_before=Pt(100)
p=text('Coordonator:       _____________  Cojocaru Svetlana',True,indent=False);p.paragraph_format.left_indent=Cm(4);p.paragraph_format.space_before=Pt(10)
p=text('Chișinău, 2026',True,align=WD_ALIGN_PARAGRAPH.CENTER,indent=False);p.paragraph_format.space_before=Pt(115)

page();h('CUPRINS',1)
p=doc.add_paragraph();p.paragraph_format.first_line_indent=Cm(0)
r=p.add_run();begin=OxmlElement('w:fldChar');begin.set(qn('w:fldCharType'),'begin');r._r.append(begin)
inst=OxmlElement('w:instrText');inst.set(qn('xml:space'),'preserve');inst.text=' TOC \\o "1-2" \\h \\z \\u ';r._r.append(inst)
sep=OxmlElement('w:fldChar');sep.set(qn('w:fldCharType'),'separate');r._r.append(sep)
r=p.add_run('Cuprinsul se actualizează automat în Microsoft Word.');fonts(r,12)
r=p.add_run();end=OxmlElement('w:fldChar');end.set(qn('w:fldCharType'),'end');r._r.append(end)

page();h('LISTA DE ABREVIERI ȘI DEFINIȚII',1)
abbrevs=[('ADR','Architecture Decision Record – documentarea unei decizii arhitecturale.'),('API','Application Programming Interface – interfață de comunicare între componente software.'),('BPwin','Denumirea anterioară a instrumentului AllFusion Process Modeler.'),('DFD','Data Flow Diagram – diagramă a fluxurilor de date.'),('Flutter','Cadru software utilizat pentru aplicația copilului și panoul adulților.'),('ICOM','Input, Control, Output, Mechanism – intrare, control, ieșire și mecanism.'),('IDEF0','Integration Definition for Function Modeling – metodă de modelare funcțională.'),('IDEF3','Process Description Capture Method – metodă de descriere a scenariilor de proces.'),('KPI','Key Performance Indicator – indicator de performanță.'),('LWW','Last Write Wins – rezolvarea conflictelor prin păstrarea valorii cu data mai recentă.'),('NestJS','Cadru software al serviciilor de pe server.'),('offline-first','Principiu prin care funcțiile principale rămân disponibile fără internet.'),('outbox','Evidența locală a înregistrărilor care așteaptă confirmarea sincronizării.'),('PostgreSQL','Sistem relațional de gestiune a bazei de date a serverului.'),('Redis / BullMQ','Infrastructură pentru stocare temporară și procesarea lucrărilor în cozi.'),('UML','Unified Modeling Language – limbaj unificat de modelare.'),('UOB','Unit of Behavior – unitate de lucru a unei diagrame IDEF3.'),('UUID','Universally Unique Identifier – identificator utilizat pentru evitarea dublurilor.'),('worker','Proces care execută lucrări din coadă în afara cererii interactive.')]
for a,b in abbrevs:
    p=text('**'+a+'** – '+b,indent=False);p.paragraph_format.line_spacing=1.5;p.paragraph_format.space_after=Pt(0)
for a,b in [('backend','serviciile aplicației executate pe server.'),('feedback','răspunsul aplicației la acțiunea copilului.'),('FIPS PUB','Federal Information Processing Standards Publication – publicație a standardelor federale de prelucrare a informației.'),('ID','identificator al unui element din model.')]:
    text('**'+a+'** – '+b,indent=False)

# The front matter is counted, but only the main text has a visible page field.
sec=doc.add_section(WD_SECTION_START.NEW_PAGE);sec.footer.is_linked_to_previous=False
p=sec.footer.paragraphs[0];p.alignment=WD_ALIGN_PARAGRAPH.CENTER;p.paragraph_format.first_line_indent=Cm(0)
r=p.add_run();fonts(r,12);fld=OxmlElement('w:fldSimple');fld.set(qn('w:instr'),'PAGE');r._r.addnext(fld)
h('INTRODUCERE',1)
paras(
'Licurici este un sistem informatic pentru activități educative adaptate copiilor. Aplicația copilului permite desfășurarea jocurilor și păstrarea rezultatelor pe dispozitiv, iar panoul destinat adulților permite configurarea activităților și urmărirea progresului. Documentația proiectului și implementarea existentă constituie baza delimitării procesului analizat [1].',
'Procesul selectat este „Gestionarea sesiunilor educative și a progresului copilului”. Acesta cuprinde configurarea profilului și a planului, pregătirea activităților, desfășurarea sesiunii și valorificarea rezultatelor. Alegerea permite urmărirea aceleiași informații de la interacțiunea copilului până la raportul consultat de adult. Autentificarea contului adultului constituie o condiție pentru operațiile la distanță, nu procesul principal al lucrării.',
'Scopul laboratorului este construirea unor reprezentări coerente ale funcțiilor, ale succesiunii activităților și ale circulației datelor. Notația IDEF0 delimitează funcțiile și resursele lor, IDEF3 descrie un scenariu de desfășurare, iar DFD evidențiază transformările și depozitele de date. Modelele trebuie să explice atât lucrul fără internet, cât și sincronizarea opțională, fără a condiționa activitatea copilului de disponibilitatea serverului.',
'Obiectivele lucrării sunt următoarele:')
bullets(['delimitarea procesului, a participanților și a rezultatelor observabile','construirea diagramei de context și a două niveluri de decompoziție funcțională','descrierea unui scenariu de sesiune cu ramificări și reveniri explicite','reprezentarea depozitelor locale și centrale prin diagrame ale fluxurilor de date','verificarea echilibrării interfețelor și a corespondenței dintre cele trei modele'])
paras('Modelul descrie arhitectura de referință Flutter și NestJS documentată în proiect. Varianta demonstrativă găzduită separat nu este confundată cu infrastructura completă. Denumirile funcțiilor sunt comune diagramelor și tabelelor, iar detaliile tehnice sunt introduse numai când explică o responsabilitate sau o limită a procesului.',
'Rezultatul urmărit este o bază verificabilă pentru proiectarea funcționalităților și a testelor. Lucrarea nu atribuie aplicației eficacitate clinică demonstrată și nu substituie evaluarea unui specialist. Progresul prezentat reprezintă indicatori ai activității în aplicație, interpretați de adult în contextul copilului.')

page();h('1 DESCRIEREA PROCESULUI MODELAT',1);h('1.1 Alegerea procesului')
paras(
'Pentru modelare a fost ales procesul „Gestionarea sesiunilor educative și a progresului copilului”. Punctul de pornire îl constituie configurarea activităților potrivite copilului, iar rezultatul este o sesiune păstrată local și un progres care poate fi consultat de persoanele autorizate. Delimitarea urmărește activitatea educativă efectivă, nu o operație auxiliară precum intrarea în cont sau schimbarea parolei.',
'Procesul are patru funcții majore: configurarea profilului și a planului, pregătirea activităților educative, desfășurarea sesiunii și sincronizarea împreună cu monitorizarea progresului. Prima funcție stabilește cadrul de lucru. A doua transformă configurația și istoricul în activități pregătite. A treia produce răspunsuri observabile și o înregistrare a sesiunii. Ultima valorifică înregistrarea, local sau prin serviciile de pe server.',
'Această structură permite două niveluri de decompoziție sub context: patru funcții în diagrama A0 și paisprezece subfuncții în diagramele A1–A4. Numărul de blocuri nu rezultă din împărțirea arbitrară a interfeței în ecrane. Fiecare bloc are o transformare distinctă, intrări identificabile și un rezultat care poate fi utilizat de altă funcție sau furnizat participantului.',
'Sesiunea reprezintă unitatea de lucru care leagă mai multe jocuri și încercări. În implementare, aceasta se deschide la începutul activității și se încheie la comanda „Gata pe azi”; salvările intermediare protejează rezultatele deja obținute. Identificatorul sesiunii se păstrează la retransmitere. În consecință, numărul transmiterilor nu trebuie confundat cu numărul sesiunilor educative [1].',
'Frontiera procesului include aplicația copilului, stocarea locală, panoul adulților și serviciile care păstrează și prelucrează sesiunile sincronizate. Copilul, părintele și specialistul autorizat sunt participanți exteriori sistemului informatic. Aceleași persoane apar drept mecanisme în modelul funcțional, deoarece contribuie la executarea activităților; în DFD apar ca surse și destinatari de date.',
'Sunt excluse din acest laborator administrarea infrastructurii, distribuirea aplicației, realizarea ilustrațiilor și procedurile complete de export sau ștergere a contului. Aceste funcții există în contextul mai larg al proiectului, dar includerea lor ar amesteca procese cu scopuri diferite. Reglementările interne privind accesul și consimțământul rămân controale ale procesului selectat.',
'Modelarea este orientată către verificare. Se poate urmări dacă răspunsul copilului produce feedback, dacă înregistrarea ajunge în stocarea locală și dacă un raport este calculat din date disponibile. Acest traseu oferă un criteriu concret pentru identificarea fluxurilor lipsă și a responsabilităților suprapuse.')

page();h('1.2 Aria de activitate')
paras(
'Aria de activitate este sprijinirea exercițiilor educative individualizate, desfășurate pe dispozitivul copilului și urmărite de un adult. Sistemul oferă jocuri organizate pe arii de dezvoltare și permite adaptarea selecției, a dificultății și a prezentării. Activitatea se poate desfășura acasă sau într-un cadru educațional, fără ca aplicația să stabilească singură un diagnostic sau un plan clinic.',
'Copilul interacționează cu ecranul de joc, ascultă instrucțiunile și răspunde prin gesturile prevăzute de mecanica activității. Acesta nu are nevoie de un cont propriu pentru utilizarea locală. Aplicația copilului funcționează în orientare orizontală și prezintă o singură sarcină principală pe ecran. Feedbackul trebuie să rămână blând, iar preferințele senzoriale influențează sunetul și mișcarea.',
'Părintele configurează utilizarea locală și decide dacă sesiunile pot fi trimise către server. Rolul său include administrarea profilului copilului și acordarea accesului unui specialist. Consimțământul pentru sincronizare este separat de simpla existență a unui cont. Retragerea sau absența acestuia nu transformă jocul local într-o funcție indisponibilă.',
'Specialistul autorizat consultă informațiile copilului partajat și poate ajusta planul în limitele implementate. Nu se presupune că orice specialist are acces la orice profil. În arhitectura de referință, accesul este verificat pentru copilul vizat, iar modificarea planului este înregistrată. Diferența dintre citirea statisticilor și modificarea datelor copilului trebuie păstrată în descrierea responsabilităților [1].',
'Aplicația pregătește stimulii vizuali și vocea înaintea rundei, primește răspunsurile și păstrează încercările. La sfârșit, înregistrarea sesiunii este scrisă local. Progresul folosit la recomandarea activităților următoare se poate calcula din istoricul dispozitivului. Aceste operații formează partea independentă de conectivitate a procesului.',
'Panoul și serviciile de pe server deservesc partea la distanță. Serverul validează datele și drepturile, păstrează sesiunile și permite consultarea lor. Prelucrarea în coadă actualizează statisticile derivate. Raportul afișat unui adult nu trebuie să presupună că toate dispozitivele au transmis deja toate sesiunile; acesta reflectă datele disponibile la momentul consultării.',
'Aria modelată cuprinde trei situații operaționale: utilizarea exclusiv locală, utilizarea conectată cu sincronizare autorizată și utilizarea temporar deconectată după activarea sincronizării. În ultima situație, înregistrările rămân pe dispozitiv până la o încercare ulterioară. O problemă de rețea nu trebuie să devină un mesaj de eșec adresat copilului.',
'Separarea acestor situații justifică reprezentarea distinctă a depozitului local și a celui central. Ele pot conține aceeași sesiune, identificată prin același UUID, fără ca aceasta să reprezinte două activități diferite. Monitorizarea urmărește rezultatul educativ și starea transferului ca informații distincte.')

page();h('1.3 Obiectivele procesului')
paras(
'Obiectivul principal este desfășurarea unei sesiuni educative coerente, adaptate configurației copilului, ale cărei rezultate pot fi păstrate și interpretate. Procesul trebuie să asigure continuitatea dintre planul ales de adult, activitatea efectivă și indicatorii prezentați după sesiune. Fiecare obiectiv se raportează la un rezultat observabil, nu doar la existența unui ecran.',
'Personalizarea urmărește disponibilitatea jocurilor potrivite, limite de dificultate explicite și respectarea preferințelor senzoriale. Un nivel de pornire nu poate depăși plafonul stabilit pentru același joc. Imaginile excluse trebuie să rămână excluse la generarea activității. Configurația devine astfel o condiție a pregătirii și a prezentării, nu o simplă etichetă a profilului.',
'Continuitatea activității urmărește posibilitatea de a juca fără internet. Instrucțiunile și stimulii necesari activităților incluse sunt pregătiți din resursele aplicației. Rezultatele se păstrează mai întâi pe dispozitiv. Disponibilitatea serverului influențează consultarea la distanță, însă nu stabilește dacă un copil poate termina o rundă deja pregătită.',
'Calitatea feedbackului urmărește sprijinirea învățării fără pedeapsă. Un răspuns care necesită corectare conduce la un indiciu și la posibilitatea reluării. Un răspuns reușit primește confirmarea potrivită. Modul calm și preferința de reducere a mișcării trebuie să se aplice și reacțiilor vizuale, nu numai fundalului ecranului.',
'Integritatea datelor urmărește păstrarea încercărilor relevante, a ordinii lor și a identificatorului sesiunii. Retrimiterea unei înregistrări nu trebuie să genereze dubluri pe server. Starea „trimis” se aplică local numai după confirmarea cererii. Dacă răspunsul serverului nu ajunge la dispozitiv, o nouă încercare trebuie să poată fi făcută în siguranță.',
'Monitorizarea urmărește prezentarea unor indicatori calculați din activitate: încercări, reușite independente, nivel de ajutor și timpi de răspuns disponibili. Acești indicatori sprijină decizia adultului privind activitățile ulterioare. Interpretarea lor nu se extinde automat la capacitățile copilului în toate mediile și nu demonstrează singură eficacitatea unei intervenții.',
'Criteriile de verificare ale procesului sunt următoarele:')
bullets(['configurația validată determină activitățile disponibile pe dispozitiv','fiecare rundă încheiată produce feedback și informațiile prevăzute pentru înregistrare','încheierea unei sesiuni cu activitate produce o înregistrare locală','retransmiterea aceleiași sesiuni păstrează un singur identificator pe server','vizualizarea la distanță se limitează la copilul pentru care adultul este autorizat'])
paras('Aceste criterii sunt folosite la citirea diagramelor: un rezultat fără sursă indică un flux incomplet, iar o activitate fără ieșire nu contribuie demonstrabil la scopul procesului. Verificarea modelelor precedă formularea scenariilor de testare.')

page();h('1.4 Importanța procesului')
paras(
'Procesul este important deoarece concentrează funcția educativă a aplicației și legătura dintre activitatea copilului și decizia adultului. O interfață plăcută nu este suficientă dacă planul nu este aplicat, dacă rezultatele dispar sau dacă raportul prezintă date duplicate. Modelarea urmărește aceste legături înainte de evaluarea detaliilor de implementare.',
'Pentru copil, continuitatea și previzibilitatea sunt esențiale. Instrucțiunea, stimulul și gestul așteptat trebuie să formeze o sarcină coerentă. Așteptarea unei conexiuni sau afișarea unei erori tehnice în mijlocul activității poate întrerupe concentrarea. Separarea jocului local de sincronizare limitează propagarea problemelor de infrastructură către experiența de învățare.',
'Pentru părinte, importanța procesului constă în controlul configurației și al transmiterii datelor. Părintele trebuie să poată distinge între încheierea jocului, salvarea rezultatului și apariția lui în panou. Cele trei momente nu sunt echivalente. O sesiune salvată local rămâne utilă chiar dacă transferul ei este amânat.',
'Pentru specialist, valoarea principală este trasabilitatea. Planul aplicat, nivelul de dificultate, tipul de ajutor și rezultatul încercărilor oferă context pentru interpretarea progresului. Compararea unor sesiuni fără a ține cont de schimbarea configurației poate conduce la concluzii nejustificate. De aceea, monitorizarea și configurarea sunt funcții distincte, dar legate prin datele procesului.',
'Pentru implementare, modelul separă datele de bază de datele derivate. Înregistrarea sesiunii reprezintă sursa pentru statistici, iar statisticile pot fi recalculate. O indisponibilitate temporară a cozii de prelucrare nu trebuie interpretată ca pierderea unei sesiuni deja acceptate. Această distincție apare în funcția A4 și explică rolul serviciilor de procesare [1].',
'Riscurile analizate sunt pierderea unei înregistrări, numărarea ei de mai multe ori, aplicarea unei configurații nepotrivite și expunerea rezultatelor unei persoane neautorizate. Pentru fiecare risc există un punct de control: salvarea locală, identificarea stabilă a sesiunii, validarea planului și verificarea accesului. Diagramele permit verificarea poziționării acestor controale.',
'Modelarea contribuie și la delimitarea promisiunilor sistemului. Aplicația poate consemna comportamentul în propriile activități, dar nu poate deduce automat un diagnostic. Un indicator de reușită nu înlocuiește evaluarea în contexte diferite. Descrierea procesului păstrează această limită prin utilizarea termenilor „activitate”, „încercare” și „progres în aplicație”.',
'Rezultatele laboratorului sunt utile pentru definirea interfețelor dintre componente, pentru alegerea datelor păstrate și pentru elaborarea testelor. Concordanța dintre modele reduce ambiguitatea: aceeași sesiune apare ca ieșire a unei funcții, ca rezultat al unui scenariu și ca flux către un depozit. Astfel, documentarea poate fi confruntată cu implementarea, nu doar citită separat de aceasta.')

page();h('1.5 Elementele procesului')
paras('Elementele externe ale procesului sunt reunite în tabelul 1.1. Codurile sunt etichete scurte folosite pe săgețile diagramelor pentru a păstra lizibilitatea; denumirea și sensul lor nu se schimbă între niveluri. Un flux poate fi ramificat către mai multe funcții fără a deveni o intrare nouă.',
'Datele de profil se limitează la informațiile necesare funcționării aplicației. Regulile de acces și consimțământ sunt modelate ca restricții ale operațiilor la distanță. În acest laborator ele descriu comportamentul implementat, fără a constitui o evaluare juridică a întregului produs.')
cap('Tabelul 1.1 – Intrările, controalele, ieșirile și mecanismele procesului',True)
meaning={
'I1':'Poreclă, avatar și opțiuni de configurare necesare activității.', 'I2':'Selecția jocurilor, nivelurile și limitele stabilite de adult.', 'I3':'Pornire, răspunsuri în joc și încheierea sesiunii.',
'C1':'Validarea planului, generarea rundelor și calcularea progresului.', 'C2':'Prezentare, voce, mișcare redusă și feedback blând.', 'C3':'Drepturi asupra profilului și acord pentru operațiile la distanță.',
'O1':'Confirmări, indicii și recompense prezentate copilului.', 'O2':'Înregistrarea păstrată pe dispozitiv, disponibilă fără internet.', 'O3':'Indicatori locali și informații consultate de adulții autorizați.', 'O4':'Confirmarea transferului sau păstrarea sesiunii în așteptare.',
'M1':'Configurează și interpretează rezultatele în limitele drepturilor.', 'M2':'Participă la activități și furnizează răspunsuri.', 'M3':'Execută jocurile și păstrează configurația și sesiunile.', 'M4':'Validează, păstrează și prezintă datele sincronizate.'}
table(['Cod','Elementul','Semnificația'],[[k,dg.LABELS[k],v] for k,v in meaning.items()],[1.4,6.4,10.2])
paras('Fluxurile interne principale sunt F1 „Profil configurat”, F2 „Plan configurat”, F3 „Activități pregătite” și F4 „Istoric și progres local”. F2 controlează pregătirea activităților, deoarece stabilește limitele selecției; F4 este intrare deoarece este prelucrat pentru construirea contextului următoarei activități.',
'Codurile locale L11–L43 denumesc rezultate intermediare numai în diagramele-copil. Sensul lor este precizat lângă tabelul funcțiilor respective. Ele nu modifică interfața externă din tabelul 1.1.')

page();h('2 MODELAREA FUNCȚIONALĂ A PROCESULUI ÎN NOTAȚIA IDEF0',1);h('2.1 Regulile notației IDEF0')
paras('IDEF0 este o metodă de modelare funcțională definită prin FIPS PUB 183. Funcțiile sunt reprezentate prin blocuri, iar săgețile exprimă informațiile sau resursele implicate. Intrările ajung în stânga, controalele sus, ieșirile pleacă din dreapta, iar mecanismele intră de jos [2]. Această distribuție permite deosebirea datelor transformate de regulile care constrâng transformarea.',
'Diagrama A-0 reprezintă contextul și conține un singur bloc, identificat cu numărul 0. Diagrama A0 descompune această funcție în blocurile 1–4, ale căror adrese complete sunt A1–A4. Diagrama A1 detaliază prima funcție, prin blocurile cu adresele A11–A13. În cadrul fiecărei diagrame sunt afișate numerele locale, iar tabelele folosesc adresele complete pentru eliminarea ambiguității.',
'Regulile aplicate în lucrare sunt următoarele:')
bullets(['denumirea fiecărei funcții exprimă o activitate și rezultatul ei urmărit','o decompoziție conține între trei și șase funcții','fiecare bloc are cel puțin un control și o ieșire','intrările și mecanismele sunt adăugate acolo unde sunt necesare activității','săgețile interfeței copilului corespund celor ale blocului-părinte','săgețile interne sunt denumite și conectează funcții ale aceleiași decompoziții'])
paras('Modelul Licurici utilizează toate cele patru categorii ICOM pentru fiecare bloc. Acest lucru rezultă din analiza funcțiilor concrete; nu se afirmă că orice model IDEF0 trebuie să aibă obligatoriu o intrare și un mecanism la fiecare funcție. Un cod repetat pe margine reprezintă ramificarea aceluiași flux. Intersecțiile de linii fără punct de conexiune nu indică o unire.',
'Echilibrarea este verificată prin compararea mulțimilor de intrări, controale, ieșiri și mecanisme ale părintelui cu interfața diagramei-copil. Rezultatele intermediare produse și consumate în interior nu se adaugă la această interfață. De exemplu, „Plan propus” aparține numai decompoziției A1, în timp ce „Plan configurat” trebuie să apară și la ieșirea funcției A1 din A0.',
'Poziționarea în diagonală exprimă organizarea funcțiilor, nu un program de execuție obligatoriu. În special, legătura de la monitorizare spre pregătire reprezintă folosirea istoricului la activitățile următoare. O sesiune nu așteaptă finalizarea statisticilor pe server pentru a putea începe. Ordinea operațională este detaliată separat în modelul IDEF3.',
'Cadrul diagramelor păstrează convenția modelului de referință: autor, proiect, dată și stare în antet, respectiv nod, titlu și număr în subsol. Acest cadru aparține figurii, nu paginii documentului.')

page();h('2.2 Diagrama de context A-0')
paras('Diagrama de context din figura 2.1 fixează frontiera procesului „Gestionarea sesiunilor educative și a progresului copilului”. Sunt reprezentate trei intrări, trei controale, patru ieșiri și patru mecanisme, cu semnificațiile stabilite în tabelul 1.1. Contextul include atât utilizarea locală, cât și partea opțională de sincronizare.',
'Scopul modelului este descrierea pregătirii, desfășurării, salvării și monitorizării sesiunilor. Punctul de vedere este cel al părintelui și al specialistului autorizat, interesați de activitățile oferite copilului și de interpretarea rezultatelor. Dispozitivul și serviciile de pe server sunt resurse ale procesului, nu persoane responsabile de decizia educativă.')
figure('context','Figura 2.1 – Diagrama de context A-0')
paras('Ieșirea O2 „Sesiune salvată local” este independentă de confirmarea transferului O4. Separarea împiedică interpretarea greșită a unei lipse de conexiune drept pierdere a sesiunii. O3 cuprinde progresul calculat local și rapoartele disponibile persoanelor autorizate, în funcție de datele efectiv accesibile.',
'Datele de profil și obiectivele sunt transformate în configurație, iar comenzile și răspunsurile sunt transformate în activitate înregistrată. Regulile educative, senzoriale și de acces ghidează aceste transformări. Niciun serviciu extern de inteligență artificială nu este obligatoriu pentru obținerea ieșirilor prezentate.')

page();h('2.3 Diagrama de decompoziție A0')
paras('Funcția generală este descompusă în cele patru funcții din figura 2.2. Interfața externă păstrează codurile din A-0. F1 și F2 leagă configurarea de pregătire, F3 leagă pregătirea de desfășurare, iar O2 este atât rezultat extern, cât și intrare în monitorizare.')
figure('A0','Figura 2.2 – Diagrama de decompoziție A0')
text('Tabelul 2.1 precizează interfața fiecărei funcții; codurile externe sunt definite în tabelul 1.1, iar F1–F4 în subcapitolul 1.5.')
icom_table('2.1',dg.FUNCTIONS,'Funcțiile diagramei A0')
paras('F4 revine din A4 în A2 pentru pregătirea activităților următoare. Inițial, istoricul poate fi gol. C3 controlează configurarea și monitorizarea; activitatea locală a copilului nu cere autentificare și nu așteaptă un raport pe server.')

details={
'A1':('2.4 Decompoziția funcției A1 „Configurarea profilului și a planului”','2.3','2.2',
'Configurarea separă introducerea profilului de alegerea activităților și de validarea configurației. Figura 2.3 prezintă această decompoziție, iar tabelul 2.2 precizează fluxurile fiecărui bloc. Adultul furnizează datele și obiectivele, în limitele drepturilor disponibile.',
'L11 este „Profil introdus”, iar L12 este „Plan propus”. A13 validează combinația lor și produce F1 „Profil configurat” și F2 „Plan configurat”. Profilul introdus se ramifică spre A12 și A13, astfel încât validarea nu pierde legătura dintre plan și copil.',
'Validarea verifică, între altele, limitele nivelurilor și ale rundelor. În implementarea de referință, nivelul de pornire al unui joc nu poate depăși plafonul său. Modificarea planului la distanță este verificată și înregistrată; profilul copilului nu primește câmpuri noi doar pentru a simplifica modelul [1].'),
'A2':('2.5 Decompoziția funcției A2 „Pregătirea activităților educative”','2.4','2.3',
'Pregătirea transformă profilul și istoricul în activități care pot fi executate pe dispozitiv. Figura 2.4 urmărește construirea contextului, selectarea activităților și încărcarea resurselor. Tabelul 2.3 separă datele prelucrate de planul care limitează selecția.',
'L21 înseamnă „Context de învățare”, iar L22 „Activități selectate”. Contextul combină profilul configurat cu istoricul și progresul local. Selectarea respectă regulile educative C1 și planul F2; încărcarea stimulilor și a vocii respectă regulile senzoriale C2 și restricțiile aceluiași plan.',
'Dacă istoricul lipsește, se folosesc valorile inițiale disponibile. Dacă un joc este exclus, acesta nu devine activitate pregătită doar pentru că figurează în catalog. Ieșirea F3 desemnează activități cu resursele necesare disponibile, nu o solicitare de descărcare obligatorie de la server.'),
'A3':('2.6 Decompoziția funcției A3 „Desfășurarea sesiunii educative”','2.5','2.4',
'Desfășurarea sesiunii include inițierea, rundele de joc, încheierea și salvarea locală. Figura 2.5 prezintă funcțiile, iar tabelul 2.4 indică interfețele lor. Comenzile și răspunsurile I3 se ramifică spre activitățile în care copilul intervine efectiv.',
'L31 este „Sesiune inițiată”, L32 „Încercări înregistrate”, iar L33 „Înregistrare încheiată”. A32 produce O1 „Feedback și recompense” pe parcursul activității. A34 produce O2 numai după scrierea în stocarea locală. Salvările intermediare folosesc aceeași responsabilitate de persistență, cu identificatorul sesiunii păstrat.',
'La „Gata pe azi”, o sesiune care conține activitate poate fi încheiată și salvată. Încercările și ajutorul utilizat sunt păstrate conform mecanicii jocului. O sesiune fără activitate nu este inventată pentru completarea raportului. Succesiunea unui scenariu cu răspuns reluat este detaliată în subcapitolul 3.2.'),
'A4':('2.7 Decompoziția funcției A4 „Sincronizarea și monitorizarea progresului”','2.6','2.5',
'Monitorizarea începe cu datele deja salvate local, nu cu un răspuns al serverului. Figura 2.6 separă calcularea locală, sincronizarea, actualizarea statisticilor centrale și prezentarea rezultatelor. Interfețele sunt precizate în tabelul 2.5.',
'L41 este „Sesiune și indicatori”, L42 „Sesiuni confirmate”, iar L43 „Statistici pe server”. F4 păstrează istoricul și progresul local pentru pregătirea următoarelor activități. Prezentarea O3 poate utiliza date locale sau centrale, după context; diagrama funcțională nu impune așteptarea simultană a ambelor surse.',
'A42 cere acord și autorizare. Fără confirmare, sesiunea rămâne în așteptare; retransmiterea nu produce dubluri. Acceptarea sesiunii și recalcularea statisticilor sunt distincte: indisponibilitatea cozii nu anulează datele păstrate [1].')}
for node,(title,fig,tab,intro,flows,endtext) in details.items():
    page();h(title);text(intro)
    figure(node,f'Figura {fig} – Decompoziția funcției {node}')
    icom_table(tab,dg.CHILDREN[node],f'Funcțiile diagramei {node}')
    paras(flows,endtext)

page();h('3 MODELAREA SCENARIULUI PROCESULUI ÎN NOTAȚIA IDEF3',1);h('3.1 Regulile notației IDEF3')
paras('IDEF3 descrie scenarii de desfășurare prin unități de lucru, legături și joncțiuni. Modelul arată cum se succed activitățile și în ce condiții se alege o ramură. El poate descrie procese existente sau propuse, cu un domeniu al scenariului declarat explicit [3]. În această lucrare este detaliată funcția A3 din modelul funcțional.',
'O unitate de lucru UOB are o denumire de activitate și un identificator. Legătura de precedență stabilește că activitatea sursă se încheie înainte de începerea activității destinație. Fluxul de obiect indică transmiterea unui obiect produs către activitatea care îl utilizează. Relațiile punctate precizează legături suplimentare, explicate în textul scenariului [3].',
'Joncțiunile se interpretează în funcție de sensul lor. O ramificare X activează o singură ramură alternativă, iar o unire X primește ramura care s-a executat. O ramificare ȘI ar activa toate ramurile; o unire ȘI ar aștepta încheierea tuturor. Alegerea simbolului trebuie să reflecte comportamentul procesului, nu dorința de a include cât mai multe simboluri într-o diagramă.',
'În scenariul Licurici sunt necesare alegeri exclusive: un răspuns conduce fie la confirmare, fie la sprijin pentru reluare; după înregistrare, sesiunea continuă sau se încheie. Nu există în acest scenariu o cerință ca două activități să înceapă exact simultan. Prin urmare, nu se introduc joncțiuni ȘI sincrone fără o justificare în comportamentul analizat.',
'Bucla de reluare trece printr-o unire explicită înaintea prezentării rundei. Această convenție evită ambiguitatea unor săgeți alternative care intră direct în același bloc. Condiția de continuare este înscrisă pe ramură, iar identificatorii joncțiunilor permit descrierea aceleiași logici în tabelul scenariului.',
'Obiectele de referință nu sunt activități executabile. „Plan și reguli” constrânge prezentarea rundei, iar „Stocare locală” indică resursa în care se păstrează înregistrarea. Legăturile lor punctate nu trebuie interpretate ca mesaje de rețea sau ca o ordine suplimentară de execuție. Semnificația concretă este menționată lângă obiect.',
'În varianta grafică utilizată, fluxul de obiect are două vârfuri orientate în același sens, conform convenției instrumentului din modelul de referință [4]. Această notație nu este o săgeată bidirecțională. De exemplu, înregistrarea încheiată circulă către salvare; salvarea nu trimite aceeași înregistrare înapoi pentru a redeschide automat sesiunea.',
'Verificarea scenariului urmărește accesibilitatea activităților, condițiile ramurilor și existența unui rezultat de ieșire. O reluare este validă numai dacă permite revenirea la progresul normal, iar încheierea nu trebuie să depindă de o operație online care nu aparține funcției A3.')

page();h('3.2 Diagrama IDEF3 a desfășurării sesiunii educative')
paras('Scenariul din figura 3.1 descrie o sesiune cu activități deja pregătite. Sunt urmărite răspunsul copilului, sprijinul pentru reluare, confirmarea, înregistrarea și salvarea finală. Intrarea este formată din activitățile pregătite și comenzile copilului, iar ieșirile sunt feedbackul și sesiunea păstrată local.',
'Tabelul 3.1 enumeră unitățile de lucru. Scenariul ales include încheierea între runde; pauza, ieșirea bruscă din aplicație și recuperarea după întrerupere sunt situații distincte, neextinse aici. Salvările intermediare prevăzute în implementare nu înlocuiesc salvarea înregistrării încheiate.')
cap('Tabelul 3.1 – Unitățile de lucru ale diagramei IDEF3',True)
uobs=[('1','Inițierea sesiunii','Se deschide înregistrarea pentru activitățile pregătite.'),('2','Prezentarea rundei','Se prezintă instrucțiunea și stimulii potriviți configurației.'),('3','Colectarea răspunsului','Se primește răspunsul și se măsoară informațiile prevăzute de joc.'),('4','Evaluarea răspunsului','Se determină dacă runda poate continua cu confirmare sau cu ajutor.'),('5','Indiciu și reluare','Se oferă sprijin blând și se revine la rundă.'),('6','Feedback pozitiv','Se confirmă reușita, respectând preferințele senzoriale.'),('7','Înregistrarea încercării','Se păstrează rezultatul, numărul încercărilor și nivelul de ajutor.'),('8','Alegerea continuării','Se aplică alegerea de continuare sau încheiere între runde.'),('9','Încheierea sesiunii','Se construiește înregistrarea finală a activității.'),('10','Salvarea locală','Se scrie înregistrarea sesiunii pe dispozitiv.')]
table(['ID','Unitatea de lucru','Descrierea'],uobs,[1.2,6.3,10.5])
text('Joncțiunile din tabelul 3.2 fac explicite alternativele și revenirea în ciclu. O singură ramură este aleasă la fiecare evaluare a condiției.')
cap('Tabelul 3.2 – Joncțiunile diagramei IDEF3',True)
table(['Cod','Tipul și rolul','Semnificația'],[
('J1','X, unire','Primește inițierea, reluarea cu ajutor sau continuarea cu o nouă rundă.'),
('J2','X, ramificare','Răspunsul acceptat duce la UOB 6; răspunsul de reluat duce la UOB 5.'),
('J3','X, ramificare','Continuarea revine la J1; încheierea duce la UOB 9.')],[1.2,4.3,12.5])
page()
figure('idef3','Figura 3.1 – Diagrama IDEF3 a scenariului unei sesiuni educative')
paras('Fluxul de obiect „Răspuns” leagă colectarea de evaluare. Fluxul „Înregistrare” leagă încheierea sesiunii de salvare. Ambele obiecte au producător și consumator identificabili; săgețile nu indică transferul direct între două depozite de date.',
'Ramura „de reluat” nu conduce la o pedeapsă sau la oprirea obligatorie a jocului. UOB 5 oferă un indiciu și revine prin J1 la prezentare. UOB 7 păstrează informațiile acumulate privind încercările și ajutorul, astfel încât reușita după sprijin să nu fie confundată cu o reușită independentă.',
'După UOB 8, alegerea „continuă” revine tot prin J1. Alegerea „încheie” produce înregistrarea finală și apoi salvarea. Lipsa conexiunii nu introduce o ramură de refuz, deoarece sincronizarea aparține funcției A4. Scenariul se termină cu o sesiune locală disponibilă pentru monitorizare sau transfer ulterior.',
'Obiectul „Plan și reguli” este legat de prezentarea rundei și indică aplicarea configurației. Obiectul „Stocare locală” este legat de UOB 10 și indică persistența. Modelul nu afirmă că aceste obiecte sunt apeluri API și nu le numără ca unități de lucru suplimentare.')

page();h('4 DIAGRAMELE FLUXURILOR DE DATE DFD',1);h('4.1 Regulile notației DFD')
paras('DFD reprezintă transformarea și păstrarea datelor, folosind procese, entități externe, depozite și fluxuri. Un proces primește date și produce alte date, iar un depozit le păstrează între utilizări. Diagrama nu stabilește ordinea temporală a operațiilor; aceasta este tratată în IDEF3. Convenția grafică Gane–Sarson este păstrată pentru compatibilitate cu modelul laboratorului [4].',
'În această lucrare, un proces are număr și denumire de activitate. O entitate externă este reprezentată printr-un dreptunghi, iar depozitul este deschis în partea dreaptă și poartă un identificator D1, D2 și așa mai departe. Săgețile sunt orientate și denumite prin datele transmise. Citirea și scrierea sunt reprezentate separat când au sensuri diferite.',
'Regulile de consistență aplicate sunt următoarele:')
bullets(['fiecare proces primește date suficiente pentru rezultatele pe care le produce','datele trec printr-un proces între o entitate externă și un depozit','nu se desenează transferuri directe între două depozite','un flux are o denumire de date, nu o comandă de succesiune','decompoziția păstrează datele care intră și ies din procesul-părinte','numerele subproceselor păstrează prefixul procesului descompus'])
paras('Frontiera DFD include aplicația, panoul și serviciile de pe server. De aceea, copilul, părintele și specialistul autorizat sunt entități externe, în timp ce aplicația și serverul nu sunt redesenate ca entități externe. Ele execută procesele din interior. Această delimitare previne prezentarea aceluiași server simultan ca proces și ca sursă exterioară a propriei înregistrări.',
'Depozitele sunt logice și nu trebuie interpretate ca tabele fizice unice. D1 reunește profilul și setările, iar D2 planul și catalogul necesare selecției. D3 și D4 sunt separate deoarece sesiunile locale și cele sincronizate au disponibilitate și responsabilități diferite. D5 reprezintă statisticile derivate din sesiunile centrale.',
'DFD nu înlocuiește controalele de securitate din IDEF0. De exemplu, un flux de raport către specialist nu înseamnă acces general la toate datele. Acesta presupune verificarea autorizării în procesul care produce raportul. Regulile și drepturile rămân condiții ale execuției, iar fluxurile arată informația transferată după aplicarea lor.',
'La decompoziție, o entitate sau un depozit exterior procesului-părinte nu poate fi introdus cu un flux nou și ascuns în copil. În subcapitolul 4.3, interfața procesului 3 este comparată explicit cu a subproceselor 3.1–3.4. Această verificare este distinctă de simpla asemănare vizuală a diagramelor.')

page();h('4.2 Diagrama principală')
paras('Diagrama principală din figura 4.1 conține patru procese, trei entități externe și cinci depozite logice. Procesele corespund funcțiilor A1–A4. Tabelul 4.1 stabilește semnificația elementelor externe și a depozitelor; denumirile sunt păstrate în decompoziția procesului 3.')
cap('Tabelul 4.1 – Elementele diagramei DFD principale',True)
table(['Tipul','Elementul','Rolul'],[
('Entitate','Părinte','Furnizează profilul și obiectivele; consultă progresul.'),('Entitate','Specialist autorizat','Propune configurația permisă și consultă rapoartele copilului partajat.'),('Entitate','Copil','Furnizează comenzi și răspunsuri; primește feedback și recompense.'),('Depozit','D1 Profil și setări','Informațiile profilului și opțiunile senzoriale utilizate la pregătire.'),('Depozit','D2 Plan și catalog','Jocurile disponibile, configurația și resursele de selecție.'),('Depozit','D3 Sesiuni locale','Înregistrări pe dispozitiv și starea de sincronizare.'),('Depozit','D4 Sesiuni pe server','Înregistrări acceptate, identificate stabil.'),('Depozit','D5 Statistici','Indicatori derivați din sesiunile centrale.')],[2.4,5.5,10.1])
figure('dfd','Figura 4.1 – Diagrama DFD principală a procesului')
text('Procesul 4 citește D3 și D4, actualizează D5 și prezintă rapoarte. Confirmarea transferului actualizează starea din D3. Procesul 2 folosește istoricul local, astfel încât pregătirea activităților rămâne posibilă fără statistici pe server.')

page();h('4.3 Decompoziția procesului 3 „Desfășurarea sesiunii educative”')
paras('Procesul 3 este descompus în figura 4.2 deoarece leagă interacțiunea copilului de înregistrarea persistentă. Din exterior intră activitățile pregătite de procesul 2 și comenzile ori răspunsurile copilului. Spre exterior ies feedbackul cu recompensele și sesiunea salvată în D3.')
figure('dfd_child','Figura 4.2 – Decompoziția procesului 3 la nivelul 1')
text('Tabelul 4.2 precizează transformările interne. Comenzile de pornire și încheiere sunt componente ale fluxului „Comenzi și răspunsuri” al părintelui, nu fluxuri externe suplimentare.')
cap('Tabelul 4.2 – Procesele decompoziției procesului 3',True)
table(['Nr.','Procesul','Date de intrare','Date de ieșire'],[
('3.1','Inițierea sesiunii','Activități pregătite; comandă de pornire','Sesiune inițiată'),('3.2','Prezentarea și evaluarea rundelor','Sesiune inițiată; răspunsuri','Feedback și recompense; încercări înregistrate'),('3.3','Încheierea sesiunii','Încercări înregistrate; comandă de încheiere','Înregistrare încheiată'),('3.4','Salvarea sesiunii','Înregistrare încheiată','Sesiune salvată în D3')],[1.1,5.4,5.9,5.6])
text('Interfața este echilibrată: nu se introduce un nou depozit și nu apare o legătură directă a copilului cu baza de date. Fluxurile dintre 3.1–3.4 detaliază transformarea, iar stocarea centrală rămâne responsabilitatea procesului 4.')

page();h('4.4 Concordanța dintre modele')
paras('Modelele descriu același proces la niveluri de analiză diferite. Tabelul 4.3 indică legătura dintre funcțiile IDEF0, unitățile IDEF3 și procesele DFD. Scenariul IDEF3 detaliază numai A3, astfel încât lipsa unei unități UOB pentru A1, A2 sau A4 nu reprezintă o funcție omisă din procesul general.')
cap('Tabelul 4.3 – Corespondența dintre IDEF0, IDEF3 și DFD',True)
table(['Funcția IDEF0','Scenariul IDEF3','Reprezentarea DFD'],[
('A1 Configurarea profilului și a planului','Configurație de referință, în afara scenariului','Procesul 1; D1 și D2'),('A2 Pregătirea activităților','Precondiția scenariului','Procesul 2; citire D1, D2 și D3'),('A31 Inițierea sesiunii','UOB 1','Procesul 3.1'),('A32 Prezentarea și evaluarea rundelor','UOB 2–8; J1–J3','Procesul 3.2'),('A33 Încheierea sesiunii','UOB 9','Procesul 3.3'),('A34 Salvarea sesiunii pe dispozitiv','UOB 10','Procesul 3.4; scriere D3'),('A4 Sincronizarea și monitorizarea progresului','În afara scenariului A3','Procesul 4; D3, D4 și D5')],[6.8,5.5,5.7])
paras('Prima verificare privește continuitatea rezultatului. O2 „Sesiune salvată local” este ieșirea A34, rezultatul UOB 10 și fluxul scris de procesul 3.4 în D3. Niciuna dintre aceste reprezentări nu declară sesiunea sincronizată doar pentru că a fost încheiată.',
'A doua verificare privește feedbackul. O1 este ieșirea activității A32 și este prezentat în scenariu prin indiciu sau confirmare. În DFD, feedbackul și recompensele circulă de la procesul 3.2 spre copil. Copilul nu primește direct date din depozitul de sesiuni.',
'A treia verificare privește echilibrarea. Pentru fiecare A1–A4 au fost comparate codurile externe ale părintelui cu cele folosite de subfuncții. Pentru procesul DFD 3 au fost comparate cele două categorii de intrări și cele două categorii de ieșiri. Fluxurile interne nu au fost numărate drept interfețe noi.',
'Ultima verificare privește implementarea. Stocarea locală, marcarea după confirmare, acceptarea idempotentă și recalcularea statisticilor sunt responsabilități distincte în codul proiectului [1]. Modelele păstrează aceste separări. Ele nu reprezintă o dovadă a funcționării infrastructurii în producție, ci o descriere verificată față de comportamentele și structurile disponibile.')

page();h('CONCLUZII',1)
paras('Lucrarea modelează procesul „Gestionarea sesiunilor educative și a progresului copilului” al aplicației Licurici. Delimitarea include configurarea, pregătirea activităților, desfășurarea sesiunii și utilizarea rezultatelor. Utilizarea locală și sincronizarea opțională sunt tratate explicit, deoarece disponibilitatea unei conexiuni nu trebuie să condiționeze activitatea educativă de bază.',
'Modelul IDEF0 cuprinde diagrama de context A-0, decompoziția A0 și diagramele-copil A1–A4. Cele patru funcții majore sunt detaliate în paisprezece subfuncții. Pentru fiecare decompoziție au fost păstrate intrările, controalele, ieșirile și mecanismele blocului-părinte. Fluxurile intermediare sunt denumite separat, iar istoricul local revine în pregătirea activităților următoare.',
'Modelul IDEF3 descrie un scenariu al funcției A3 prin zece unități de lucru și trei joncțiuni exclusive. Sunt explicite reluarea cu sprijin și alegerea dintre continuare și încheiere. Înregistrarea finală ajunge la salvarea locală fără a trece obligatoriu prin server. Obiectele de referință precizează relația scenariului cu planul și cu stocarea.',
'Diagramele DFD evidențiază patru procese, trei entități externe și cinci depozite logice. Separarea sesiunilor locale de cele centrale permite reprezentarea transferului amânat și a confirmării sale. Decompoziția procesului 3 păstrează interfața părintelui și nu introduce depozite sau entități externe suplimentare.',
'Concordanța dintre modele este demonstrată prin urmărirea acelorași rezultate. Feedbackul rămâne adresat copilului, sesiunea rămâne salvată local înaintea transferului, iar rapoartele sunt produse pentru adulții autorizați. Statisticile reprezintă date derivate din sesiuni și nu înlocuiesc înregistrarea sursă.',
'Modelarea oferă puncte concrete pentru verificarea aplicației: respectarea planului, aplicarea preferințelor senzoriale, păstrarea rezultatelor la întreruperea conexiunii, evitarea dublurilor și controlul accesului la rapoarte. Aceste puncte pot fi transpuse în scenarii de testare fără a modifica scopul procesului.',
'Rezultatul laboratorului este o descriere funcțională și informațională coerentă a aplicației existente. Validarea ulterioară cu utilizatori și specialiști rămâne necesară pentru evaluarea utilității educative. Diagramele verifică organizarea și circulația informației; ele nu constituie o demonstrație de eficacitate clinică.')

page();h('BIBLIOGRAFIE',1)
refs=[
'[1] M. Mudrea, „Licurici — platformă educativă pentru copii”, documentație și cod sursă, 2026. Consultate: README.md; backend/src/children/plan.ts; backend/src/sync/sessions.ts; backend/prisma/schema.prisma; apps/child_app/lib/data/session.dart și sync.dart. [Online]. Disponibil: https://github.com/MudreaDev/Licurici. [Accesat: 12 noiembrie 2026].',
'[2] National Institute of Standards and Technology, Integration Definition for Function Modeling (IDEF0), FIPS PUB 183. Gaithersburg, MD, SUA: NIST, 1993. [Online]. Disponibil: https://www.govinfo.gov/app/details/GOVPUB-C13-ba43579ec72306f00c01305771ffdf3b. [Accesat: 12 noiembrie 2026].',
'[3] R. J. Mayer, C. P. Menzel, M. K. Painter, P. S. deWitte, T. Blinn și B. Perakath, Information Integration for Concurrent Engineering (IICE): IDEF3 Process Description Capture Method Report. College Station, TX, SUA: Knowledge Based Systems, Inc., sept. 1995. [Online]. Disponibil: https://www.idef.com/wp-content/uploads/2016/02/Idef3_fn.pdf. [Accesat: 12 noiembrie 2026].',
'[4] Computer Associates International, AllFusion Process Modeler Methods Guide, versiunea 4.1, 2002, cap. 2–4. [Online]. Disponibil: https://ftpdocs.broadcom.com/cadocs/0/e000771e.pdf. [Accesat: 12 noiembrie 2026].'
]
for ref in refs:
    p=text(ref,indent=False);p.paragraph_format.left_indent=Cm(.8);p.paragraph_format.first_line_indent=Cm(-.8);p.paragraph_format.space_after=Pt(12)

def main():
    OUT.parent.mkdir(parents=True,exist_ok=True);doc.save(OUT)
    print(OUT)

if __name__=='__main__':main()
