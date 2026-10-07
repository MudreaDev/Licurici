# Politica de retenție (cât păstrăm datele)

> Ciornă. Vezi [README](README.md). Principiul: păstrăm cât e nevoie pentru scop, apoi ștergem
> automat. ✅ = aplicat de cod · 🕓 = de implementat (job / configurare).

| Date | Unde | Cât | Cum se șterge | Stare |
|---|---|---|---|---|
| Contul (e-mail, hash parolă) | Server | Cât există contul | La cererea de ștergere: anonimizat imediat, șters definitiv la 7 zile (`purge-account`) | ✅ |
| Profilul copilului | Server | Cât există profilul | Marcare imediată, definitiv la 7 zile (`purge-child`), în cascadă | ✅ |
| Sesiunile de joc | Server | **24 de luni rulant** | Job zilnic `expire-sessions` (coada `gdpr`, 03:30) — `backend/src/gdpr/retention.ts` | ✅ |
| Rezumatele AI | Server | Cât există sesiunea | Cascadă cu sesiunea | ✅ |
| Partajările cu specialistul | Server | Până la termen (implicit 90 zile) / revocare | La revocare: imediat; la expirare: accesul se oprește (rândul rămâne până la reînnoire/revocare) | ✅ (🕓 curățarea rândurilor expirate) |
| Dovezile consimțământului | Server | Durata contului + 3 ani | 🕓 de mutat într-un jurnal separat care supraviețuiește contului 3 ani (acum se șterg odată cu contul) | 🕓 |
| Jurnalul de audit | Server | Cât există contul | Cascadă cu contul | ✅ |
| Refresh tokenuri | Redis | 30 de zile / până la folosire / ieșire | TTL; de unică folosință | ✅ |
| Jurnale tehnice | Server | 30 de zile | Rotație (driverul de loguri Docker / furnizor); conținutul e deja fără date personale (IP trunchiat, fără antete) | 🕓 rotația |
| Copiile de siguranță | Server/furnizor | ≤ 35 de zile | Rotație; o ștergere ajunge și în backup-uri după cel mult 35 de zile | 🕓 |
| Datele de pe tabletă (sesiuni, setări, abțibilduri, stele, acvariu) | Dispozitiv | Cât există aplicația | Din „Pentru părinți” sau dezinstalare | ✅ (operatorul nu le are) |
| Fotografia fișei de colorat | Dispozitiv (memorie) | Secunde | Nu se salvează; doar desenul decupat rămâne local | ✅ |

**Perioada de grație de 7 zile** există ca o ștergere din greșeală să poată fi anulată (la cerere, prin
suport). În acest timp, **accesul e deja oprit** pentru toată lumea.
