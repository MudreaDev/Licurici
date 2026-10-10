# 05 · Securitatea și protecția datelor copiilor: de la lege la cod

*Capitol de cercetare pentru teză (README §23). Starea din sesiunea a unsprezecea (11.10.2026). ADR-uri legate: 012, 020, 029, 032. Documentele juridice (ciorne): [docs/gdpr/](../gdpr/README.md).*

> Acesta e un capitol tehnic: arată cum fiecare cerință legală devine o regulă în cod și un test. Interpretarea juridică finală aparține unui jurist (README §0.0 D).

## 1. De ce e un caz special

Licurici prelucrează date despre **copii între 2 și 12 ani**, mulți cu tulburări de dezvoltare. Trei motive pentru care cerințele sunt mai stricte decât la o aplicație obișnuită:

1. **Copiii nu pot consimți.** Sub 14 ani (Legea RM 195/2024; în UE, între 13 și 16 după stat — GDPR art. 8), consimțământul îl dă părintele, iar operatorul trebuie să facă „eforturi rezonabile” să verifice asta.
2. **Datele de progres pot sugera o condiție de sănătate** (categorie specială, GDPR art. 9). Faptul că un copil exersează „recunoașterea emoțiilor” la 8 ani spune ceva. De aceea **nu cerem niciodată diagnosticul** și tratăm toate datele de progres ca sensibile.
3. **Copilul nu poate citi o politică de confidențialitate**, deci protecția trebuie să fie implicită, nu o opțiune de bifat.

Cadrul: GDPR (utilizatori din UE) + Legea RM 195/2024 (în vigoare din 23.08.2026, transpune substanțial GDPR) + politicile magazinelor (Google Play Families, Apple Kids Category).

## 2. Principiul de bază: datele nu pleacă fără un adult care a ales asta

| Mod | Ce se întâmplă cu datele | Cine poate vedea |
|---|---|---|
| **Fără cont** (implicit) | Totul rămâne în SQLite pe tabletă. Zero cereri de rețea. | Doar cine are tableta și trece poarta pentru adulți. |
| Cont + acord `SYNC` | Sesiunile pleacă pe server la cerere sau automat. | Părintele, în panou. |
| + acord `THERAPIST_SHARING` + invitație | Specialistul ales vede datele, **doar citire**, pe termen limitat (implicit 90 de zile). | Părintele și specialistul. |
| + acord `AI_SUMMARY` | Faptele agregate ale unei sesiuni (fără poreclă, fără id) merg la Claude pentru un rezumat. | Furnizorul AI, ca împuternicit, fără drept de antrenare. |

Fiecare pas e un **acord separat**, retractabil oricând la fel de ușor cum a fost dat (GDPR art. 7(3)), păstrat într-un **jurnal append-only** — fiecare decizie e un rând nou, cu versiunea politicii acceptate (dovada, art. 7(1)).

## 3. Cerință → măsură → dovadă

### 3.1 Consimțământ (GDPR art. 7–8, Legea 195/2024)

| Cerința | Măsura în cod | Dovada |
|---|---|---|
| Consimțământ separat pe scopuri, fără bife pre-completate | 5 scopuri (`consentPurposes`), fiecare cu decizia lui; implicit: niciunul | `sync.spec.ts` — scop necunoscut respins |
| Doar părintele consimte | `ConsentService.set` refuză orice rol în afară de `PARENT` | `sync.spec.ts` |
| „Efort rezonabil” de verificare a părintelui | **Acordul se poate da doar de pe o adresă de e-mail confirmată** (legătură unică, 48 h); retragerea merge oricând (sesiunea 11) | `sync.spec.ts` — „acordul se dă doar de pe o adresă confirmată” |
| Fără acord, nicio prelucrare | Sincronizarea, prezența „se joacă acum”, partajarea și rezumatele AI verifică fiecare acordul lor la **fiecare** cerere (nu doar o dată) | `sync.spec.ts` — 403 și după retragere |
| Dovada consimțământului după ștergerea contului | Arhivă fără identificatori (scop, versiune, dată, hash-ul id-ului), 3 ani (`consent_archive`) | `gdpr.processor.ts`, `retention.spec.ts` |

### 3.2 Minimizare și confidențialitate prin design (art. 5(1)(c), art. 25)

- **Ce nu colectăm:** numele real (doar o poreclă), data nașterii (doar anul, opțional), fotografii (fișa scanată se procesează în memorie și se aruncă), audio/video, locație, identificatori de publicitate, diagnostic. Fără SDK-uri de analiză sau reclame în aplicația copilului.
- **Schema strictă pe server:** corpul sincronizării e validat cu zod `.strict()` — un câmp neprevăzut (de exemplu un nume adăugat din greșeală într-o versiune viitoare a tabletei) e **respins**, nu salvat (`sync.spec.ts` — „câmpurile în plus (ex. un nume) sunt respinse”). Orice dată nouă despre copil cere deci o schimbare explicită în schemă, în README §11/§13 și în RoPA.
- **Pseudonimizare spre AI:** Claude primește doar faptele agregate (`SessionReport.toAiJson()`): procente, număr de încercări, tipuri de confuzii — fără poreclă, fără id (ADR-029).
- **Jurnale fără date personale:** fiecare cerere se notează doar cu metoda, calea fără parametri, codul și **IP-ul trunchiat** (IPv4 /24, IPv6 /48) — `common/log-privacy.ts`; Sentry fără cerere, utilizator, breadcrumbs sau e-mailuri (`common/sentry.ts`).
- **Desenele copilului** (pești colorați, pagini de colorat) rămân doar pe tabletă.

### 3.3 Controlul accesului

Regula, într-un singur loc (`children/access.ts`): **părintele** — citire și scriere pentru copiii lui; **specialistul** — doar citire, doar cât `CareLink` e activ și neexpirat (cu o singură excepție de scriere: planul de jocuri, ADR-031, auditat); **oricine altcineva — 404**, nu 403, ca să nu afle nici măcar că acel copil există.

| Proprietate | Dovada |
|---|---|
| Alt părinte → 404 | `sync.spec.ts` — `ChildAccess` |
| Specialistul fără partajare sau cu partajarea expirată → 404 | `sync.spec.ts`, `sharing.spec.ts` |
| Copilul șters → inaccesibil și părintelui | `sync.spec.ts` |
| Canalul live aplică aceeași regulă | `live.spec.ts`, testul de fum cu Socket.IO real |
| **Fiecare accesare a specialistului intră în jurnalul de audit**, iar părintele o vede în export (cine și când) | `sync.spec.ts`, `gdpr.spec.ts` (sesiunea 11) |

### 3.4 Autentificare

| Amenințare | Măsura |
|---|---|
| Parole slabe / baze de date furate | Argon2id (parametrii OWASP), parola nu se păstrează niciodată în clar |
| Ghicirea parolei | Blocare 15 minute după 5 încercări greșite, pe hash-ul e-mailului — și pentru adrese fără cont (nu dezvăluie cine e înscris) |
| Token de acces furat | Valabil 15 minute |
| Refresh token furat | Opac, păstrat ca hash, de unică folosință (`GETDEL` atomic): o reutilizare e refuzată |
| Parola schimbată / cont compromis | „Generația” utilizatorului se schimbă → **toate** sesiunile se închid deodată |
| Phishing / parolă refolosită | 2FA TOTP (RFC 6238, implementat fără biblioteci externe, testat pe vectorii oficiali), opțional pentru orice cont, recomandat specialiștilor |
| Enumerarea conturilor | „Am uitat parola” și blocarea după parole greșite răspund la fel pentru orice adresă; autentificarea are timp constant (hash fictiv pentru adresele inexistente). **Excepție:** înregistrarea spune „există deja un cont” (vezi §4) |
| Tableta pierdută | Doar refresh tokenul, în stocarea securizată a sistemului (Keystore / Keychain / DPAPI); niciodată parola |

### 3.5 Drepturile părintelui (art. 15–20)

| Drept | Implementare |
|---|---|
| Acces + portabilitate | `GET /me/export`: JSON complet (cont, jurnalul acordurilor, copiii cu toate sesiunile și rezumatele, **accesările specialiștilor**), descărcat ca fișier |
| Ștergerea copilului | Acces tăiat imediat, ștergere definitivă după 7 zile (anularea greșelilor), job idempotent |
| Ștergerea contului | Cere parola din nou; copii, partajări (și cele în care contul e specialistul), e-mail anonimizat imediat; definitiv după 7 zile |
| Retragerea acordului | Oricând, din panou; efect imediat la următoarea cerere |
| Ștergerea datelor de pe tabletă | „Pentru părinți” → sesiuni, setări, abțibilduri, stele, acvariu, desene |

### 3.6 Retenție (art. 5(1)(e))

Job zilnic în worker (`gdpr/retention.ts`, programat idempotent): sesiunile mai vechi de **24 de luni** se șterg; arhivele acordurilor mai vechi de **3 ani** se șterg; partajările expirate dispar. Backup-urile criptate (age) se rotesc la 35 de zile, deci o ștergere ajunge și în backup în cel mult 35 de zile.

## 4. Ce rămâne deschis (riscuri reziduale)

| Măsură | Stare | De ce încă nu |
|---|---|---|
| Criptarea volumului bazei de date | 🕓 | Ține de VPS (criptarea discului la furnizor sau LUKS); de făcut la primul deploy |
| Criptarea câmpului e-mail (`pgcrypto` + hash pentru căutare) | 🕓 | Necesită migrare + gestiunea cheii; riscul rezidual e trecut în DPIA ca „mediu” până atunci |
| SQLite criptat pe tabletă (SQLCipher) | opțional | Datele de pe tabletă sunt deja în spațiul privat al aplicației; criptarea ar proteja doar o tabletă cu root/jailbreak |
| 2FA obligatorie pentru specialiști | decizie | Utilizatorul (README §0.0 D) |
| Verificarea juridică a documentelor și identitatea operatorului | 🕓 | Jurist (README §0.0 D) |
| Înregistrarea dezvăluie dacă o adresă are cont (409) | acceptat deocamdată | Remedierea standard (răspuns identic + e-mail „cineva a încercat să-și facă un cont cu adresa ta”) schimbă fluxul de înregistrare din panou; riscul e mic: existența unui cont nu spune nimic despre copii (nici câți sunt, nici dacă există) |

## 5. Alternative la deciziile-cheie

| Decizie | Alternativa | De ce nu |
|---|---|---|
| Doar adulții au conturi (ADR-012) | Cont pentru copil | Ar cere date despre copil (e-mail, parolă) fără niciun beneficiu; copilul nu are nevoie să se autentifice pe propria tabletă |
| E-mail confirmat ca „efort rezonabil” | Verificare cu card bancar (micro-plată) sau act de identitate | Disproporționat pentru riscul datelor noastre; exclude familiile fără card; colectează *mai multe* date. Verificarea prin e-mail e metoda acceptată pentru servicii cu risc moderat (de ex. ghidurile FTC pentru COPPA, „email plus”) |
| Găzduire în UE, VPS propriu (ADR-020) | Firebase / un cloud american | Transferuri internaționale, mai mulți împuterniciți, control redus asupra locației datelor |
| AI pe fapte agregate | Fără AI deloc | Rezumatele ajută părinții să înțeleagă progresul; riscul e controlat prin agregare, acord separat și rezervă din reguli. Cine nu vrea, nu bifează |
| 404 pentru „nu ai acces” | 403 | 403 confirmă că resursa există — pentru un copil, chiar și existența e o informație |

## 6. Rezumat pentru susținere (60 s)

*Problema:* date despre copii mici, posibil cu dizabilități, într-o aplicație folosită de părinți și specialiști. *Principiul:* nimic nu pleacă de pe tabletă fără un adult care a ales explicit, pe scopuri separate, de pe o adresă confirmată. *Măsuri:* minimizare (fără nume, diagnostic, fotografii), schemă strictă pe server, acces într-un singur loc testat (404 pentru străini, specialistul doar citire, cu termen și audit), tokenuri rotite de unică folosință, 2FA, export complet cu jurnalul accesărilor, ștergere în două etape, retenție automată. *Deschis:* criptarea volumului și a e-mailului, verificarea juridică. *Verificat* prin teste de acces, consimțământ, idempotență și contract.
