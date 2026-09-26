# ADR-002: Widget-uri Flutter ca bază, Flame doar unde e nevoie

Status: Acceptat · Data: 2026-09-26

## Context
Cele ~58 de jocuri sunt în mare parte „UI cu reguli”; câteva (labirint, obiecte care cad) au nevoie de o buclă de joc.

## Decizie
majoritatea jocurilor (alege, trage-și-plasează, memorie, secvențe) = widget-uri Flutter; **Flame** doar pentru jocurile cu buclă de joc (labirint, prinde obiecte, trasare cu particule).

## De ce
jocurile educative sunt în mare parte „UI cu reguli”; widget-urile dau accesibilitate (Semantics), layout responsiv și teste de widget gratis. Flame adaugă game loop, coliziuni, sprite-uri — util doar unde e nevoie.

## Alternative
totul în Flame; totul în widget-uri; Rive state machines pentru jocuri.

## De ce nu
totul în Flame → pierdem accesibilitatea și testarea de widget; totul în widget-uri → labirintul/fizica devin cod stângaci.

## Când am alege altfel
dacă >50% din jocuri devin arcade → Flame peste tot.
