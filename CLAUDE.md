# Licurici — instrucțiuni de lucru

**Predare 25.10.2026:** acvariul pictat și corecțiile modului calm sunt gata; baza pictată din „Rândul meu” este integrată. Bărcile din „Paznicul farului” erau deja pictate; semnele geometrice ale regulilor rămân intenționat din cod. Versiuni descărcabile și publicare: [docs/releases.md](docs/releases.md). Citește starea detaliată și verificările din [CODEX-CONTINUARE.md §1](CODEX-CONTINUARE.md) înainte de a relua sarcinile vechi.

**Sursa unică de adevăr este [README.md](README.md).** Citește întâi **§0.1 (unde am rămas și ce urmează)**, apoi §0 (starea proiectului) și §22 (ghid de lucru). La finalul fiecărei sesiuni actualizează §0.1.

**Sincronizare cu Codex:** proiectul e lucrat pe rând de Claude (acest fișier) și de Codex ([AGENTS.md](AGENTS.md) — aceleași reguli; cine schimbă o regulă o schimbă în amândouă). Predarea și pașii în curs (imaginile Codex, ce urmează): **[CODEX-CONTINUARE.md](CODEX-CONTINUARE.md)** — citește-l la începutul sesiunii și actualizează-i secțiunea „1. Starea de acum” la final, împreună cu README §0.1 / §0.0. Verifică în `git log` ce a făcut Codex între timp.

- Proiectul țintă: aplicație **Flutter** pentru copii + backend **NestJS / PostgreSQL / Redis / BullMQ / stocare S3 (RustFS)** în **Docker** + dashboard Flutter Web. Arhitectura: README §4–§12.
- Codul JavaScript/Electron din `legacy/electron/` este doar **prototipul de referință**. Nu mai adăuga funcții noi acolo; portează comportamentul în Flutter (README §3).
- Orice tehnologie nouă → ADR în `docs/adr/` (README §7). Orice dată nouă despre copil → README §11 + §13.
- Grafică: ilustrații **Codex** (cerut de utilizator pe 16.10: tot ce era desenat din cod de Claude se înlocuiește cu imagini Codex; uneltele în `tools/art/`, vezi `CODEX-CONTINUARE.md` §2) → **animație procedurală din cod** în Flutter (ADR-028). Fără Rive, fără Unity. Aplicația copilului e doar landscape (ADR-023).
- Jocuri: README §15 (motor + animații) și §16 (catalog). La finalul fiecărei sarcini bifează progresul în README (§0, §16, §21).
- **README §0.0 „Ce ai de făcut tu”**: la finalul fiecărei sesiuni actualizează lista (adaugă ce îi revine utilizatorului, bifează ce a confirmat că a făcut) și linia de progres (% din §21). Când utilizatorul întreabă „ce a mai rămas?”, răspunde din §0.0.
- Commit-uri: mesaje simple și convenționale, fără atribuiri sau mențiuni despre unelte de AI. Push pe `feat/fundatia-terapeutica` **și** pe `main` (`git push origin feat/fundatia-terapeutica:main`; `main` = producția Vercel).
- Comunicarea cu utilizatorul: în română, concis.
