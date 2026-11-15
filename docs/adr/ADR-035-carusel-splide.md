# ADR-035: Splide pentru caruselul de prezentare

Status: Acceptat · Data: 2026-11-14

## Context
Utilizatorul a cerut explicit o bibliotecă pentru un carusel cu autoplay. Schimbarea de imagine implementată inițial nu oferea un track cu glisare tactilă reală.

## Decizie
Splide **4.1.4**, licență MIT, numai în landing. Se livrează local modulul ESM, CSS core și licența din pachetul npm oficial `@splidejs/splide`. Arhiva a fost verificată SHA-512 față de integritatea declarată de npm. Nu este necesar un build nou sau un CDN la accesarea paginii.

Șase slide-uri HTML complete, tranziție orizontală, loop, swipe/drag, autoplay la 5 secunde, progres și buton nativ play/pause. Splide gestionează focusul slide-urilor inactive, etichetele ARIA și reducerea mișcării. Păstrăm designul și selecția tematică existente; oprim autoplay în dialog și în afara ecranului. Motorul propriu și testele lui sunt eliminate.

## Alternative și argumente
- **Splide:** include autoplay, comutator play/pause, loop, drag și accesibilitate în același pachet, fără framework.
- **Embla 8:** potrivit pentru gesturi, dar autoplay este un plugin separat și integrarea accesibilității cere mai mult cod propriu. Documentația nouă v9 era încă RC la verificare.
- **Swiper:** o alternativă bogată în efecte și module; nu sunt necesare pentru prezentarea simplă cu un ecran activ.

## Consecințe
O dependență frontend nouă, fixată și versionată local; nicio modificare în aplicația Flutter sau panou. Actualizările bibliotecii sunt explicite, cu verificarea licenței, integrității și comportamentului. `vendor/manifest.json` păstrează proveniența și hash-urile fișierelor.

Surse: [instalare](https://splidejs.com/guides/getting-started/), [autoplay](https://splidejs.com/guides/autoplay/), [accesibilitate](https://splidejs.com/guides/accessibility/), [Embla autoplay](https://www.embla-carousel.com/docs/v8/plugins/autoplay).
