# ADR-001: Flutter pentru aplicația copilului

Status: Acceptat · Data: 2026-09-26

## Context
Aplicația copilului trebuie să ruleze pe tablete și telefoane Android/iOS și pe desktop (Windows/macOS), să arate identic peste tot și să aibă animații fluide. Un singur dezvoltator.

## Decizie
Flutter.

## De ce
un singur cod pentru Android, iOS, Windows, macOS (și web demo); randare proprie (Skia/Impeller) → **aspect identic pe toate platformele** (esențial pentru predictibilitate la copiii cu TSA); animații la 60/120 fps; hot reload → iterație rapidă pe UI; ecosistem bun pentru jocuri 2D (Flame, Rive). Cerință a proiectului.

## Alternative
React Native; Kotlin Multiplatform (Compose MP); Unity; nativ (Swift + Kotlin); păstrarea Electron.

## De ce nu
RN — UI prin componente native → diferențe vizuale între platforme, animații complexe mai costisitoare; KMP/Compose MP — iOS/desktop încă mai puțin maturi, ecosistem de joc mic; Unity — excelent pentru jocuri 3D, dar greu pentru UI de tip aplicație (formulare, setări, accesibilitate), build-uri mari, licențiere; nativ — de 2× codul; Electron — doar desktop, ~170 MB, fără mobil (unde sunt copiii).

## Când am alege altfel
Unity dacă jocurile devin 3D/fizică complexă; nativ dacă avem nevoie de API-uri de platformă profunde (ex. Screen Time, AAC de sistem); RN dacă echipa e deja web/React.
