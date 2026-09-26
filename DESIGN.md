# Curcubeu — decizii de design (bazate pe dovezi)

Rezumatul practicilor mondiale pe care le-am „copiat" în jocuri. Sursele sunt la final.

## Framework-uri și ce am luat din fiecare
- **ABA** — fiecare abilitate spartă în pași mici; recompensă imediată după fiecare răspuns corect. Coloana vertebrală a aplicației.
- **TEACCH** — structură vizuală: început clar, „ce ai de făcut" clar, stare „gata" clară. Predictibilitate în locul instrucțiunilor lungi.
- **PECS** — comunicare prin atingerea cardurilor-imagine în succesiune → tabla din jocul „Vorbește".
- **Social Stories** — scenarii scurte, literale, la persoana întâi → jocul „Situații".
- **Zones of Regulation** — verificarea emoției + unealtă de calmare → jocul „Respiră".
- **PRT** — folosește interesele copilului ca recompensă; răsplătește **încercarea**, nu doar corectitudinea.

## Reguli non-negociabile (fixate în motor)
1. O singură sarcină pe ecran; 2–3 variante la început.
2. Paletă calmă, saturație redusă; temă întunecată/palidă comutabilă; fără neon/modele agitate.
3. Nimic nu pornește singur; sunet și mișcare comutabile; respectă `prefers-reduced-motion`.
4. Recompensă imediată (<1s) la corect; răsplătește și efortul.
5. Nu pedepsi greșeala — reține recompensa, re-ghidează blând spre succes.
6. Învățare fără eroare: ghidaj puternic la început, retras pe măsură ce stăpânește.
7. Ținte ≥ 44–48px, bine distanțate (noi folosim ≥ 60px).
8. Navigație identică și fixă pe fiecare ecran; Acasă mereu prezent.
9. Tranziții semnalizate + stare „Gata!" clară.
10. Text literal; sans-serif; **bold** nu MAJUSCULE/italice; interlinie ≥ 1.5.
11. Personalizare + profil senzorial salvat.
12. Prioritate: emoții, comunicare AAC/PECS, secvențiere, potrivire, autoreglare — setul cu cea mai mare valoare.

## Culori
- Fundaluri moi, saturație joasă (verde-albastru, gri cald). Ex. `#EAF2F5`, `#DCEAE4`.
- De evitat: roșu/portocaliu aprins pe suprafețe mari, neon, modele repetitive.
- O culoare = un sens (verde = corect, mereu).
- Contrast text ≥ AA (4.5:1), dar fără negru pur pe alb pur (folosim `#2f3d3b` pe fundal cald).

## Feedback
- **Errorless learning**: evidențiază corectul, estompează distractorii, retrage ajutorul pe măsură ce reușește.
- Fără X roșu, fără buzzer, fără „Greșit!", fără scădere de scor.
- La greșeală: indiciu neutru („Mai încearcă"), re-evidențiere, apoi succes → recompensă.
- Sistem de jetoane (steluțe) spre o recompensă la final.

## Tipuri de joc dovedite (ordinea valorii)
Recunoaștere emoții (dovada cea mai tare) → scenarii sociale → secvențiere rutine →
sortare/categorii → potrivire → memorie & modele → comunicare AAC/PECS → autoreglare/respirație.

## Accesibilitate
- Ținte mari, bine distanțate; navigabil cu tastatura; focus vizibil.
- Codare redundantă: niciodată doar culoarea — mereu icon + text (+ voce).
- Text-to-speech pentru toate instrucțiunile (aici: `speechSynthesis`, limba `ro-RO`).
- Profiluri senzoriale per utilizator (sunet, mișcare, paletă, text, dificultate).

## Idei copiate din aplicații apreciate
- **Otsimo** — feedback tactil în trepte, fundaluri moi, un singur fundal solid în spatele obiectului.
- **Proloquo2Go** — grilă AAC scalabilă, tap → construiește propoziția → o rostește.
- **Endless Reader / Avokiddo** — personaje prietenoase, fără stări de eșec, repetiție blândă.
- **Daniel Tiger** — autoreglare prin ritm/mantră; structură „Întâi–Apoi".
- **Zones of Regulation / Goally** — verificarea emoției + unelte de calmare; bandă de program vizual.

## Surse
- Serious Games for Social Skills in ASD — review sistematic (PMC10931397)
- Mobile apps for emotion recognition in autism — review (Frontiers, frcha.2023.1118665)
- Otsimo — Designing UI/UX for Children with Autism (Medium)
- Errorless Learning in autism (MoveUp ABA; Autism Classroom Resources)
- TEACCH, PRT, DIR/Floortime (Key Autism Services; Autism Parenting Magazine; ASAT)
- First-Then / Visual Schedules (Goally; Autism Classroom Resources)
- WCAG 2.5.8 Target Size (W3C); Proloquo2Go (AssistiveWare)

> Notă: valorile exacte de culoare/spațiere vin din practica de design profesională și sunt
> expuse ca **setări ajustabile**, nu ca adevăruri clinice. Regulile comportamentale
> (învățare fără eroare, recompensă imediată, fără pedeapsă, structură vizuală) și datele
> despre eficacitatea tipurilor de joc au cel mai solid suport în cercetare.
