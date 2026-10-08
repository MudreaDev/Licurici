# ADR-031: Specialistul poate alege jocurile copilului (singura scriere permisă lui)

Status: Propus · Data: 2026-10-09

## Context
Planul terapeutic (plan §5.1) spune că **specialistul alege** din paleta de jocuri ce vede fiecare copil; copilul vede doar
jocurile alese. Până acum, regula de acces (README §2.1, §13; `children/access.ts`) era simplă: părintele citește și scrie,
specialistul cu partajare activă (`CareLink`) doar citește. Alegerea jocurilor e o scriere, deci regula trebuia schimbată sau
ocolită. În plus, părintele trebuie să poată alege și singur, pe tabletă, fără cont (copii fără specialist).

## Decizie
- Un **plan de jocuri** per copil = lista jocurilor scoase (`hiddenGames`, id-uri de joc — nu date despre copil) + data și
  rolul ultimei schimbări + istoricul schimbărilor (ultimele 50).
- `GET /children/:id/plan` și `PUT /children/:id/plan`: **părintele și specialistul cu partajare activă** pot scrie planul.
  E **singurul lucru** pe care specialistul îl poate schimba; sesiunile, consimțămintele, partajarea și ștergerea rămân ale
  părintelui. Fiecare scriere intră în `audit_log` (`child.plan`).
- Stocare în `child_settings.extra.plan` (JSON existent) — fără tabel și fără migrare nouă.
- Pe tabletă: „Pentru părinți” → „Jocurile copilului” (fără cont). La sincronizare, **ultimul câștigă** după dată
  (`hiddenGamesAt`, ca setările din ADR-011): planul mai nou de pe server vine pe tabletă, cel mai nou de pe tabletă pleacă.
- În panou: tabul „Jocuri” la fiecare copil; schimbările apar ca **linii de schimbare de fază** în graficul de independență.
- Lista e „ce scoatem”, nu „ce permitem”: un joc nou din aplicație apare implicit.

## De ce
- Respectă planul terapeutic (specialistul conduce intervenția) fără să-i dea acces de scriere la datele copilului.
- Datele planului nu sunt date personale ale copilului (doar id-uri de joc); riscul GDPR al scrierii e minim, iar auditul
  păstrează trasabilitatea.
- „Ultimul câștigă” e deja regula pentru setări (ADR-011); copilul are o singură tabletă, conflictele reale sunt rare.
- „Ce scoatem” face actualizările aplicației sigure: un copil nu rămâne fără jocuri noi doar pentru că lista e veche.

## Alternative
1. Specialistul doar **propune**, părintele aprobă fiecare schimbare.
2. Mod de acces nou, general (`write` pentru specialist) pe toate datele copilului.
3. Lista „ce permitem” (allow-list) în loc de „ce scoatem”.
4. Tabel nou `child_plans` cu istoric complet.

## De ce nu
1. **Aprobarea părintelui** la fiecare schimbare încetinește intervenția și mută responsabilitatea clinică pe părinte; părintele
   vede oricum lista în aplicație și o poate schimba.
2. **Scriere generală** pentru specialist ar contrazice minimizarea (GDPR art. 5) și README §13.
3. **Allow-list:** fiecare joc nou ar trebui adăugat manual la fiecare copil; ușor de uitat.
4. **Tabel nou:** o migrare în plus pentru o listă mică; `extra` + `audit_log` acoperă nevoia acum.

## Când am alege altfel
- Dacă specialiștii cer parametri pe joc (`GameConfig`, ADR-025: treapta de pornire, limite ale axelor, frecvența) — atunci
  planul devine o entitate proprie (tabel `child_plans`, cu versiuni) și „propune / aprobă” poate deveni util.
- Dacă un copil folosește mai multe tablete, „ultimul câștigă” se înlocuiește cu fuziune pe joc.
