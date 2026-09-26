# ADR-015: Stocare obiecte S3-compatibilă (RustFS în dezvoltare)

Status: Acceptat · Data: 2026-09-26

## Context
Pachetele de conținut, audio și exporturile GDPR sunt fișiere mari care nu își au locul în baza de date.

## Decizie
fișierele mari (pachete de conținut, audio, exporturi GDPR) stau într-o stocare **compatibilă S3**, servite prin URL-uri pre-semnate cu expirare. Codul vorbește doar protocolul S3 (`S3_ENDPOINT`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`), deci furnizorul se schimbă din configurație. În dezvoltare: **RustFS** (Apache-2.0, compatibil S3/MinIO) în Docker. În producție: S3 administrat, cu regiune UE.

## De ce
API S3 standard → migrare ușoară la orice furnizor; nu încărcăm Postgres cu blob-uri; link-uri temporare = securitate pentru exporturi.

## Alternative
MinIO (build din sursă); Garage (AGPL, configurare mai complexă); SeaweedFS; AWS S3 / Cloudflare R2 / Hetzner Object Storage; sistem de fișiere local; Postgres `bytea`.

## De ce nu
MinIO — fără imagini oficiale, ar trebui construit și întreținut de noi; Garage — layout de cluster de configurat și pentru un singur nod; fișiere locale — nu scalează la mai multe instanțe, fără URL-uri pre-semnate; `bytea` — umflă baza și backup-urile.

## Când am alege altfel
RustFS se declară încă în dezvoltare rapidă, deci **nu îl folosim în producție**. Acolo alegem un S3 administrat în UE (durabilitate, backup, CDN) sau Garage dacă vrem să găzduim singuri.

## Istoric
planul inițial era MinIO, dar imaginea comunitară `minio/minio` nu mai e publicată pe Docker Hub (verificat în 09.2026). Faptul că nu ne-am legat de un anumit furnizor (Adapter + protocol standard) a făcut schimbarea ieftină.
