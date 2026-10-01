# ADR-029: Rezumatele sesiunii pentru părinte și specialist — fapte calculate în cod, formulate de Claude

Status: Propus · Data: 2026-10-01 · Legat de: README §2.1 (chat AI doar pentru adulți), §13, §17; plan §4; ADR-013.

## Context
Părintele și specialistul vor, după fiecare sesiune, un rezumat: ce s-a exersat, ce a mers, ce greșeli apar,
cum s-a simțit copilul. Datele sunt despre un copil (posibil cu TSA), deci contează exactitatea, confidențialitatea
și să nu existe afirmații medicale.

## Decizie
1. **Faptele le calculează codul**: `SessionReport` în `licurici_core` (Dart pur, testat) — acuratețe, independență,
   ajutor P0–P4, latență, confuzii, oboseală, pauze, dispoziția aleasă de copil.
2. **Rezumatul din reguli** (`parentSummary`, `specialistNotes`) există mereu, offline, fără AI.
3. **Opțional, cu consimțământ separat**: backend-ul trimite `toAiJson()` (agregate pseudonimizate, schemă `strict`
   care respinge orice câmp în plus) la **Claude Opus 5.5** (`claude-opus-5-5`) prin SDK-ul oficial
   `@anthropic-ai/sdk`, cu ieșire structurată (zod) și promptul de sistem fix, cache-uit. Modelul doar formulează.
4. La eroare, limită de utilizare, refuz sau răspuns invalid → `SummaryUnavailableError` → panoul arată rezumatul din reguli.
5. Fallback de refuz pe server (`fallbacks: "default"`), efort `medium`.

## De ce
- Cifrele nu pot fi „halucinate”: modelul nu calculează nimic; promptul îi interzice să deducă dincolo de date.
- Minimizare (GDPR art. 5, Legea 195/2024): fără nume, id-uri, date calendaristice, text liber, audio sau imagini.
- Textul natural, adaptat cititorului (cald pentru părinte, tehnic pentru specialist), e mult mai util decât tabelele.
- AI-ul nu e pe drumul critic: totul funcționează și fără el.

## Alternative
(a) Doar rezumate din reguli; (b) model rulat local/self-hosted; (c) alt furnizor LLM; (d) AI care primește datele brute.

## De ce nu
(a) rămâne rezerva, dar textele din șabloane sunt rigide și repetitive; (b) cost de infrastructură și calitate mai slabă
în română pentru o licență; (c) proiectul folosește deja Claude pentru chatul adulților (§2.1) — un singur procesator,
un singur DPA; (d) încalcă minimizarea și permite deducții necontrolate.

## Când am alege altfel
Dacă procesatorul nu poate oferi găzduire/garanții potrivite în UE (ADR-020) sau costul pe sesiune devine relevant →
doar rezumatele din reguli sau un model local. Dacă specialiștii cer rezumate pe mai multe sesiuni (lunare), același
mecanism primește agregatele pe perioadă.

## Consecințe
- `ANTHROPIC_API_KEY` doar în mediul backend-ului; niciodată în aplicații.
- De făcut: endpoint `POST /children/:id/sessions/:sid/summary` (rol PARENT/THERAPIST, verificare consimțământ `ai_summary`),
  limită per cont în Redis, cache al rezumatului per sesiune, intrare în RoPA (procesator: Anthropic).
- Evaluare înainte de producție: set de ~30 de sesiuni demo, verificat de un specialist (fără cifre inventate, ton potrivit).
