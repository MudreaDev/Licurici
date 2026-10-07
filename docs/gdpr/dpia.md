# Evaluarea impactului asupra protecției datelor (DPIA)

> Ciornă — de completat și semnat de operator; de verificat de un specialist (vezi [README](README.md)).
> Data: 2026-10-08. Revizuire: la fiecare funcție nouă care prelucrează date ale copilului, cel puțin anual.

## 1. De ce e necesară
Criterii întrunite: **persoane vulnerabile** (copii, inclusiv copii cu TSA), **monitorizarea
sistematică a progresului**, **tehnologie nouă** (rezumate generate de AI), **partajare cu terți
profesioniști**. Chiar dacă nu cerem diagnostic, contextul terapeutic poate dezvălui informații despre
sănătate → tratăm datele ca sensibile.

## 2. Descrierea prelucrării
- **Aplicația copilului** (tabletă/telefon, offline): jocuri pe arii de dezvoltare; fiecare rundă =
  o încercare măsurată (corect, ajutor P0–P4, latență). Date locale (SQLite/Drift).
- **Sincronizarea** (opțională, cu acord): sesiunile pseudonimizate pleacă spre server (NestJS +
  PostgreSQL), unde le vede părintele în panou și, dacă e invitat, specialistul.
- **Rezumatele AI** (opțional, cu acord separat): faptele agregate ale unei sesiuni → Claude
  (Anthropic) → un text pentru părinte și unul pentru specialist.
- **Acvariul**: desenele copilului rămân pe dispozitiv; fotografia fișei se procesează pe dispozitiv și
  se aruncă.

## 3. Necesitate și proporționalitate
| Principiu | Cum îl respectăm |
|---|---|
| Minimizare | Fără nume real, dată completă a nașterii, foto, audio, locație, diagnostic, ID de publicitate. Poreclă aleasă de părinte. |
| Limitarea scopului | Datele de joc servesc doar progresului, dificultății și rapoartelor; nu reclame, nu profilare comercială. |
| Implicit privat | Aplicația copilului merge fără cont și fără rețea; sincronizarea e opțională. |
| Consimțământ | Separat pe scopuri, fără bife implicite, retragere la fel de ușoară, versiunea politicii salvată. |
| Retenție | 24 de luni pentru sesiuni (job zilnic ✅), ștergere definitivă la 7 zile după cerere. |
| Drepturi | Export complet, ștergere copil, ștergere cont (cu parola), din panou. |

## 4. Riscuri și măsuri

| Risc | Probabilitate | Impact | Măsuri | Risc rezidual |
|---|---|---|---|---|
| Acces neautorizat la datele unui copil (alt părinte, specialist fără partajare) | Scăzută | Ridicat | Verificarea accesului la fiecare cerere (`ChildAccess`: părintele doar copiii lui; specialistul doar cu `CareLink` activ, neexpirat), teste automate, audit | Scăzut |
| Compromiterea contului părintelui | Medie | Ridicat | Argon2id, sesiuni de 15 min, refresh rotit de unică folosință, parola cerută la ștergerea contului, **blocare 15 min după 5 parole greșite** ✅; 🕓 2FA pentru specialiști | Scăzut |
| Scurgere din baza de date | Scăzută | Ridicat | Minimizare (fără nume/diagnostic), hash-uri pentru parole și refresh tokenuri, 🕓 criptarea volumului și a e-mailului | Mediu |
| Reidentificare prin rezumatele AI | Scăzută | Mediu | Doar fapte agregate, fără poreclă/id; consimțământ separat; DPA fără antrenare pe date | Scăzut |
| Inferarea unei condiții de sănătate | Medie | Mediu | Nu cerem diagnostic; limbaj neutru; date minime; acces restrâns | Scăzut |
| Specialistul păstrează accesul după încheierea terapiei | Medie | Mediu | Partajare cu termen (implicit 90 zile), revocare oricând, ștergerea contului taie toate partajările | Scăzut |
| Expunerea desenelor / fotografiilor copilului | Scăzută | Mediu | Rămân pe dispozitiv; fotografia nu se salvează | Foarte scăzut |
| Pierderea datelor (ștergere din greșeală) | Medie | Scăzut | Perioadă de grație 7 zile, export oricând | Scăzut |

## 5. Concluzie
Cu măsurile existente, riscul rezidual e **acceptabil**, cu condiția finalizării măsurilor 🕓:
criptarea volumului bazei de date și a câmpului e-mail, 2FA pentru specialiști. (Făcute: expirarea
sesiunilor la 24 de luni, blocarea după 5 parole greșite.) Nu e necesară consultarea prealabilă a autorității
dacă acestea se implementează înainte de lansarea publică.

**Aprobat de:** […] **Data:** […]
