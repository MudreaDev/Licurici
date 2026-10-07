# Lista persoanelor împuternicite (procesatori) și a transferurilor

> Ciornă (Legea 195/2024; GDPR art. 28, 44–46). Vezi [README](README.md).
> Regula: niciun furnizor nou fără DPA semnat/acceptat și fără actualizarea acestei liste, a registrului
> și a politicii de confidențialitate.

| Furnizor | Pentru ce | Date primite | Țara / regiunea | Garanții | Stare |
|---|---|---|---|---|---|
| […furnizor VPS…] | Găzduirea serverului (Docker: API, worker, PostgreSQL, Redis, stocare) | Toate datele sincronizate | […de ales: UE / RM…] | DPA; criptarea volumului 🕓 | 🕓 de ales |
| **Anthropic, PBC** (Claude API) | Rezumatele sesiunilor scrise de AI (ADR-029) | Doar faptele agregate ale unei sesiuni (KPI, fără poreclă, fără id-uri); doar cu acordul „Rezumate AI” | SUA | DPA Anthropic; clauze contractuale standard; datele API nu se folosesc la antrenare | ✅ implementat (opțional, cheie în `.env`) |
| Microsoft (edge-tts / Azure AI Speech) | Generarea vocii aplicației, **la construire** | Doar texte fixe ale jocurilor — **nicio dată personală** | UE / global | Nu e prelucrare de date personale | ✅ (instrument de build) |
| Google (Play, FCM) | Distribuire; 🕓 notificări | 🕓 token dispozitiv | Global | DPA Google; Families Policy | 🕓 |
| Apple (App Store, APNs) | Distribuire; 🕓 notificări | 🕓 token dispozitiv | Global | DPA Apple; Kids Category | 🕓 |
| […furnizor e-mail, ex. Brevo…] | 🕓 Raport săptămânal, verificarea e-mailului | E-mail, rezumat agregat | UE | DPA | 🕓 |
| […monitorizare erori, ex. Sentry…] | 🕓 Rapoarte de eroare | Fără PII (`sendDefaultPii=false`, scrubbing) | UE | DPA | 🕓 |

**Nu sunt împuterniciți (nu primesc date):** OpenMoji, fonturile, bibliotecile open source incluse în
aplicație (rulează pe dispozitiv / server, fără trimiteri către autorii lor).

**Specialiștii invitați** nu sunt împuterniciți ai operatorului: primesc acces la cererea părintelui,
în scop terapeutic, și sunt operatori independenți pentru propria activitate profesională (vezi
[termeni.md](termeni.md) §4).
