# ADR-004: Offline-first cu Drift (SQLite) local

Status: Acceptat · Data: 2026-09-26

## Context
Copiii folosesc tablete des fără internet; datele copilului trebuie să rămână pe dispozitiv dacă părintele nu creează cont.

## Decizie
SQLite prin Drift; datele copilului trăiesc **întâi pe dispozitiv**.

## De ce
copiii folosesc tablete fără internet (mașină, grădiniță); confidențialitate implicită (fără cont = nimic nu pleacă de pe dispozitiv); Drift = SQL tipizat, migrații, stream-uri reactive, funcționează pe toate platformele (web prin WASM).

## Alternative
Hive/Isar (NoSQL); shared_preferences; ObjectBox; Firebase Firestore offline.

## De ce nu
Hive/Isar — mentenanță incertă, interogări limitate pentru statistici; shared_preferences — doar chei simple; ObjectBox — licență/sincronizare comercială; Firestore — date la Google (transfer SUA, GDPR pentru copii), vendor lock-in.

## Când am alege altfel
Firestore/Supabase pentru un MVP rapid fără cerințe stricte de confidențialitate.
