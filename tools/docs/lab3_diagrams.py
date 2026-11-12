"""Diagrams for the Licurici PSI laboratory. All coordinates are in diagram units."""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tmp/lab3/diagrams'
FONT = ROOT / 'tmp/lab3/fonts/liberation-fonts-ttf-2.1.5'
S = 3

class Drawing:
    def __init__(self, node, title, number):
        self.im = Image.new('RGB', (1200*S, 800*S), 'white')
        self.d = ImageDraw.Draw(self.im)
        self.rect((2,2,1198,798))
        self.line([(2,62),(1198,62)]); self.line([(2,736),(1198,736)])
        for x in (180,570,790,1000): self.line([(x,2),(x,62)])
        self.text(12,10,'USED AT:',11)
        self.text(190,9,'AUTHOR: Mudrea Mihail\nPROJECT: Licurici',12)
        self.text(440,9,'DATE: 12.11.2026\nREV: 12.11.2026',11)
        self.text(585,9,'WORKING     RECOMMENDED\nDRAFT       X PUBLICATION',11)
        self.text(800,9,'READER     DATE',11); self.text(1010,9,'CONTEXT',11)
        for x in (145,1030): self.line([(x,736),(x,798)])
        self.text(12,743,'NODE:',11); self.text(155,743,'TITLE:',11); self.text(1040,743,'NUMBER:',11)
        self.text(72,768,node,18,True,'center'); self.text(585,770,title,17,True,'center'); self.text(1110,770,str(number),18,False,'center')
    def font(self,size,bold=False): return ImageFont.truetype('C:/Windows/Fonts/timesbd.ttf' if bold else 'C:/Windows/Fonts/times.ttf',round(size*S))
    def text(self,x,y,t,size=16,bold=False,align='left',bg=False):
        f=self.font(size,bold); lines=t.split('\n'); heights=round(size*1.17*S)
        for i,l in enumerate(lines):
            w=self.d.textlength(l,font=f); xx=x*S-(w/2 if align=='center' else w if align=='right' else 0); yy=y*S+i*heights
            if bg: self.d.rectangle((xx-3,yy-1,xx+w+3,yy+heights),fill='white')
            self.d.text((xx,yy),l,font=f,fill='black',stroke_width=0)
    def rect(self,b,fill='white',width=1.4): self.d.rectangle(tuple(v*S for v in b),fill=fill,outline='black',width=round(width*S))
    def line(self,pts,width=1.4,dash=False):
        pts=[(x*S,y*S) for x,y in pts]
        if not dash: self.d.line(pts,fill='black',width=round(width*S),joint='curve'); return
        for (x,y),(a,b) in zip(pts,pts[1:]):
            length=math.hypot(a-x,b-y)
            for n in range(0,int(length),18):
                z=min(n+10,length)
                self.d.line((x+(a-x)*n/length,y+(b-y)*n/length,x+(a-x)*z/length,y+(b-y)*z/length),fill='black',width=round(width*S))
    def arrow(self,pts,label='',lp=None,double=False,dash=False):
        self.line(pts,dash=dash)
        x,y=pts[-1]; a,b=pts[-2]; ang=math.atan2(y-b,x-a)
        for off in ([0,10] if double else [0]):
            xx=x-off*math.cos(ang); yy=y-off*math.sin(ang)
            self.d.polygon([(xx*S,yy*S),((xx-10*math.cos(ang)+4*math.sin(ang))*S,(yy-10*math.sin(ang)-4*math.cos(ang))*S),((xx-10*math.cos(ang)-4*math.sin(ang))*S,(yy-10*math.sin(ang)+4*math.cos(ang))*S)],fill='black')
        if label and lp: self.text(*lp,label,15,bg=True)
    def block(self,x,y,w,h,title,num):
        self.rect((x,y,x+w,y+h)); lines=title.count('\n')+1
        self.text(x+w/2,y+(h-lines*20)/2-5,title,17,False,'center')
        self.text(x+w-8,y+h-23,num,14,False,'right')
    def save(self,name):
        OUT.mkdir(parents=True,exist_ok=True); self.im.save(OUT/(name+'.png')); return OUT/(name+'.png')

LABELS={
 'I1':'Date de profil', 'I2':'Obiective educative', 'I3':'Comenzi și răspunsuri',
 'C1':'Reguli educative și de adaptare', 'C2':'Reguli senzoriale și de feedback', 'C3':'Reguli de acces și consimțământ',
 'M1':'Părinte / specialist autorizat', 'M2':'Copil', 'M3':'Aplicația Flutter și stocarea locală', 'M4':'Panoul și serviciile backend',
 'O1':'Feedback și recompense', 'O2':'Sesiune salvată local', 'O3':'Progres și rapoarte', 'O4':'Starea sincronizării',
 'F1':'Profil configurat', 'F2':'Plan configurat', 'F3':'Activități pregătite', 'F4':'Istoric și progres local',
 'L11':'Profil introdus', 'L12':'Plan propus', 'L21':'Context de învățare', 'L22':'Activități selectate',
 'L31':'Sesiune inițiată', 'L32':'Încercări înregistrate', 'L33':'Înregistrare încheiată',
 'L41':'Sesiune și indicatori', 'L42':'Sesiuni confirmate', 'L43':'Statistici pe server',
}

def fn(code,name,I,C,O,M): return dict(code=code,name=name,I=I.split(),C=C.split(),O=O.split(),M=M.split())
FUNCTIONS=[
 fn('A1','Configurarea profilului și a planului','I1 I2','C1 C2 C3','F1 F2','M1 M3 M4'),
 fn('A2','Pregătirea activităților educative','F1 F4','C1 C2 F2','F3','M3'),
 fn('A3','Desfășurarea sesiunii educative','F3 I3','C1 C2','O1 O2','M2 M3'),
 fn('A4','Sincronizarea și monitorizarea progresului','O2','C1 C3','F4 O3 O4','M1 M3 M4'),
]
CHILDREN={
 'A1':[
 fn('A11','Introducerea profilului','I1','C3','L11','M1 M3 M4'),
 fn('A12','Configurarea planului','I2 L11','C1 C2','L12','M1 M3 M4'),
 fn('A13','Validarea și salvarea configurației','L11 L12','C1 C2 C3','F1 F2','M3 M4')],
 'A2':[
 fn('A21','Construirea contextului de învățare','F1 F4','C1','L21','M3'),
 fn('A22','Selectarea activităților','L21','C1 F2','L22','M3'),
 fn('A23','Încărcarea stimulilor și a vocii','L22','C2 F2','F3','M3')],
 'A3':[
 fn('A31','Inițierea sesiunii','F3 I3','C1 C2','L31','M2 M3'),
 fn('A32','Prezentarea și evaluarea rundelor','L31 I3','C1 C2','L32 O1','M2 M3'),
 fn('A33','Încheierea sesiunii','L32 I3','C1 C2','L33','M2 M3'),
 fn('A34','Salvarea sesiunii pe dispozitiv','L33','C1','O2','M3')],
 'A4':[
 fn('A41','Calcularea progresului local','O2','C1','F4 L41','M3'),
 fn('A42','Sincronizarea sesiunilor','L41','C3','L42 O4','M1 M3 M4'),
 fn('A43','Recalcularea statisticilor pe server','L42','C1 C3','L43','M4'),
 fn('A44','Prezentarea progresului și a rapoartelor','F4 L43','C3','O3','M1 M3 M4')],
}

def validate_models():
    for p in FUNCTIONS:
        kids=CHILDREN[p['code']]; outputs={o for k in kids for o in k['O']}
        for typ in ('I','C','M'):
            actual={v for k in kids for v in k[typ] if v not in outputs}
            assert actual==set(p[typ]),(p['code'],typ,actual,p[typ])
        used={v for k in kids for t in ('I','C') for v in k[t]}
        terminal=outputs-used
        assert terminal<=set(p['O']),(p['code'],terminal)
        assert set(p['O'])<=outputs
        for k in kids:
            assert all(k[t] for t in ('I','C','O','M'))
    assert len(FUNCTIONS)==4 and sum(map(len,CHILDREN.values()))==14

def context():
    d=Drawing('A-0','Gestionarea sesiunilor educative și a progresului copilului',1)
    d.block(390,285,420,210,'Gestionarea sesiunilor\neducative și a\nprogresului copilului','0')
    for i,k in enumerate(['I1','I2','I3']):
        y=315+i*65; d.arrow([(20,y),(390,y)],k+'  '+LABELS[k],(23,y-25))
    for i,k in enumerate(['C1','C2','C3']):
        x=440+160*i; d.arrow([(x,165),(x,285)]); d.text(x,90,k+'\n'+LABELS[k].replace(' și ','\nși '),16,False,'center')
    for i,k in enumerate(['O1','O2','O3','O4']):
        y=315+i*48; d.arrow([(810,y),(1180,y)],k+'  '+LABELS[k],(825,y-25))
    for i,k in enumerate(['M1','M2','M3','M4']):
        x=420+i*120; d.arrow([(x,650),(x,495)]); d.text(x,660,k,16,True,'center')
    d.text(24,520,'Scop: descrierea pregătirii, desfășurării,\nsalvării și monitorizării sesiunilor.\n\nPunct de vedere: părintele și\nspecialistul autorizat.',15)
    d.text(24,701,'M1 Părinte / specialist autorizat   M2 Copil   M3 Aplicație și stocare locală   M4 Panou și backend',15)
    d.save('context')

def wrap(t,n=20):
    words=t.split(); ls=['']
    for w in words:
        if len(ls[-1])+len(w)+1>n: ls.append(w)
        else: ls[-1]+=(' ' if ls[-1] else '')+w
    return '\n'.join(ls)

def idef0(node,functions,boundary,number,name):
    d=Drawing(node,name,number)
    # Interface codes are repeated as boundary connectors. They are defined in the ICOM tables.
    # Repeated codes denote branches of one flow, never new external data.
    positions=[]
    n=len(functions)
    for i,k in enumerate(functions):
        x=135+i*(238 if n==4 else 350); y=185+i*(112 if n==4 else 160)
        positions.append((x,y,195,95))
    producers={v:i for i,f in enumerate(functions) for v in f['O']}
    def source(v):
        pi=producers[v]; px,py,pw,ph=positions[pi]
        return px+pw,py+20+functions[pi]['O'].index(v)*25
    for i,(k,(x,y,w,h)) in enumerate(zip(functions,positions)):
        d.block(x,y,w,h,wrap(k['name'],23),k['code'][-1])
        for j,v in enumerate(k['I']):
            yy=y+28+j*25
            if v in producers:
                pi=producers[v]; px,py,pw,ph=positions[pi]
                if pi<i:
                    mid=x-28-j*13
                    sx,sy=source(v)
                    d.arrow([(px+pw,sy),(mid,sy),(mid,yy),(x,yy)],v,(mid+3,(sy+yy)/2-12))
                else: # feedback routed below the entire decomposition
                    sx,sy=source(v)
                    d.arrow([(sx,sy),(1158,sy),(1158,650),(x-48,650),(x-48,yy),(x,yy)],v,(x-44,yy-23))
            else:
                d.arrow([(18,yy),(x,yy)],v,(23,yy-23))
        for j,v in enumerate(k['C']):
            xx=x+30+j*54
            if v in producers:
                sx,sy=source(v)
                d.arrow([(sx,sy),(sx+22,sy),(sx+22,y-35),(xx,y-35),(xx,y)])
                d.text(xx,y-60,v,16,False,'center')
            else:
                d.arrow([(xx,150),(xx,y)]); d.text(xx,130,v,16,False,'center')
        for j,v in enumerate(k['M']):
            xx=x+28+j*54; d.arrow([(xx,655),(xx,y+h)]); d.text(xx,660,v,16,False,'center')
        out_external=[v for v in k['O'] if v in boundary['O']]
        for j,v in enumerate(out_external):
            yy=y+20+k['O'].index(v)*25; d.arrow([(x+w,yy),(1180,yy)],v,(1135,yy-23))
    d.text(25,82,'Intrări: '+'; '.join(boundary['I'])+'    Controale: '+'; '.join(boundary['C']),17)
    d.text(25,108,'Ieșiri: '+'; '.join(boundary['O'])+'    Mecanisme: '+'; '.join(boundary['M']),17)
    d.text(25,685,'Coduri ICOM: vezi tabelul asociat. Repetarea unui cod indică ramificarea aceluiași flux.',15)
    d.text(25,709,'I = intrare (stânga)   C = control (sus)   O = ieșire (dreapta)   M = mecanism (jos)',15)
    d.save(node)

def idef3():
    d=Drawing('A3 / IDEF3','Scenariul unei sesiuni educative',7)
    def u(x,y,t,n): d.block(x,y,150,86,t,str(n)); return (x,y)
    def j(x,y,n): d.rect((x,y,x+30,y+42));d.text(x+15,y+8,'X',20,True,'center');d.text(x+15,y+45,n,13,False,'center')
    u(35,130,'Inițierea\nsesiunii',1); j(215,152,'J1')
    u(280,130,'Prezentarea\nrundei',2);u(480,130,'Colectarea\nrăspunsului',3);u(680,130,'Evaluarea\nrăspunsului',4);j(875,152,'J2')
    u(975,130,'Feedback\npozitiv',6)
    u(680,300,'Indiciu și\nreluare',5)
    u(975,300,'Înregistrarea\nîncercării',7)
    u(975,470,'Alegerea\ncontinuării',8);j(875,492,'J3')
    u(680,470,'Încheierea\nsesiunii',9);u(440,470,'Salvarea\nlocală',10)
    d.arrow([(185,173),(215,173)]); d.arrow([(245,173),(280,173)])
    d.arrow([(430,173),(480,173)]); d.arrow([(630,173),(680,173)],'Răspuns',(632,105),double=True)
    d.arrow([(830,173),(875,173)]);d.arrow([(905,173),(975,173)],'corect',(917,146))
    d.arrow([(890,194),(890,343),(830,343)],'de reluat',(845,273))
    d.arrow([(680,343),(230,343),(230,194)],'reluare cu ajutor',(385,318))
    d.arrow([(1050,216),(1050,300)],'confirmat',(1060,249))
    d.arrow([(1050,386),(1050,470)],'încercare',(1060,420))
    d.arrow([(975,513),(905,513)])
    d.arrow([(890,492),(890,427),(260,427),(260,105),(230,105),(230,152)],'continuă',(530,404))
    d.arrow([(875,513),(830,513)],'încheie',(835,450))
    d.arrow([(680,513),(590,513)],'Înregistrare',(591,450),double=True)
    d.arrow([(440,513),(310,513)],'Sesiune salvată',(300,543))
    d.rect((30,590,335,648));d.text(182,602,'OBJECT / Plan și reguli\nconstrânge prezentarea și evaluarea',15,False,'center')
    d.line([(90,590),(90,390),(355,390),(355,216)],dash=True)
    d.rect((440,590,745,648));d.text(592,603,'OBJECT / Stocare locală\npersistența înregistrării',15,False,'center')
    d.line([(515,590),(515,556)],dash=True)
    d.text(30,677,'Intrare: activități pregătite și comenzile copilului. Ieșiri: feedback și sesiune salvată local.',16)
    d.text(30,704,'Linie continuă = precedență; vârf dublu = flux de obiect; linie punctată = relație; X = alegere exclusivă.',14)
    d.save('idef3')

def dfd():
    d=Drawing('A0 / DFD','Fluxurile de date ale sesiunilor educative',8)
    def ext(x,y,w,t):
        d.rect((x+5,y+5,x+w+5,y+65),fill='#bbbbbb');d.rect((x,y,x+w,y+60));d.text(x+w/2,y+14,t,17,False,'center')
    def proc(x,y,w,t,n):
        d.d.rounded_rectangle((x*S,y*S,(x+w)*S,(y+85)*S),radius=12*S,fill='white',outline='black',width=4)
        d.line([(x,y+23),(x+w,y+23)]);d.text(x+10,y+3,n,16,True);d.text(x+w/2,y+30,t,17,False,'center')
    def store(x,y,w,t,n):
        d.line([(x+w,y),(x,y),(x,y+52),(x+w,y+52)]);d.line([(x+38,y),(x+38,y+52)]);d.text(x+19,y+16,n,15,True,'center');d.text(x+46,y+17,t,16)
    ext(30,110,190,'Părinte');ext(30,245,190,'Specialist autorizat');ext(30,535,190,'Copil')
    proc(315,150,220,'Configurarea profilului\nși a planului','1');proc(315,345,220,'Pregătirea activităților\neducative','2')
    proc(315,535,220,'Desfășurarea sesiunii\neducative','3');proc(900,345,255,'Sincronizarea și\nmonitorizarea progresului','4')
    store(650,105,290,'Profil și setări','D1');store(650,225,290,'Plan și catalog','D2');store(650,550,250,'Sesiuni locale','D3');store(900,620,265,'Sesiuni pe server','D4');store(900,480,265,'Statistici','D5')
    d.arrow([(220,137),(270,137),(270,178),(315,178)],'Date profil,\nobiective',(225,85))
    d.arrow([(220,273),(270,273),(270,208),(315,208)],'Obiective',(230,280))
    d.arrow([(535,174),(600,174),(600,131),(650,131)],'Profil',(560,146))
    d.arrow([(535,207),(585,207),(585,251),(650,251)],'Plan',(592,219))
    d.arrow([(650,143),(615,143),(615,365),(535,365)],'Profil și setări',(540,331))
    d.arrow([(650,264),(635,264),(635,397),(535,397)],'Plan, catalog',(539,404))
    d.arrow([(425,430),(425,535)],'Activități\npregătite',(432,463))
    d.arrow([(220,555),(315,555)],'Comenzi,\nrăspunsuri',(224,516))
    d.arrow([(315,595),(220,595)],'Feedback,\nrecompense',(224,613))
    d.arrow([(535,575),(650,575)],'Sesiune',(553,551))
    d.arrow([(650,588),(615,588),(615,445),(500,445),(500,430)],'Istoric',(540,454))
    d.arrow([(800,550),(800,455),(980,455),(980,430)],'Sesiuni locale',(690,429))
    d.arrow([(900,390),(850,390),(850,540),(880,540),(880,550)],'Stare sync',(754,516))
    d.arrow([(1155,375),(1173,375),(1173,595),(1100,595),(1100,620)],'Sesiuni\nconfirmate',(1000,550))
    d.arrow([(1165,645),(1180,645),(1180,400),(1155,400)],'Istoric server',(1064,678))
    d.arrow([(1060,430),(1060,480)],'Statistici',(1070,450))
    d.arrow([(900,505),(878,505),(878,410),(900,410)])
    d.text(784,452,'Statistici citite',14)
    d.arrow([(1020,345),(1020,80),(100,80),(100,110)],'Progres și rapoarte',(410,63))
    d.arrow([(1020,315),(245,315),(245,320),(125,320),(125,305)],'Progres și rapoarte',(520,291))
    d.text(30,694,'D1 și D2 sunt depozite logice, cu date locale și/sau pe server. D3 include starea outbox.',15)
    d.save('dfd')

def dfd_child():
    d=Drawing('3 / DFD','Decompoziția desfășurării sesiunii educative',9)
    def p(x,y,t,n):
        d.d.rounded_rectangle((x*S,y*S,(x+230)*S,(y+95)*S),radius=12*S,fill='white',outline='black',width=4)
        d.line([(x,y+24),(x+230,y+24)]);d.text(x+10,y+3,n,16,True);d.text(x+115,y+35,t,17,False,'center')
    def e(x,y,w,t): d.rect((x+5,y+5,x+w+5,y+65),fill='#bbbbbb');d.rect((x,y,x+w,y+60));d.text(x+w/2,y+18,t,17,False,'center')
    e(25,115,235,'2 Pregătirea activităților');e(25,350,200,'Copil')
    p(340,110,'Inițierea\nsesiunii','3.1');p(340,340,'Prezentarea și\nevaluarea rundelor','3.2');p(810,340,'Încheierea\nsesiunii','3.3');p(810,570,'Salvarea\nsesiunii','3.4')
    d.line([(580,590),(330,590),(330,650),(580,650)]);d.line([(375,590),(375,650)]);d.text(352,611,'D3',17,True,'center');d.text(390,611,'Sesiuni locale',17)
    d.arrow([(260,145),(340,145)],'Activități\npregătite',(267,89))
    d.arrow([(225,365),(280,365),(280,182),(340,182)],'Start',(283,235))
    d.arrow([(225,383),(340,383)],'Răspunsuri',(229,357))
    d.arrow([(340,415),(200,415),(200,410)],'Feedback și recompense',(28,436))
    d.arrow([(455,205),(455,340)],'Sesiune inițiată',(465,267))
    d.arrow([(570,385),(810,385)],'Încercări înregistrate',(609,360))
    d.arrow([(125,350),(125,280),(925,280),(925,340)],'Comandă de încheiere',(600,252))
    d.arrow([(925,435),(925,570)],'Înregistrare încheiată',(934,490))
    d.arrow([(810,618),(580,618)],'Sesiune salvată',(634,592))
    d.text(30,684,'Interfață păstrată față de procesul 3: activități pregătite, comenzi și răspunsuri,',16)
    d.text(30,707,'feedback și recompense, sesiune salvată în D3. Nu se adaugă entități sau depozite externe.',16)
    d.save('dfd_child')

def main():
    validate_models(); context()
    boundary=dict(I=['I1','I2','I3'],C=['C1','C2','C3'],O=['O1','O2','O3','O4'],M=['M1','M2','M3','M4'])
    idef0('A0',FUNCTIONS,boundary,2,'Gestionarea sesiunilor educative și a progresului copilului')
    for i,p in enumerate(FUNCTIONS): idef0(p['code'],CHILDREN[p['code']],p,3+i,p['name'])
    idef3();dfd();dfd_child()
    print('Validated 4 major functions, 14 subfunctions, 9 diagrams')

if __name__=='__main__': main()
