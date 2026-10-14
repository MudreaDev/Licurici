# ADR-033: Muzica de fundal, generată din cod și oprită de adult

Status: Propus · Data: 2026-10-15

## Context
Utilizatorul a cerut o muzică terapeutică, liniștită și plăcută pentru copil, pe care specialistul să o poată porni sau opri. Constrângeri: aplicația e offline (fără streaming), fără licențe de plătit sau de verificat, fără stimulare în plus pentru copiii sensibili la sunet (TSA), vocea lui Licurici trebuie să se audă mereu clar, iar unele jocuri au sunetul ca sarcină (notele felinarelor, toba, „Ce se aude?”).

## Decizie
- **Trei piese generate din cod** (`tools/audio/gen_music.py`, numpy + ffmpeg → MP3 96 kbps, ~1 MB fiecare): „Lumini de seară” (clopoței), „Valuri” (flaut), „Grădina” (marimbă). Reguli muzicale fixe: 58–70 bpm, doar gama pentatonică majoră (fără disonanțe), fără percuție, atac lent, melodie rară cu pauze, reverberație moale, fără înalte ascuțite (filtru trece-jos).
- **Piesele se cântă pe rând**, cu 4 s de liniște între ele, nu în buclă: MP3 nu are bucle fără cusătură (întârzierea codorului ar da un „clic”), iar o piesă care se încheie natural, pe acordul de bază, e mai liniștitoare.
- **Volumul e mereu sub voce**: 0,2 (0,12 în modul calm) și coboară la o treime cât vorbește Licurici (`voiceActivityProvider`); schimbările de volum sunt line (pași de 50 ms).
- **Tace** în jocurile în care sunetul e sarcina și în acvariu (are apa lui), când aplicația nu e în față și când adultul a oprit-o.
- **Cine decide:** adultul — pe tabletă („Pentru părinți” → „Muzică liniștită”, după poarta pentru adulți) sau specialistul din panou (tabul „Jocuri”, câmpul `music` din planul copilului, `{on, track}`, aplicat pe tabletă la sincronizare după regula „ultimul câștigă”). Pornită implicit, încet.

## De ce
- **Fără dependențe și licențe:** același drum ca sunetele interfeței (`gen_sfx.py`); piesele se pot regenera oricând (alt tempo, altă gamă) dintr-un singur fișier.
- **Pentatonica și tempoul lent** sunt alegerile obișnuite în muzica pentru relaxare la copii: orice combinație de note sună armonios, nimic nu „surprinde”.
- **`audioplayers`** e deja în aplicație (vocea, sunetele) — niciun pachet nou.
- **Controlul la adult** respectă principiul „totul dezactivabil” (README §2, §22) și lasă specialistul să decidă pentru copiii care nu tolerează sunetul de fundal.

## Alternative
1. Muzică înregistrată, cu licență (ex. biblioteci royalty-free).
2. Muzică generată la rulare (sinteză în timp real în aplicație).
3. O singură buclă WAV, fără cusătură.
4. Fără muzică; doar sunetul apei în acvariu.

## De ce nu
1. Licențele trebuie verificate și păstrate; muzica „de relaxare” găsită gata are adesea schimbări bruște sau instrumente ascuțite, greu de controlat.
2. Sinteza în timp real cere cod nativ sau shadere audio, consumă baterie și e greu de testat; câștigul (variație infinită) nu contează pentru un fundal discret.
3. WAV fără compresie: ~10 MB pe piesă (vs ~1 MB), iar o buclă scurtă devine repetitivă.
4. A fost cerută explicit; în plus, poate liniști copilul în timpul jocurilor (rămâne opțională).

## Când am alege altfel
- Dacă specialiștii cer piese anume (ex. muzică folosită deja în terapie) → piese înregistrate, cu licență, în același loc (`audio/music/`).
- Dacă se dorește volum reglabil sau mai multe piese alese de copil → setări noi în același câmp `music` al planului.

## Consecințe
- +3,5 MB în aplicație (trei MP3).
- Pe web (doar previzualizare) muzica pornește abia după prima atingere (regula browserelor); aplicația reîncearcă la următoarea schimbare de ecran.
- Testele de widget rulează fără audio (ca la sunete): logica de volum și de pauză e testată ca funcții pure (`musicVolume`, `musicPausedOn`).
