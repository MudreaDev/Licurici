# ADR-025: Jocuri configurabile (schemă de parametri) și planuri de la specialist

Status: Propus · Data: 2026-09-26

## Context
Vor exista ~60–100 de jocuri. Specialistul (terapeut / educator) trebuie să poată alege și personaliza jocurile pe care le joacă un copil. Părintele și specialistul văd progresul. Nu vrem muncă în panou pentru fiecare joc nou, iar modificarea unui joc nu trebuie să atingă restul.

## Decizie
- **Câte un folder per joc:** `packages/licurici_core/lib/src/games/<materie>/<id>/`, cu generatorul, conținutul (`continut.json`) și testele lui.
- Fiecare joc declară:
  - **abilitățile** exersate, folosite de statistici;
  - o **schemă de parametri** (`GameConfig`): tipuri simple, adică număr cu min/max, alegere din listă, subset din conținut, boolean. Fiecare are o valoare implicită.
- Specialistul creează un **plan**: jocuri, parametri, ordine și, opțional, o perioadă. Panoul web **generează formularul din schemă**, deci nu scriem cod de panou pentru jocuri noi.
- Motorul trimite **evenimente standard**: joc, abilitate, corect din prima, timp de răspuns, nivel. Statisticile se calculează pe abilități.
- Planul ajunge în aplicația copilului la sincronizare (tabela locală `plan`) și se joacă offline.

## De ce
- **Adăugarea unui joc nu atinge panoul, statisticile sau sincronizarea.** Jocurile noi apar automat.
- Folderele autonome reduc riscul de regresii și costul modificărilor: omul sau AI-ul citește doar folderul jocului.
- Schema e date, nu cod. Se poate valida pe server (zod) și în aplicație, și se versionează împreună cu jocul.

## Alternative
Un ecran de configurare scris de mână pentru fiecare joc; jocuri neconfigurabile, cu doar nivel ușor/mediu; un DSL de scripting pentru jocuri.

## De ce nu
- **Ecrane manuale:** muncă proporțională cu numărul de jocuri și risc de desincronizare între joc și panou.
- **Fără configurare:** specialistul nu poate adapta terapia la copil, deci se pierde valoarea principală pentru TSA.
- **DSL:** complexitate mare, greu de testat și de argumentat pentru un singur dezvoltator.

## Când am alege altfel
Un editor vizual de jocuri pentru specialiști (creare de jocuri noi, nu doar configurare), dacă produsul crește și există o echipă.
