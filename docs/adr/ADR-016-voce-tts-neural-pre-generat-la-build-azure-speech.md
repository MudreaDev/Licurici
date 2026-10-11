# ADR-016: Voce: TTS neural pre-generat la build (Azure Speech)

Status: Acceptat · Data: 2026-09-26

## Context
Instrucțiunile trebuie rostite natural în română, offline, fără a trimite date ale copilului la terți.

## Decizie
replicile se generează **la build** cu Azure AI Speech (voce `ro-RO-AlinaNeural`, `en-US-JennyNeural`) și se livrează ca MP3/OGG în pachetele de conținut. Replicile dinamice (ex. numele copilului) se compun din fragmente.

## De ce
voce naturală fără internet; **nicio dată a copilului nu pleacă spre un serviciu extern la rulare**; cost ~0 (nivelul gratuit acoperă generarea). Prototipul folosea `edge-tts` (endpoint neoficial) — pentru un produs/teză folosim API-ul oficial, cu cheie și termeni clari.

## Alternative
TTS de pe dispozitiv (`flutter_tts`); TTS în cloud la rulare; înregistrări cu actor.

## De ce nu
TTS dispozitiv — vocile românești lipsesc sau sună robotic pe multe dispozitive; cloud la rulare — necesită internet + trimite text (posibil numele copilului) la terți; actor — cost, greu de extins.

## Când am alege altfel
TTS on-device neural (ex. modele Piper) dacă devine suficient de bun în română → elimină complet serviciul extern.

## Actualizare (11.10.2026) — vocea aleasă
Comparate 11 mostre cu aceeași frază: cele două voci românești native (Alina, Emil), cu viteze și înălțimi diferite, și
șase voci multilingve Microsoft (Ava, Emma, Vivienne, Seraphina, Thalita, Andrew — au accent străin pe ă, î, ș, ț).
Aleasă: **ro-RO-AlinaNeural, viteză −5%, înălțime +15 Hz** — mai caldă și puțin mai rară, ușor de urmărit pentru
copiii mici. Toate clipurile românești au fost regenerate cu aceste setări (`node tools/gen-voice/gen-voice.mjs --toate`),
ca aplicația să aibă o singură voce peste tot. Frazele jocului Engleză rămân cu `en-US-AnaNeural` (voce de copil).
Setările stau într-un singur loc: `tools/gen-voice/gen-voice.mjs` (`VOICE`, `RATE`, `PITCH`).
