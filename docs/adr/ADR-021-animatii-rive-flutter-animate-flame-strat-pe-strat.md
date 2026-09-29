# ADR-021: Animații: Rive + flutter_animate + Flame (strat pe strat)

Status: Acceptat · Data: 2026-09-26 · **Partea de Rive e înlocuită de [ADR-028](ADR-028-animatie-procedurala-din-cod-fara-rive.md)** (animație procedurală din cod).

## Context
Jocurile trebuie să fie vii și interactive, dar fără să distragă sau să supra-stimuleze, și cu modul calm respectat peste tot.

## Decizie
Rive pentru personaje și obiecte cu stări (mascota, emoții, ceas); `flutter_animate` și animațiile implicite pentru efectele de UI; Flame doar pentru jocurile cu buclă (ADR-02). Toate trec prin `MotionPolicy`, ca modul calm să funcționeze peste tot.

## De ce
Rive are **state machines** (idle → bucurie → încurajare, controlate din cod), fișiere mici (zeci de KB) și randare vectorială clară la orice rezoluție. `flutter_animate` înlocuiește sute de `AnimationController` cu cod declarativ scurt.

## Alternative
Lottie; sprite sheets (PNG); doar animații Flutter scrise manual; Spine.

## De ce nu
Lottie redă doar „filme” After Effects, fără state machine interactivă, și are fișiere mai mari. Sprite sheets sunt grele în MB și se pixelizează pe tablete mari. Animațiile manuale înseamnă mult cod repetitiv. Spine e licență comercială, gândit pentru jocuri.

## Când am alege altfel
Lottie dacă primim animații gata făcute de la un designer în After Effects; sprite sheets pentru stil pixel-art.

## Consecințe
trebuie învățat editorul Rive (gratuit pentru uz individual). Animațiile personajelor sunt active separate și se versionează în `game_content`.
