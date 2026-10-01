# Licurici — panouri web

Aceeași aplicație Flutter Web, două interfețe pentru adulți:

- `/`: alegere rol, fără autentificare în demo.
- `/parinte`: rezumat, obiective, dispoziție și istoricul copilului; selector pentru mai mulți copii.
- `/specialist`: lista copiilor.
- `/specialist/copil/:id`: prezentare, progres ABA, sesiuni și confuzii agregate.

Rutele folosesc implicit strategia hash Flutter Web (de exemplu `/#/parinte`), astfel încât reîncărcarea funcționează și pe găzduire statică.

`lib/data.dart` expune `childrenProvider`, momentan bazat pe `demoChildren()`. Datele sunt inventate. Integrarea API va înlocui această sursă și va aplica autorizarea pe server; selectorul de rol nu reprezintă autentificare. Butonul AI este dezactivat; JSON-ul din sesiune este doar o previzualizare locală a `toAiJson()`, fără trimitere.

Graficul arată independența pe sesiuni, cu goluri pentru obiective neexersate, legendă și valori text accesibile. Pragul de 80% este numai componenta de independență a criteriului de stăpânire. Oboseala reprezintă variația latenței, nu un diagnostic.

Nunito și ilustrațiile OpenMoji provin din `game_content`. OpenMoji: https://openmoji.org/ — CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/). Nu există dependențe noi. La lățimi sub 900 px, copiii sunt într-un drawer.

Din acest director:

```sh
flutter run -d chrome
flutter analyze
flutter test
flutter build web
```

Testele acoperă rolurile, selectorul, notițele, valorile graficului, pragul de 80%, detaliile sesiunii și JSON-ul, agregarea confuziilor, drawer-ul, istoricul gol și id-urile necunoscute.
