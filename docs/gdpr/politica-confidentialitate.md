# Politica de confidențialitate Licurici

> Ciornă — de verificat de un jurist înainte de publicare (vezi [README](README.md)).
> Versiunea politicii: **2026-10** (aceeași valoare se salvează la fiecare consimțământ — `privacyPolicyVersion`).

## 1. Cine suntem
Licurici este o aplicație de jocuri terapeutice pentru copii (inclusiv copii cu tulburări de spectru
autist), cu un panou web pentru părinți și specialiști.

**Operatorul datelor:** […nume / denumire…], […adresă…], contact pentru protecția datelor:
[…e-mail…]. Autoritatea de supraveghere: **CNPDCP** (Republica Moldova, datepersonale.md); pentru
utilizatorii din România: **ANSPDCP**.

## 2. Pe scurt
- **Copilul nu are cont.** Aplicația copilului funcționează complet **fără internet și fără cont**; tot
  ce face copilul rămâne pe tabletă, dacă părintele nu alege altfel.
- **Nu cerem și nu păstrăm** numele real al copilului, data completă a nașterii, fotografii ale
  copilului, înregistrări audio/video, locația, contactele sau un diagnostic medical.
- **Fără reclame, fără analytics, fără urmărire** în aplicația copilului.
- Datele ajung pe server **doar dacă părintele își face cont și dă acordul** pentru sincronizare.
- Părintele poate vedea, copia, șterge orice și își poate retrage oricând acordurile.

## 3. Ce date prelucrăm, de ce și pe ce temei

| Date | Despre cine | De ce | Temei | Unde |
|---|---|---|---|---|
| E-mail, parola (doar ca hash Argon2id) | Părinte / specialist | Contul și autentificarea | Contract | Server |
| Acordurile date sau retrase (scop, versiunea politicii, data, hash al IP-ului) | Părinte | Dovada consimțământului | Obligație legală | Server |
| Poreclă (aleasă de părinte), avatar, anul nașterii, clasa | Copil | Adaptarea conținutului | Consimțământul părintelui | Tabletă; server doar cu acordul „Sincronizare” |
| Setări senzoriale (modul calm, volum, mișcări reduse) | Copil | Confort, siguranță senzorială | Consimțământul părintelui | Tabletă; server doar cu acordul „Sincronizare” |
| Sesiunile de joc: ce joc, nivelul, ce s-a ales, corect/greșit, ajutorul dat, timpi de răspuns, dispoziția aleasă de copil („Cum te simți?”), cererile din tabla de comunicare | Copil | Progresul, dificultatea adaptivă, rezumatul pentru părinte și specialist | Consimțământul părintelui | Tabletă; server doar cu acordul „Sincronizare” |
| Rezumatul unei sesiuni scris de AI | Copil (pseudonimizat) | Explicarea progresului în cuvinte | Consimțământ separat „Rezumate AI” | Server |
| „Se joacă acum” în panou | Copil (pseudonimizat): doar faptul că are o sesiune deschisă | Panoul în timp real | Acordul de sincronizare + trimiterea automată pornită de părinte | Maximum 20 de minute (memorie temporară pe server) |
| Răspunsuri AI la întrebările adultului („Întreabă despre progres”) | Copil (pseudonimizat): faptele agregate ale ultimelor 20 de sesiuni; întrebarea adultului | Explicarea progresului în cuvinte | Același consimțământ „Rezumate AI” | Nu se păstrează (nici întrebarea, nici răspunsul) |
| Abțibildurile, stelele, peștii din acvariu (desenele copilului) | Copil | Recompense în joc | Consimțământul părintelui | **Doar pe tabletă**, nu se trimit nicăieri |
| Jurnalul de audit (cine a accesat / exportat / șters, când) | Părinte / specialist | Securitate, responsabilizare | Obligație legală / interes legitim | Server |

**Fotografia fișei de colorat** (acvariul): se face cu camera telefonului, se analizează pe loc pe
dispozitiv ca să se decupeze peștele, apoi **nu se păstrează**. Rămâne doar desenul peștelui, pe
tabletă.

**Diagnosticul:** nu îl cerem. Modul calm și setările senzoriale se aleg fără nicio întrebare despre
sănătate. Totuși, faptul că o familie folosește o aplicație terapeutică poate sugera informații despre
sănătate; de aceea tratăm toate datele copilului cu nivelul de protecție al datelor sensibile.

## 4. Copiii și consimțământul părintelui
Utilizatorii aplicației copilului au sub 14 ani. Consimțământul îl dă **părintele / reprezentantul
legal** (Legea 195/2024; GDPR art. 8). Setările și acordurile se schimbă doar după **poarta pentru
adulți** din aplicație. Acordurile sunt separate pe scopuri, niciunul nu e bifat implicit și se pot
retrage la fel de ușor cum se dau (panoul web → „Contul meu”).

Scopurile pentru care cerem acord separat: **Sincronizarea sesiunilor**, **Rezumate scrise de AI**,
**Partajarea cu specialistul**, 🕓 **Raport săptămânal pe e-mail**, 🕓 **Notificări**.

## 5. Cine mai vede datele
- **Specialistul invitat de părinte** (logoped, psiholog, terapeut ABA): doar copilul pentru care
  părintele l-a invitat, **doar citire, pe timp limitat** (implicit 90 de zile), revocabil oricând.
  Fiecare acces e notat în jurnalul de audit.
- **Furnizorii care ne ajută** (împuterniciți), fiecare cu un acord de prelucrare: găzduirea
  serverului; **Anthropic** (Claude), doar pentru rezumatele AI, **doar dacă părintele a dat acordul** —
  primește doar cifre agregate ale unei sesiuni, **fără poreclă, fără nume, fără identificatori**. Lista
  completă: [lista-imputerniciti.md](lista-imputerniciti.md).
- **Nu vindem** date și nu le folosim pentru reclame.

## 6. Cât timp păstrăm
Rezumat (detalii în [politica-retentie.md](politica-retentie.md)): datele contului — cât există contul;
sesiunile copilului — cel mult 24 de luni; dovezile consimțământului — durata contului + 3 ani;
jurnalele tehnice — 30 de zile. La ștergere, accesul se oprește imediat, iar datele se șterg definitiv
după **7 zile** (perioada în care se poate anula o greșeală, scriind la suport).

## 7. Drepturile tale
Acces, rectificare, ștergere, restricționare, opoziție, portabilitate, retragerea consimțământului,
plângere la autoritate. Majoritatea se exercită direct din panou: **„Contul meu” → Datele mele** (export
complet, fișier JSON), **Șterge profilul** (un copil), **Șterg contul** (cu parola), comutatoarele de acord.
Pentru restul: […e-mail…]. Răspundem în cel mult **o lună** (detalii în
[procedura-drepturi.md](procedura-drepturi.md)).

## 8. Securitate
Conexiuni criptate (TLS); parolele doar ca hash Argon2id; autentificare în doi pași (cod din aplicația
de autentificare), recomandată specialiștilor; blocare temporară după încercări greșite; sesiuni scurte (15 minute) cu reîmprospătare
de unică folosință; acces verificat la fiecare cerere (părintele doar la copiii lui, specialistul doar cu
partajare activă); jurnal de audit; date minimizate prin design. În caz de incident, procedura e în
[procedura-incident.md](procedura-incident.md).

## 9. Transferuri în afara spațiului european
Rezumatele AI (doar cu acord) sunt generate de Anthropic, cu sediul în SUA, pe baza clauzelor
contractuale standard / a garanțiilor din acordul de prelucrare. Fără acordul „Rezumate AI”, nu există
transfer în afara SEE/Republicii Moldova. […de confirmat regiunea serverului…]

## 10. Modificări
Versiunea politicii se salvează la fiecare acord. La o schimbare importantă, cerem din nou acordul.

---

## Pentru copii (pe înțeles)

> Se citește împreună cu un adult. Pe ecran, cu imagini.

- **Licurici este prietenul tău de joacă.** Nu-ți cere numele adevărat și nu-ți face poze.
- **Ce faci în joc rămâne pe tableta ta.** Doar mama, tata sau cine are grijă de tine poate alege să
  trimită jocurile tale, ca să vadă cum te descurci.
- **Desenele tale de pești rămân la tine**, în acvariul tău.
- **Nu există reclame** și nimeni nu-ți vinde nimic.
- **Dacă ceva te supără**, spune-i unui adult. Adultul poate șterge oricând tot.
