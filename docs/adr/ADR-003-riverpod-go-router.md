# ADR-003: Riverpod + go_router

Status: Acceptat · Data: 2026-09-26

## Context
Aplicația are stare partajată (setări, profil, progres) și multe ecrane mici; trebuie să fie ușor de testat și să aibă link-uri directe în dashboard-ul web.

## Decizie
Riverpod pentru stare și injecție de dependențe; go_router pentru navigare declarativă (deep links în dashboard web).

## De ce
compile-safe, testabil fără `BuildContext`, override ușor în teste (fake repository), stare asincronă (`AsyncValue`) pentru încărcări.

## Alternative
BLoC; Provider; GetX; setState + InheritedWidget.

## De ce nu
BLoC — mult boilerplate pentru ~58 de jocuri mici; Provider — predecesorul Riverpod, limitări (dependență de context); GetX — „magie” globală, greu de testat și argumentat; setState — nu scalează.

## Când am alege altfel
BLoC în echipe mari care vor fluxuri eveniment→stare foarte stricte și auditabile.
