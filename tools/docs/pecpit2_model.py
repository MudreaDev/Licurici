"""PERT Licurici: explicit scope allocation, exact arithmetic and all DAG paths."""
from pathlib import Path
from fractions import Fraction
from collections import Counter
import json
from pecpit_wbs_data import ROWS as WBS, LEAVES, TITLE

# ID | WBS leaves | activity | predecessors | O M P | estimation basis | dependency rationale
DATA='''
P01|1.9.1|Planificarea inițială a proiectului||8 12 20|Delimitarea livrabilelor și elaborarea WBS/PERT; ajustarea ulterioară a planului și pregătirea Gantt sunt incluse în buget.|Activitatea inițializează planul; acesta va fi revizuit la punctele de control.
P02|1.1.1|Studiul activităților asistate|P01|12 20 32|Documentarea a patru procese și a limitelor unui suport informatic pentru terapie.|Necesită perimetrul inițial de studiu.
P03|1.1.2,1.1.3|Actorii, necesitățile și consultările|P02|12 20 36|Pregătirea întrebărilor, consultarea unui părinte și unui specialist și sinteza; exclude așteptarea programărilor.|Necesită înțelegerea proceselor; este independentă de analiza produselor.
P04|1.2.1,1.2.2|Selectarea soluțiilor și criteriilor|P02|6 10 16|Fișe pentru minimum trei soluții și șapte criterii comune.|Procesele analizate oferă criteriile inițiale de comparație.
P05|1.2.3,1.2.4|Comparația soluțiilor și oportunitățile|P04|10 16 26|Compararea funcțiilor, verificarea surselor și analiza SWOT.|Folosește fișele și criteriile definite.
P06|1.1.4|Formularea problemei și obiectivelor|P03,P05|4 6 10|Corelarea necesităților utilizatorilor cu lacunele soluțiilor și definirea obiectivelor verificabile.|Necesită atât consultările, cât și comparația soluțiilor.
P07|1.3.1,1.3.2|Conceptul, perimetrul și rolurile|P06|8 12 20|Definirea aplicațiilor, a limitelor și a matricei de acces pe copil.|Conceptul răspunde problemei și obiectivelor formulate.
P08|1.3.3,1.3.4,1.3.5|Cerințele și regulile privind datele|P07|16 24 40|Cerințe funcționale, offline, accesibilitate, inventar de date și consimțăminte separate pentru sincronizare/AI.|Cerințele detaliază perimetrul și permisiunile.
P09|1.9.2|Revizuirea cerințelor și riscurilor|P08|2 4 8|Prima parte a monitorizării: revizie cu coordonatorul și actualizarea riscurilor.|Punct de control înaintea modelării și planului de test.
P10|1.4.1,1.4.2|Modelarea utilizării și proceselor|P09|12 20 32|Cazuri de utilizare, procese și fluxuri locale/centrale distincte.|Modelează cerințele revizuite.
P11|1.4.4|Modelarea conceptuală a datelor|P10|8 12 20|Entități, relații și cardinalități pentru plan, sesiune, încercare și acces.|Entitățile sunt extrase din cazurile și fluxurile modelate.
P12|1.4.3,1.4.5|Modelarea interacțiunilor și stărilor|P11|12 18 30|Secvențe pentru sincronizare/live/AI și stări pentru sesiune și transfer.|Necesită procesele și entitățile deja identificate.
P13|1.5.1|Proiectarea arhitecturii|P12|10 16 28|Responsabilități Flutter/NestJS/worker și diagrame de desfășurare.|Arhitectura trebuie să susțină interacțiunile modelate.
P14|1.5.2|Proiectarea stocării locale și centrale|P13|12 18 30|Scheme SQLite/PostgreSQL, indexuri și stocare S3.|Arhitectura fixează separarea datelor și componentele persistente.
P15|1.5.3,1.5.4|Proiectarea API-ului și securității|P14|16 24 40|Contracte REST/live, idempotență, autorizare și model de amenințări.|Contractele de date și controalele se bazează pe schema de stocare.
P16|1.5.5,1.5.6|Proiectarea interfețelor și motorului|P13|20 32 52|Prototipuri pe roluri, GameConfig, politica de mișcare și contracte pentru integrări.|Poate fi realizată separat de schema fizică, folosind modelele și arhitectura aprobate.
P17|1.9.2|Revizuirea proiectării și a planului|P15,P16|2 4 8|A doua parte a monitorizării: coerența contractelor, interfețelor și planului.|Poartă de revizie comună înaintea implementării de bază.
P18|1.6.1.1,1.6.1.2|Configurarea monorepo-ului și Docker|P17|12 20 36|Structura pachetelor, verificări automate și pornirea API/worker/PostgreSQL/Redis/S3.|Planul adoptă implementarea după revizuirea proiectării, inclusiv a mediilor.
P19|1.6.2.1|Implementarea entităților și migrărilor|P18|10 16 28|Module NestJS, schema inițială și migrări reproductibile.|Necesită mediul de dezvoltare și baza de date funcțională.
P20|1.6.2.2,1.6.2.3|Conturile adulților și accesul pe copil|P19|24 40 64|Înregistrare, confirmare, recuperare, autorizare, invitații și revocări.|Accesul folosește entitățile și relațiile centrale.
P21|1.6.2.4|Consimțămintele, exportul și ștergerea|P20|18 28 48|Acorduri pe scopuri și operații de export/ștergere cu tratarea erorilor.|Operațiile necesită conturi și control de acces.
P22|1.6.3.1,1.6.3.2|Aplicația locală și interacțiunea accesibilă|P18|24 40 64|Navigație landscape, profil local, poarta adultului, ținte tactile și MotionPolicy.|Clientul poate fi dezvoltat offline în paralel cu serviciile centrale.
P23|1.6.4.1|Motorul și dificultatea jocurilor|P22|24 40 68|Contractele comune, ajutor gradual, metrici și scări de dificultate verificabile.|Motorul utilizează infrastructura clientului și politica de interacțiune.
P24|1.6.4.6|Integrarea ilustrațiilor și vocii române|P23|32 56 96|Pregătirea și verificarea materialelor, manifestului audio și încărcării offline.|Integrarea finală a materialelor folosește identificatorii și contractele motorului.
P25|1.6.4.2,1.6.4.3|Jocurile de bază, limbajul și AAC|P24|80 128 200|Atenție, imitație, potrivire, înțelegere, vorbire și AAC, cu reutilizarea mecanicilor.|Necesită motorul și materialele; este primul lot de integrare a catalogului.
P26|1.6.4.4,1.6.4.5|Jocurile avansate și explorările|P25|96 160 260|Logică, emoții, autonomie, numere/litere, explorări și activități libere.|Planul adoptă două loturi succesive: mecanicile consolidate în primul lot sunt reutilizate în al doilea.
P27|1.6.5.1,1.6.5.2,1.6.5.3|Recompensele și acvariul interactiv|P24|40 64 112|Stele, album, colorare, scanarea fișei și animația procedurală; risc ridicat la scanare și performanță.|Poate folosi profilul și materialele comune fără a aștepta întregul catalog.
P28|1.6.3.3,1.6.3.4|Planul local și înregistrarea sesiunilor|P26,P27|24 40 68|Integrarea planului, limitelor zilnice și salvării încercărilor/rezultatelor.|Integrarea sesiunii verifică jocurile și acordarea persistentă a recompenselor.
P29|1.6.6.1,1.6.6.4|Panoul părintelui și controlul datelor|P21|20 32 52|Istoric, configurare și interfețe pentru acord, partajare, export și ștergere.|Necesită API-ul de cont, acces și confidențialitate.
P30|1.6.6.2,1.6.6.3|Panoul specialistului și planurile|P29|24 40 68|Lista copiilor, fișa de progres, notițe și constructor de plan din GameConfig.|Reutilizează navigația, selecția copilului și componentele panoului comun.
P31|1.6.7.1|Sincronizarea sesiunilor și planurilor|P28,P30|24 40 72|Transfer idempotent, confirmări, retrimitere și preluarea planului pentru lucru offline.|Necesită sesiuni locale și planuri disponibile în panou.
P32|1.6.7.2|Agregarea statisticilor pe abilități|P31|16 24 40|Joburi BullMQ, agregări și invalidarea cache-ului Redis.|Se bazează pe sesiunile confirmate de sincronizare.
P33|1.6.7.3,1.6.7.4|Rapoartele, canalul live și notificările|P32|24 40 68|Grafice, WebSocket, e-mailuri, cozi și fișiere de conținut/export.|Consumă agregatele și evenimentele centrale.
P34|1.6.8.1|Pregătirea contextului pentru AI|P32|8 12 22|Selectarea agregatelor și eliminarea identificatorilor și notițelor brute.|AI utilizează aceleași statistici verificate ca panoul.
P35|1.6.8.2,1.6.8.3|Serviciul AI și interfața adultului|P34|20 32 56|Adaptor de furnizor, acord, limitare, cache, timeout și interfața de întrebări/rezumate.|Contextul permis trebuie definit înaintea apelurilor și afișării răspunsurilor.
P36|1.7.1|Planul și cazurile de test|P09|12 20 32|Strategie, date sintetice și matrice cerințe–teste; întreținerea cazurilor este inclusă.|Pornește din cerințe, fără să aștepte finalizarea implementării.
P37|1.7.2|Testarea unitară și de integrare|P33,P35,P36|24 40 68|Finalizarea și execuția suitelor pentru nucleu, widgeturi, API și infrastructură reală.|Necesită implementările integrate și planul de test; verificările locale se fac și în timpul dezvoltării.
P38|1.7.3|Testarea fluxurilor complete și offline|P37|16 24 40|Plan–joc–salvare–repornire–sincronizare–progres, inclusiv întreruperi de rețea.|Se testează o versiune care trece verificările unitare și de integrare.
P39|1.7.4|Testarea accesibilității și performanței|P37|16 28 48|Măsurători pe telefon/tabletă, ținte tactile, calm și fluiditatea acvariului.|Folosește aceeași versiune stabilizată; poate fi evaluată separat de fluxurile complete.
P40|1.7.5,1.7.6|Verificarea securității și a asistentului AI|P37|20 32 56|Izolarea datelor, retragerea acordului și răspunsuri AI pe cazuri sintetice, insuficiente sau nepermise.|Necesită module integrate și un set reproductibil de date de test.
P41|1.7.7|Validarea cu adulți și remedierea|P38,P39,P40|24 40 72|Feedback de la părinte/specialist, corecții și regresie; fără studiu clinic.|Se aplică observațiile după toate cele trei categorii de verificări.
P42|1.9.2|Revizuirea finală a riscurilor și progresului|P41|2 4 8|A treia parte a monitorizării: închiderea observațiilor și consemnarea limitărilor.|Punct de control înaintea înghețării versiunii de predare.
P43|1.6.1.3|Pregătirea versiunii de demonstrație|P42|8 14 24|APK, panou, mediu de test, versiune identificabilă și verificarea restaurării.|Publicarea pachetului de demonstrație urmează acceptării versiunii.
P44|1.8.1|Finalizarea documentației tehnice|P43|16 24 40|Consolidarea arhitecturii/API/instalării/restaurării pentru versiunea livrată.|Instrucțiunile finale trebuie să corespundă versiunii demonstrabile.
P45|1.8.2|Finalizarea ghidurilor de utilizare|P44|12 18 30|Ghiduri ilustrate pentru adulți și indicații de asistare a copilului.|Folosește procedurile tehnice stabilizate și capturile versiunii livrate.
P46|1.8.3|Redactarea și revizuirea tezei|P45|48 72 112|Consolidarea notelor și modelelor, capitole, bibliografie, anexe și corecturi.|Versiunea finală descrie produsul, verificările și ghidurile complete.
P47|1.8.4|Prezentarea și demonstrația|P46|12 20 32|Diapozitive, scenariu, repetiție și înregistrare de rezervă.|Folosește teza revizuită și versiunea finală a sistemului.
P48|1.9.3|Pre-susținerea și susținerea|P47|6 10 18|Participare, tratarea observațiilor și predarea materialelor; exclude așteptarea datei comisiei.|Necesită materialele și demonstrația pregătite.
'''

def build():
    rows=[]
    for line in DATA.strip().splitlines():
        code,wbs,name,pred,omp,basis,logic=line.split('|')
        O,M,P=map(int,omp.split())
        rows.append(dict(code=code,wbs=wbs.split(','),name=name,pred=pred.split(',') if pred else [],O=O,M=M,P=P,basis=basis,logic=logic))
    by={r['code']:r for r in rows}
    assert len(by)==len(rows)
    allocation=Counter(c for r in rows for c in r['wbs'])
    assert set(allocation)=={r['code'] for r in LEAVES}
    assert {c:n for c,n in allocation.items() if n>1}=={'1.9.2':3}
    for r in rows:
        assert 0<r['O']<=r['M']<=r['P']
        assert all(p in by for p in r['pred'])
        r['succ']=[s['code'] for s in rows if r['code'] in s['pred']]
        r['te']=Fraction(r['O']+4*r['M']+r['P'],6)
        r['variance']=Fraction((r['P']-r['O'])**2,36)
    pending=set(by);order=[]
    while pending:
        ready=sorted(c for c in pending if all(p in order for p in by[c]['pred']))
        assert ready,'Cycle in PERT'
        order+=ready;pending-=set(ready)
    starts=[r['code'] for r in rows if not r['pred']]
    ends=[r['code'] for r in rows if not r['succ']]
    assert starts==['P01'] and ends==['P48']
    for c in order:
        r=by[c];r['ES']=max((by[p]['EF'] for p in r['pred']),default=Fraction(0));r['EF']=r['ES']+r['te']
    duration=max(by[c]['EF'] for c in ends)
    for c in reversed(order):
        r=by[c];r['LF']=min((by[s]['LS'] for s in r['succ']),default=duration);r['LS']=r['LF']-r['te'];r['float']=r['LS']-r['ES'];r['critical']=r['float']==0
        assert r['float']>=0
    paths=[]
    def visit(code,path):
        path=path+[code]
        if not by[code]['succ']:
            paths.append(dict(nodes=path,duration=sum((by[c]['te'] for c in path),Fraction(0))))
        else:
            for successor in by[code]['succ']:visit(successor,path)
    visit('P01',[])
    paths.sort(key=lambda p:(-p['duration'],p['nodes']))
    for i,path in enumerate(paths,1):path.update(id=f'T{i:02}',critical=path['duration']==duration)
    assert paths[0]['duration']==duration
    assert set(c for p in paths for c in p['nodes'])==set(by)
    # Independent recursive longest-path recurrence, distinct from the forward table.
    memo={}
    def longest(c):
        if c not in memo:memo[c]=by[c]['te']+max((longest(s) for s in by[c]['succ']),default=Fraction(0))
        return memo[c]
    assert longest('P01')==duration
    assert all(p['duration']==sum(by[c]['te'] for c in p['nodes']) for p in paths)
    critical=[r['code'] for r in rows if r['critical']]
    assert set(critical)=={c for p in paths if p['critical'] for c in p['nodes']}
    return dict(title=TITLE,rows=rows,wbs=WBS,paths=paths,stats=dict(activities=len(rows),wbs_packages=len(LEAVES),paths=len(paths),duration=duration,effort=sum((r['te'] for r in rows),Fraction(0)),critical=critical,critical_paths=sum(p['critical'] for p in paths),min_path=paths[-1]['duration'],second_path=paths[1]['duration'],critical_variance=sum((by[c]['variance'] for c in critical),Fraction(0))))

def serializable(obj):
    if isinstance(obj,Fraction):return float(obj)
    if isinstance(obj,list):return [serializable(x) for x in obj]
    if isinstance(obj,dict):return {k:serializable(v) for k,v in obj.items()}
    return obj

if __name__=='__main__':
    model=build();root=Path(__file__).resolve().parents[2]
    out=root/'tmp/pecpit2';out.mkdir(parents=True,exist_ok=True)
    (out/'model.json').write_text(json.dumps(serializable(model),ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(serializable(model['stats']),ensure_ascii=False,indent=2))
