# ADR-019: Jocuri ca date + mecanici reutilizabile

Status: Acceptat · Data: 2026-09-26

## Context
~58 de jocuri trebuie construite într-un an, cu comportament consecvent (învățare fără eroare, recompense, accesibilitate).

## Decizie
fiecare joc = `GameSpec` (metadate + generator de runde) peste un număr mic de **mecanici** (§15). Conținutul (cuvinte, imagini, audio) = JSON versionat în `game_content`.

## De ce
58 de jocuri peste ~9 mecanici → UI/accesibilitate/recompense scrise o singură dată; conținutul poate fi actualizat fără release în magazin (content packs); testare pe generator (pur Dart).

## Alternative
fiecare joc scris de la zero; un DSL/scripting (Lua); jocuri web încapsulate (WebView).

## Când am alege altfel
jocuri scrise individual doar pentru cele cu mecanici unice (labirint, colorare).
