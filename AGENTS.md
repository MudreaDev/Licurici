# Licurici — instrucțiuni pentru Codex

Lucrezi împreună cu un alt agent (Claude) pe același repo. **Sursa unică de adevăr este [README.md](README.md)**: citește §0.1, §2 (principii), §14–§15.1 (design + animații), §22 (reguli).

## Împărțirea muncii
- **Claude — arhitectură:** `packages/licurici_core` (logica pură, generatoare, modele, teste), `backend/`, `docs/adr/`, README.
- **Codex — front:** `apps/child_app/lib/**` (ecrane, widget-uri, animații procedurale), teste de widget în `apps/child_app/test/`.
- Nu modifica fișierele din zona celuilalt. Dacă ai nevoie de o schimbare în `licurici_core`, scrie-o în raportul final ca propunere.
- Nu face commit-uri; Claude verifică și face commit-ul.

## Reguli obligatorii (din README)
- Aplicația copilului: **doar landscape**, ținte ≥ 64 dp, o singură sarcină pe ecran.
- **Fără pedeapsă:** fără roșu, fără X, fără sunete de eșec, fără „Greșit”. Feedback blând.
- **Animație procedurală din cod** (CustomPainter, AnimationController, flutter_animate). Fără Rive, fără Unity, fără pachete noi fără să le ceri.
- Tot ce animă citește `MotionPolicy` / modul calm (`apps/child_app/lib/shared/motion.dart`): `off` = fără mișcare decorativă.
- Fără clipiri > 3/s, ≤ 40 de particule, o singură animație mare pe ecran.
- Ilustrații: OpenMoji prin `EmojiArt` (`shared/emoji_art.dart`), niciodată emoji de sistem.
- Voce: `shared/voice.dart` (frazele lipsă sunt sărite în tăcere).
- Interfața în română; identificatorii de cod în engleză.
- Măsurători de timp cu `Stopwatch` (ceas monoton).
- Înainte de final: `flutter analyze` curat și `flutter test` trece în `apps/child_app`.
