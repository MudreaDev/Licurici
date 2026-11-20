"""Structura unica pentru raportul WBS PECPIT si diagramele sale."""

TITLE = 'Dezvoltarea unui sistem informatic pentru terapia asistată a copiilor cu tulburări din spectrul autist'
ROOT = 'Sistem informatic pentru terapia asistată a copiilor cu TSA (Licurici)'

# Cod | Element | Lucrare | Rezultat | Criteriu. Criteriile sunt tinte, nu rezultate pretinse.
DATA = '''
1.0|Sistemul informatic Licurici|Realizarea întregului proiect de licență, de la analiza problemei până la susținere.|Sistem realizat, verificat și documentat; teză și demonstrație.|-
1.1|Analiza domeniului și definirea problemei|Analiza contextului de utilizare a unui suport informatic în activități asistate de adulți.|Problemă argumentată și necesități identificate.|-
1.1.1|Studiul activităților asistate|Descrierea pregătirii activităților, exersării, acordării ajutorului și urmăririi progresului.|Descrierea proceselor actuale și a dificultăților observate în surse.|Sunt descrise cele patru procese, cu intrări, actori și rezultate.
1.1.2|Actorii și necesitățile lor|Identificarea nevoilor copilului, părintelui și specialistului, inclusiv utilizarea fără internet.|Lista actorilor și matricea necesităților.|Fiecare actor are nevoi explicite și legături cu procesele analizate.
1.1.3|Consultarea specialiștilor și părinților|Pregătirea întrebărilor, organizarea consultărilor și sintetizarea observațiilor, fără date identificabile despre copii.|Ghid de consultare și sinteză anonimizată.|Sunt documentate perspectivele unui specialist și unui părinte; lipsa participării este declarată.
1.1.4|Problema și obiectivele proiectului|Formularea problemei de personalizare, continuitate offline și vizibilitate a progresului.|Problema, scopul și obiectivele verificabile.|Fiecare obiectiv are un rezultat software sau documentar și un mod de verificare.
1.2|Analiza soluțiilor existente|Compararea soluțiilor relevante cu necesitățile proiectului.|Argumentarea diferențiatorilor Licurici.|-
1.2.1|Selectarea soluțiilor relevante|Selectarea pentru studiu a AutiSpark, Otsimo și a unei soluții AAC; consultarea surselor oficiale.|Fișe de produs cu sursă și data consultării.|Minimum trei soluții au fișe; funcțiile neconfirmate sunt marcate ca atare.
1.2.2|Criteriile de comparație|Definirea criteriilor: română, offline, personalizare, accesibilitate senzorială, AAC, progres și confidențialitate.|Grilă de evaluare cu explicația criteriilor.|Toate cele șapte criterii sunt definite și legate de nevoile actorilor.
1.2.3|Comparația soluțiilor|Aplicarea aceleiași grile fiecărui produs și consemnarea avantajelor și limitărilor.|Tabel comparativ susținut prin surse.|Fiecare evaluare are justificare; absența dovezii nu este prezentată ca absență a funcției.
1.2.4|Oportunitățile soluției propuse|Sintetizarea lacunelor și elaborarea unei analize SWOT a soluției Licurici.|SWOT și lista oportunităților urmărite.|Fiecare oportunitate selectată se regăsește în cerințele soluției.
1.3|Definirea soluției propuse|Definirea perimetrului și a comportamentului așteptat al sistemului.|Specificația cerințelor Licurici.|-
1.3.1|Conceptul și perimetrul|Descrierea aplicației copilului, panoului pentru adulți și serviciilor, cu includerea asistentului AI pentru adulți.|Concept, livrabile și excluderi explicite.|Toate modulele incluse au o ramură de realizare; extensiile sunt separate.
1.3.2|Rolurile și accesul|Definirea utilizării locale fără cont și a accesului părintelui și specialistului la datele partajate.|Matricea rolurilor și permisiunilor.|Fiecare operație asupra datelor unui copil are condiții de autorizare definite.
1.3.3|Cerințele funcționale|Codificarea cerințelor pentru jocuri, AAC, planuri, acvariu, sincronizare, rapoarte și AI.|Lista cerințelor funcționale prioritizate.|Fiecare cerință are identificator, actor, rezultat și criteriu de acceptare.
1.3.4|Cerințele nefuncționale|Specificarea utilizării offline, a țintelor tactile de minimum 64 dp, a modului calm, securității și performanței.|Cerințe nefuncționale măsurabile.|Fiecare cerință are metodă de verificare; politica de mișcare acoperă toate ecranele copilului.
1.3.5|Datele și limitele utilizării|Definirea datelor strict necesare, a consimțămintelor și a limitelor suportului oferit de AI.|Inventarul datelor și regulile de utilizare.|Sunt separate sincronizarea, partajarea și AI; nu se definesc diagnostic sau tratament automat.
1.4|Modelarea soluției|Modelarea comportamentului, informațiilor și interacțiunilor sistemului.|Modele coerente cu cerințele.|-
1.4.1|Cazurile de utilizare|Modelarea jocului local, configurării, planificării, consultării progresului și întrebărilor către AI.|Diagrame de cazuri de utilizare și scenarii textuale.|Fiecare cerință funcțională este asociată unui caz de utilizare.
1.4.2|Procesele și fluxurile de date|Modelarea pregătirii planului, desfășurării sesiunii și prelucrării rezultatelor.|Diagrame de activitate și fluxuri de date.|Sunt distincte salvarea locală, transferul confirmat și calculul statisticilor centrale.
1.4.3|Interacțiunile dintre componente|Descrierea prin secvențe a sincronizării, partajării, sesiunii live și solicitării AI.|Patru diagrame de secvență.|Sunt reprezentate refuzul accesului, lipsa rețelei și eroarea serviciului extern.
1.4.4|Modelul conceptual al datelor|Modelarea copilului, adultului, legăturii de acces, planului, sesiunii, încercării și consimțământului.|Diagramă conceptuală cu relații și cardinalități.|Fiecare dată necesară are entitate și scop; nu apar date fără justificare.
1.4.5|Stările sesiunii și sincronizării|Modelarea sesiunii active, întrerupte și încheiate și a transferului în așteptare, confirmat sau reîncercat.|Diagrame de stări.|Fiecare tranziție are declanșator; salvarea parțială nu devine finalizare completă.
1.5|Proiectarea soluției|Definirea arhitecturii și a contractelor tehnice înaintea implementării.|Proiect tehnic al sistemului.|-
1.5.1|Arhitectura sistemului|Proiectarea clientului Flutter offline-first, panoului Flutter Web, API-ului NestJS și workerului BullMQ.|Diagrame de componente și desfășurare; decizii arhitecturale.|Fiecare componentă are responsabilitate, interfețe și tehnologie argumentată.
1.5.2|Stocarea locală și centrală|Proiectarea schemelor SQLite/Drift și PostgreSQL, a indexurilor și a stocării S3.|Scheme fizice și plan de migrare.|Sunt definite integritatea relațiilor, retenția și separarea datelor locale de cele sincronizate.
1.5.3|API-ul și contractele de sincronizare|Definirea REST, a mesajelor live, a identificatorilor și a confirmării transferului sesiunilor.|Contracte API și reguli de idempotență.|Retrimiterea aceleiași sesiuni nu produce o dublură în contractul definit.
1.5.4|Securitatea și confidențialitatea|Proiectarea autentificării, verificării accesului, consimțămintelor, exportului și ștergerii.|Model de amenințări și controale de securitate.|Fiecare risc prioritar are control și scenariu de test asociat.
1.5.5|Interfețele și accesibilitatea|Proiectarea ecranelor landscape, a navigației, feedbackului blând și panourilor pe roluri.|Prototipuri și reguli de interacțiune.|Prototipurile acoperă fluxurile principale, țintele de 64 dp și modul calm.
1.5.6|Motorul și integrările|Proiectarea GameConfig, a metricilor, pachetelor de conținut, cozilor și adaptorului AI pentru adulți.|Contracte ale modulelor și integrărilor.|Sunt definite limitele nivelurilor, lipsa rețelei, retry și datele permise către AI.
1.6|Realizarea soluției|Implementarea modulelor și integrarea lor într-o versiune demonstrabilă.|Sistemul Licurici executabil în mediul de test.|-
1.6.1|Infrastructura de dezvoltare și livrare|Pregătirea mediilor și a pachetelor de instalare.|Mediu reproductibil de dezvoltare și demonstrație.|-
1.6.1.1|Monorepo și verificări automate|Organizarea aplicațiilor și pachetelor comune; configurarea comenzilor de analiză, teste și build.|Repozitoriu organizat și flux automat de verificare.|O modificare de probă declanșează verificările configurate; erorile blochează livrarea.
1.6.1.2|Serviciile Docker|Configurarea API, worker, PostgreSQL, Redis și stocării S3 în Docker Compose.|Mediu local complet și configurație fără secrete versionate.|Serviciile pornesc pe un mediu curat și trec verificările de sănătate.
1.6.1.3|Pachetele și mediul de demonstrație|Construirea APK-ului Android și a panoului web; configurarea unui mediu de test și a salvării/restaurării datelor.|Versiune identificabilă și procedură de restaurare.|APK-ul se instalează, panoul accesează API-ul, iar restaurarea unui set sintetic reușește.
1.6.2|Serviciile centrale și accesul|Implementarea funcțiilor comune ale serverului.|API securizat și model de date funcțional.|-
1.6.2.1|Entitățile și migrările|Implementarea modulelor NestJS, a schemei PostgreSQL și a migrărilor.|Server compilabil și schemă inițială.|Migrările rulează pe o bază goală și păstrează integritatea relațiilor.
1.6.2.2|Conturile adulților|Implementarea înregistrării, confirmării e-mailului, autentificării și recuperării accesului.|Fluxuri de cont pentru adulți.|Scenariile valide funcționează; tokenurile expirate sau reutilizate sunt respinse.
1.6.2.3|Accesul și partajarea copilului|Implementarea verificării drepturilor și a invitației/revocării specialistului.|Control de acces pe copil și legături de partajare.|Un adult neautorizat nu citește datele; revocarea elimină accesul specialistului.
1.6.2.4|Consimțământul și drepturile asupra datelor|Implementarea acordurilor pe scopuri, exportului și fluxului de ștergere.|Jurnal de consimțăminte, export și ștergere controlată.|Retragerea oprește prelucrările aferente; exportul și ștergerea trec scenariile stabilite.
1.6.3|Aplicația copilului și sesiunile locale|Implementarea experienței de bază și a persistenței pe dispozitiv.|Aplicație utilizabilă fără cont și fără internet.|-
1.6.3.1|Navigația și profilul local|Implementarea ecranelor pe arii, a setărilor și a porții de acces pentru adulți.|Navigație landscape și profil local persistent.|Aplicația pornește fără rețea; setările se păstrează după repornire.
1.6.3.2|Interacțiunea accesibilă|Integrarea MotionPolicy, a comutatoarelor audio și a feedbackului fără pedeapsă.|Comportament senzorial coerent.|Țintele au minimum 64 dp; modul calm și reduce-motion se aplică tuturor animațiilor.
1.6.3.3|Planul și desfășurarea sesiunii|Implementarea ordinii jocurilor, pauzelor, limitei zilnice și repetărilor configurate de adult.|Sesiune controlată de plan și setări.|Limita oprește continuarea, salvează încercările și nu marchează jocul parțial drept încheiat.
1.6.3.4|Înregistrarea și salvarea locală|Salvarea încercărilor, ajutorului, latenței și nivelului în Drift/SQLite; măsurarea duratelor cu Stopwatch.|Istoric local și sesiuni recuperabile.|Întreruperea și reluarea nu pierd încercările deja salvate și nu dublează finalizarea.
1.6.4|Motorul de jocuri și conținutul|Implementarea mecanicilor, progresiei și materialelor folosite de copil.|Catalog de activități integrat în motorul comun.|-
1.6.4.1|Contractele și dificultatea jocurilor|Implementarea configurației comune, a ajutorului gradual, metricilor și regulilor de progresie.|Nucleu Dart și scări de dificultate explicite.|Fiecare joc are metadate și limite documentate; creșterea nivelului schimbă efectiv sarcina.
1.6.4.2|Atenție, imitație și potrivire|Implementarea jocurilor de reacție, imitație, sortare, memorie și puzzle din aceste arii.|Jocuri executabile pentru cele trei arii.|Toate intrările catalogului sunt realizate și acoperite de scenarii pentru treptele lor.
1.6.4.3|Înțelegere, vorbire și AAC|Implementarea instrucțiunilor, asocierilor audio, propozițiilor și tablei de comunicare augmentativă și alternativă.|Activități de limbaj și tablă AAC disponibilă integral.|Instrucțiunile sunt în română; AAC poate fi folosit fără deblocare prin performanță.
1.6.4.4|Gândire, emoții și deprinderi|Implementarea jocurilor de logică, emoții, relaționare, autonomie, numere și litere din catalogul de bază.|Activități pe arii și inventar de acoperire.|Fiecare joc din ariile alocate are configurație, rezultate și scenarii verificabile.
1.6.4.5|Explorări și activități libere|Implementarea episoadelor narative, colorării și respirației, cu salvarea progresului.|Explorări cu opriri și activități fără competiție.|Episodul complet contează o singură dată; activitățile libere nu impun niveluri competitive.
1.6.4.6|Ilustrațiile și vocea română|Integrarea ilustrațiilor pictate prin StimulusArt și a clipurilor vocale cu manifest de acoperire.|Pachet vizual și audio offline.|Fiecare frază rostită are clip românesc; imaginile sunt verificate, fără emoji de sistem.
1.6.5|Recompensele și acvariul|Implementarea recompenselor și a activității creative cu pești.|Acvariu și colecții locale integrate.|-
1.6.5.1|Stelele și albumul|Implementarea acordării stelelor, a pușculiței și a albumului de recompense.|Recompense persistente și feedback blând.|Aceeași finalizare nu acordă dublu recompensa; greșelile nu retrag stele.
1.6.5.2|Colorarea și scanarea peștilor|Implementarea colorării digitale și a importului din fișa fotografiată, cu procesare locală.|Pești personalizați salvați pe dispozitiv.|Ambele fluxuri produc un pește utilizabil; fotografia brută nu se păstrează.
1.6.5.3|Scena și interacțiunile acvariului|Integrarea peștilor, hrănirii, recifului și cufărului, cu animații procedurale.|Scenă interactivă adaptată politicii de mișcare.|Modul calm este respectat, țintele au 64 dp și bugetul total nu depășește 40 de particule.
1.6.6|Panoul părintelui și specialistului|Implementarea interfeței Flutter Web pentru cele două roluri.|Panou comun cu funcții și acces diferențiate.|-
1.6.6.1|Panoul părintelui|Implementarea selectării copilului, istoricului, progresului și configurării setărilor permise.|Ecranele părintelui.|Datele apar doar pentru copiii autorizați; datele demonstrative sunt etichetate distinct.
1.6.6.2|Panoul specialistului|Implementarea listei copiilor partajați, căutării, fișei de progres și notițelor.|Ecranele specialistului.|Specialistul vede numai copiii partajați și poate consulta separat progresul fiecăruia.
1.6.6.3|Constructorul planului de lucru|Generarea formularelor din GameConfig și salvarea ordinii, nivelurilor, repetărilor și limitei zilnice.|Plan personalizat și validat.|Parametrii nevalizi sunt respinși; planul salvat poate fi preluat de aplicația copilului.
1.6.6.4|Interfața de confidențialitate|Implementarea ecranelor de acord, partajare, retragere, export și ștergere, conectate la API.|Interfață pentru controlul datelor.|Fiecare acțiune afișează rezultatul real al API-ului și tratează refuzul sau eroarea.
1.6.7|Sincronizarea și raportarea|Transferul controlat al sesiunilor și prezentarea progresului centralizat.|Date sincronizate și rapoarte consecvente.|-
1.6.7.1|Transferul sesiunilor și planurilor|Implementarea cozii locale, retrimiterii și confirmării sesiunilor; preluarea planului.|Sincronizare idempotentă și plan disponibil offline.|Retrimiterea nu dublează sesiunea; datele neconfirmate rămân disponibile pentru retry.
1.6.7.2|Statisticile pe abilități|Implementarea joburilor BullMQ, agregărilor și invalidării cache-ului Redis.|Statistici centrale reproductibile.|Agregatele coincid cu calculul manual pentru un set de sesiuni sintetice.
1.6.7.3|Rapoartele și sesiunea live|Afișarea indicatorilor și istoricului; implementarea actualizărilor prin WebSocket.|Grafice și actualizări live în panou.|O sesiune confirmată actualizează panoul autorizat; lipsa conexiunii live este semnalată.
1.6.7.4|Notificările și fișierele|Implementarea e-mailurilor pentru cont și rapoarte, a cozilor și a stocării fișierelor de conținut/export.|Integrări de e-mail și stocare S3.|Mesajele de test sunt livrate; retry nu dublează notificările, iar fișierele private cer autorizare.
1.6.8|Asistentul AI pentru adulți|Implementarea rezumatelor și răspunsurilor despre progres, numai în panoul adultului.|Asistent conectat la statistici și controlat prin acord.|-
1.6.8.1|Pregătirea contextului permis|Selectarea statisticilor agregate și eliminarea identificatorilor și a notițelor libere din contextul transmis.|Contract de context pseudonimizat.|Datele trimise sunt afișabile pentru verificare; nu includ nume, e-mailuri sau notițe brute.
1.6.8.2|Serviciul AI din backend|Implementarea adaptorului de furnizor, verificării acordului, limitării cererilor, cache-ului și timeoutului.|Serviciu de rezumate și întrebări despre progres.|Fără acord nu pleacă cereri; cheia rămâne pe server; erorile externe sunt tratate.
1.6.8.3|Interfața asistentului pentru adult|Implementarea rezumatului și a întrebărilor, cu indicarea limitelor și a provenienței statisticilor.|Ecrane AI pentru părinte și specialist.|Funcția nu apare în aplicația copilului; răspunsul nu este prezentat ca diagnostic sau prescripție.
1.7|Testarea și validarea|Verificarea sistemului integrat față de cerințele stabilite.|Dovezi de funcționare și limitări declarate.|-
1.7.1|Planul și cazurile de test|Definirea mediilor, seturilor sintetice și scenariilor; asocierea cerințelor cu testele.|Plan de test și matrice de trasabilitate.|Fiecare cerință inclusă are cel puțin un scenariu cu rezultat așteptat.
1.7.2|Testele unitare și de integrare|Verificarea nucleului Dart, widgeturilor, serviciilor API și workerului cu stocările reale de test.|Suite automate și rapoarte de execuție.|Suitele trec; testele cu baze simulate sunt diferențiate de cele cu PostgreSQL/Redis reale.
1.7.3|Fluxurile complete și modul offline|Testarea planului, jocului, salvării, repornirii, sincronizării și apariției progresului în panou.|Raport end-to-end pe dispozitiv și server.|Fluxul reușește după întreruperea rețelei, fără pierderi ori dublări de sesiuni.
1.7.4|Accesibilitatea și performanța|Verificarea pe telefon și tabletă a țintelor, modului calm, sunetului și fluidității scenelor.|Măsurători și raport vizual pe dispozitiv.|Țintele respectă 64 dp; mișcarea respectă politica; măsurătorile indică dispozitivul și configurația.
1.7.5|Securitatea și protecția datelor|Testarea izolării între conturi, revocării, consimțământului, exportului, ștergerii și jurnalelor.|Raport de verificare a controalelor.|Nu se poate accesa copilul altui cont; retragerea blochează prelucrările vizate.
1.7.6|Verificarea asistentului AI|Evaluarea răspunsurilor pe seturi sintetice, inclusiv date insuficiente, solicitări clinice și erori ale furnizorului.|Grilă de evaluare și exemple de răspunsuri.|Nu inventează valori din progres; cazurile nesigure sunt tratate; limitările sunt consemnate.
1.7.7|Validarea cu adulți și remedierea|Parcurgerea scenariilor cu părinte și specialist; înregistrarea defectelor, corectarea și retestarea.|Feedback, registru de defecte și raport final.|Fluxurile critice sunt acceptate; defectele blocante sunt închise; limitările rămase sunt explicite.
1.8|Documentarea|Pregătirea documentelor necesare utilizării și evaluării proiectului.|Documentație tehnică, ghiduri și teză.|-
1.8.1|Documentația tehnică|Descrierea arhitecturii, API-ului, schemelor, instalării, restaurării și deciziilor tehnice.|README, specificații și ghid de operare.|Instalarea într-un mediu curat poate fi repetată exclusiv pe baza instrucțiunilor.
1.8.2|Ghidurile de utilizare|Redactarea ghidurilor pentru părinte și specialist și a indicațiilor de asistare a copilului.|Ghiduri ilustrate pe roluri.|Sunt acoperite planul, sesiunea, progresul, acordurile și limitele AI.
1.8.3|Teza de licență|Redactarea analizei, proiectării, implementării și evaluării; completarea bibliografiei și anexelor.|Teză conform cerințelor universitare.|Capitolele corespund realizării; afirmațiile au surse sau dovezi; observațiile coordonatorului sunt tratate.
1.8.4|Prezentarea și demonstrația|Pregătirea diapozitivelor, scenariului demo și a unei înregistrări de rezervă.|Prezentare și demonstrație reproductibilă.|Scenariul arată jocul offline, planul, sincronizarea, progresul și AI pe date sintetice.
1.9|Managementul proiectului|Planificarea, urmărirea și finalizarea lucrării de licență.|Proiect urmărit până la susținere.|-
1.9.1|WBS și planificarea ulterioară|Definirea WBS; ulterior, estimarea duratelor/costurilor și construirea dependențelor, PERT și Gantt.|WBS codificat și planul proiectului în etapele următoare.|WBS are rezultate verificabile; estimările și calendarul se completează în lucrările ulterioare.
1.9.2|Progresul, riscurile și consultările|Urmărirea lucrărilor, consultarea coordonatorului și gestionarea riscurilor de integrare și validare.|Registru de progres, riscuri și decizii.|Fiecare risc prioritar are măsură și responsabil; schimbările de perimetru sunt consemnate.
1.9.3|Pre-susținerea și susținerea|Participarea la pre-susținere, aplicarea observațiilor și prezentarea finală a tezei.|Observații rezolvate și proiect prezentat.|Materialele finale sunt predate, iar demonstrația și susținerea sunt efectuate.
'''

ROWS = [dict(zip(('code','name','work','result','done'), line.split('|'))) for line in DATA.strip().splitlines()]
BY_CODE = {r['code']:r for r in ROWS}
def children(code):
    if code == '1.0':
        return [r for r in ROWS if r['code'].count('.') == 1 and r['code'] != '1.0']
    return [r for r in ROWS if r['code'].startswith(code+'.') and r['code'].count('.') == code.count('.')+1]
LEAVES = [r for r in ROWS if not children(r['code'])]

def validate():
    assert len(BY_CODE)==len(ROWS)
    for r in ROWS:
        if r['code'].count('.')>1:
            assert r['code'].rsplit('.',1)[0] in BY_CODE
        assert bool(children(r['code'])) == (r['done']=='-'), r['code']
    assert len(ROWS)==1+9+8+len(LEAVES)
    assert len(children('1.6'))==8
    return {'elements':len(ROWS),'components':9,'intermediate':8,'packages':len(LEAVES),'implementation_packages':sum(r['code'].startswith('1.6.') for r in LEAVES)}

if __name__=='__main__':
    print(validate())
