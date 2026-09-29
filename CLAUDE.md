# Licurici — instrucțiuni de lucru

**Sursa unică de adevăr este [README.md](README.md).** Citește întâi **§0.1 (unde am rămas și ce urmează)**, apoi §0 (starea proiectului) și §22 (ghid de lucru). La finalul fiecărei sesiuni actualizează §0.1.

- Proiectul țintă: aplicație **Flutter** pentru copii + backend **NestJS / PostgreSQL / Redis / BullMQ / stocare S3 (RustFS)** în **Docker** + dashboard Flutter Web. Arhitectura: README §4–§12.
- Codul JavaScript/Electron din `legacy/electron/` este doar **prototipul de referință**. Nu mai adăuga funcții noi acolo; portează comportamentul în Flutter (README §3).
- Orice tehnologie nouă → ADR în `docs/adr/` (README §7). Orice dată nouă despre copil → README §11 + §13.
- Grafică: ilustrații ChatGPT → decupare pe straturi → **animație procedurală din cod** în Flutter (ADR-028). Fără Rive, fără Unity. Aplicația copilului e doar landscape (ADR-023).
- Jocuri: README §15 (motor + animații) și §16 (catalog). La finalul fiecărei sarcini bifează progresul în README (§0, §16, §21).
- Commit-uri: mesaje simple și convenționale, fără atribuiri sau mențiuni despre unelte de AI.
- Comunicarea cu utilizatorul: în română, concis.
