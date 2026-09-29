# ADR-026: Trasee de dezvoltare pe arii, nu clase și materii

Status: Propus · Data: 2026-09-29 · Detalii: [plan-dezvoltare-terapeutica.md](../plan-dezvoltare-terapeutica.md)

## Context
Licurici e gândit pentru copii cu TSA și pentru specialiștii care lucrează cu ei. Organizarea actuală (materii + clase G–4, extinsă spre 5–12) vine din școală. Copiii cu TSA au un profil de dezvoltare inegal: același copil poate fi foarte în urmă la comunicare și avansat la potrivire vizuală. Specialistul are nevoie de obiective măsurabile, date pe încercare (inclusiv cât ajutor a primit copilul) și grafice de progres, nu de „stele la matematică”.

## Decizie
- Conținutul se organizează pe **arii de dezvoltare** (atenție, imitație, potrivire, limbaj receptiv, comunicare, cogniție, emoții, funcții executive, autonomie, motricitate, pre-academic), fiecare cu un **traseu de trepte** ordonate, cu criteriu de stăpânire.
- Nivelul copilului este **treapta pe fiecare arie**, nu clasa. `Grade` și `Subject` ies din fluxul copilului.
- Fiecare rundă devine o **încercare** înregistrată: treaptă, stimul, corect, **nivel de ajutor (P0–P4)**, încercări, latență.
- Jocurile devin **exerciții** legate de trepte, configurate prin `GameConfig` (ADR-025).
- Jocurile formează o **paletă** vizibilă doar adulților. **Specialistul alocă fiecărui copil doar jocurile de care are nevoie**; copilul vede numai jocurile alocate (fără catalog, fără categorii).
- Planul specialistului conține **obiective** (trepte + criteriu + termen + strategie de ajutor).
- Aplicația **observă și semnalează**, nu diagnostichează. Deciziile sunt ale specialistului.
- Se retrage extinderea la clasele 5–12.

## De ce
- Corespunde modului în care lucrează terapia (ABA, TEACCH, evaluări pe arii și repere) și practicilor bazate pe dovezi (prompting, time delay, DTT, suporturi vizuale).
- Independența (nivelul de ajutor) și generalizarea sunt indicatorii pe care specialiștii îi urmăresc; fără ele datele nu permit concluzii.
- Profilul pe arii arată inegalitățile copilului; clasa le ascunde.
- Motorul existent (mecanici, `Difficulty`, `AdaptiveRule`) se refolosește; se schimbă doar modelul din jurul jocurilor.

## Alternative
1. Păstrăm clasele și materiile, adăugăm doar statistici mai bogate.
2. Folosim direct un instrument standardizat (VB-MAPP, ABLLS-R) ca structură.
3. Doar vârsta ca nivel (ex. „3–4 ani”).

## De ce nu
1. Nivelul pe clasă e fals pentru un profil inegal; statisticile ar fi pe categorii școlare, nu pe abilități de dezvoltare.
2. Instrumentele sunt protejate de drepturi de autor, necesită formare certificată și nu sunt gândite pentru administrare pe tabletă. Ne inspirăm din structura lor (arii, niveluri, repere), nu le copiem.
3. Vârsta are aceeași problemă ca clasa.

## Când am alege altfel
Dacă produsul ar deveni o aplicație școlară pentru copii tipici (atunci curriculumul pe clase e util), sau dacă am obține licența unui instrument standardizat și un parteneriat clinic.

## Consecințe
- Refacem ecranul principal al copilului („Drumul de azi”, harta cu felinare), modelul de date (§11) și panoul (grafice ABA, obiective).
- Datele pot deveni **date privind sănătatea** în context terapeutic → consimțământ explicit, DPIA, audit (README §13).
- Trebuie evitată încadrarea ca **dispozitiv medical** (MDR 2017/745): platforma e instrument educațional și de suport, fără diagnostic sau tratament automat.
- Treptele trebuie validate cu specialiști.
