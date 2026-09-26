# ADR-022: Fontul: Nunito (nu Fredoka)

Status: Acceptat · Data: 2026-09-26

## Context
Aplicația e în limba română; textul trebuie să fie lizibil, prietenos și identic pe toate platformele, offline.

## Decizie
Nunito (SIL OFL), inclus în aplicație (`packages/game_content/fonts/`), greutăți 500–800.

## De ce
literele rotunjite îl fac prietenos pentru copii, iar lizibilitatea e bună la dimensiuni mari. Motivul decisiv: are **toate diacriticele românești** (ă, â, î, ș, ț). Prototipul folosea Fredoka; la verificarea tabelului `cmap` am găsit că Fredoka nu conține ă, ș, ț. Browserul le lua din alt font, așa că arătau diferit în mijlocul cuvântului.

## Alternative
Fredoka; Andika (SIL, gândit pentru cititori începători); Baloo 2; fonturile sistemului.

## De ce nu
Fredoka — fără ă/ș/ț; fonturile sistemului — arată diferit pe fiecare platformă (contrar principiului de predictibilitate), iar pe web Flutter le-ar descărca de la Google (trafic extern, offline imposibil); Andika — excelent pentru lectură, dar mai puțin „jucăuș” pentru titluri.

## Când am alege altfel
Andika pentru textele din jocurile de citire (litere, silabe), unde forma literei contează mai mult decât stilul.
