# Procedura pentru cererile privind drepturile persoanelor

> Ciornă (Legea 195/2024; GDPR art. 12–22). Vezi [README](README.md).

**Termen:** răspuns în cel mult **o lună** de la primire (prelungibil cu încă două luni pentru cereri
complexe, cu anunțarea motivului în prima lună). **Gratuit.**

## Pas cu pas
1. **Înregistrare.** Cererea (e-mail la […], sau din panou) se notează: data, cine, ce drept.
2. **Identificare.** Răspundem doar titularului contului: cererea vine de la e-mailul contului sau
   persoana se autentifică în panou. Pentru un copil, cererea o face **părintele** (titularul contului
   care a creat profilul). Nu cerem documente în plus decât dacă există îndoieli rezonabile.
3. **Rezolvare** (cele mai multe sunt deja **în panou**, „Contul meu”):

| Dreptul | Cum se exercită | Implementare |
|---|---|---|
| Acces (art. 15) | „Datele mele” → copiază exportul complet (JSON) | ✅ `GET /me/export` |
| Portabilitate (art. 20) | Același export, format citibil de mașină | ✅ (🕓 descărcare ca fișier; acum clipboard) |
| Rectificare (art. 16) | Poreclă, an, clasă: din aplicație / panou; e-mail: la cerere | 🟨 parțial |
| Ștergere (art. 17) | „Șterge profilul” (copil); „Șterg contul” (cu parola) | ✅ acces tăiat imediat, definitiv la 7 zile |
| Retragerea consimțământului (art. 7) | Comutatoarele din „Acordurile mele” | ✅ jurnal append-only |
| Restricționare (art. 18) | Retragerea acordului „Sincronizare” oprește noile date; la cerere, marcăm profilul | 🟨 la cerere |
| Opoziție (art. 21) | Nu facem profilare comercială / marketing; la cerere, oprim prelucrarea pe interes legitim | La cerere |
| Decizii automate (art. 22) | Nu luăm decizii cu efect juridic. Dificultatea adaptivă și rezumatele AI sunt orientative, revizuite de om | — |

4. **Răspuns** în scris, limbaj simplu, cu ce s-a făcut și cum se poate contesta (CNPDCP / ANSPDCP).
5. **Evidență**: cererea și răspunsul se păstrează 3 ani (fără să păstrăm datele șterse).

## Cazuri speciale
- **Specialistul cere ștergerea notițelor proprii:** specialistul e operator independent pentru notițele
  lui din afara aplicației; în aplicație poate cere ștergerea contului.
- **Copilul (devenit adolescent, 14+) își exercită drepturile:** Legea 195/2024 îi permite să consimtă
  singur de la 14 ani — cererea lui se tratează direct.
- **Datele de pe tabletă:** nu le avem; părintele le șterge din aplicație („Pentru părinți”) sau
  dezinstalând aplicația.
