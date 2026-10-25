# Licurici — instrucțiuni pentru Codex

**Predare 25.10.2026:** acvariul pictat și corecțiile modului calm sunt gata; baza pictată din „Rândul meu” este integrată. Bărcile din „Paznicul farului” erau deja pictate; semnele geometrice ale regulilor rămân intenționat din cod. Versiuni descărcabile și publicare: [docs/releases.md](docs/releases.md). Citește starea detaliată și verificările din [CODEX-CONTINUARE.md §1](CODEX-CONTINUARE.md) înainte de a relua sarcinile vechi.

**Sursa unică de adevăr este [README.md](README.md).** Citește întâi **§0.1 (unde am rămas și ce urmează)**, §0.0
(ce are de făcut utilizatorul), §2 (principii), §14–§15.1 (design + animații), §22 (reguli).
**Predarea de la Claude (16.10.2026) și pașii concreți: [CODEX-CONTINUARE.md](CODEX-CONTINUARE.md)** — începe cu el.

## Sincronizare Claude ↔ Codex

Proiectul e lucrat pe rând de **Claude** (instrucțiunile lui: [CLAUDE.md](CLAUDE.md)) și de **Codex** (acest fișier).
Regulile sunt aceleași în ambele fișiere; cine schimbă o regulă o schimbă în **amândouă**.
Ca celălalt agent să poată continua fără să întrebe:
- la finalul fiecărei sesiuni actualizează **README §0.1** (ce s-a făcut, ce urmează), **§0.0** (lista utilizatorului
  + linia de progres din §21) și secțiunea **„1. Starea de acum”** din `CODEX-CONTINUARE.md` (bifează ce e gata din
  §2–§5 acolo);
- totul se urcă în git (§ „Commit-uri”) — starea nu stă în fișiere locale, cu excepția surselor brute de imagini
  (`tools/art/batch/out/`, ignorat de git, rămâne pe calculatorul utilizatorului).

## Reguli obligatorii

- Comunicarea cu utilizatorul: **în română, concis.**
- **Commit-uri:** mesaje simple, convenționale, fără diacritice, **fără atribuiri sau mențiuni despre unelte de AI**.
  Se lucrează pe `feat/fundatia-terapeutica` și se urcă pe ambele ramuri:
  `git push origin feat/fundatia-terapeutica` și `git push origin feat/fundatia-terapeutica:main`
  (`main` = producția de pe Vercel).
- Proiectul țintă: aplicație **Flutter** pentru copii + backend **NestJS / PostgreSQL / Redis / BullMQ / S3** în
  **Docker** + panou Flutter Web (README §4–§12). `legacy/electron/` e doar prototip de referință.
- Orice tehnologie nouă → ADR în `docs/adr/` (README §7). Orice dată nouă despre copil → README §11 + §13.
- Jocuri: README §15 și §16; la finalul fiecărei sarcini bifează progresul în README (§0, §16, §21).
- **Grafică:** ilustrații pictate făcute cu **Codex** (stil de carte pentru copii, paleta pastel din README), integrate
  cu uneltele din `tools/art/` (vezi `CODEX-CONTINUARE.md` §2); desenele din cod rămân doar rezervă. Animația e
  **procedurală din cod** (ADR-028). Fără Rive, fără Unity, fără pachete noi fără ADR.
- Aplicația copilului: **doar landscape**, ținte ≥ 64 dp, o singură sarcină pe ecran.
- **Fără pedeapsă:** fără roșu aprins, fără X la greșeli, fără sunete de eșec, fără „Greșit”. Feedback blând.
- Tot ce animă citește `MotionPolicy` / modul calm (`apps/child_app/lib/shared/motion.dart`).
  Fără clipiri > 3/s, ≤ 40 de particule, o singură animație mare pe ecran.
- Stimulii se afișează prin `StimulusArt` (`apps/child_app/lib/shared/stimulus_art.dart`: ilustrația pictată,
  altfel OpenMoji) — niciodată emoji de sistem.
- Voce: `shared/voice.dart`; orice frază nouă → `packages/licurici_core/tool/voice_coverage.dart` + generarea vocii
  (fără voci în engleză).
- Interfața în română; identificatorii de cod în engleză. Măsurători de timp cu `Stopwatch`.
- Înainte de commit: testele trec (comenzile în `CODEX-CONTINUARE.md` §4). Python se rulează cu `py`.
- Nu crea conturi și nu introduce parole pe site-uri publice (ex. panoul de pe Vercel).
