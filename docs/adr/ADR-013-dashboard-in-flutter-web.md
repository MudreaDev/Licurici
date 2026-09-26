# ADR-013: Dashboard în Flutter Web

Status: Acceptat · Data: 2026-09-26

## Context
Părinții și terapeuții au nevoie de un panou web cu statistici și setări; aplicația copilului e deja în Flutter.

## Decizie
panoul părinte/terapeut în Flutter Web.

## De ce
refolosim `licurici_ui`, `licurici_core`, modelele și clientul API; un singur limbaj; grafice cu `fl_chart`.

## Alternative
React/Next.js; Angular; Vue.

## De ce nu
ar dubla modelele, componentele și testele; SEO nu contează (panou autentificat).

## Când am alege altfel
React/Next dacă panoul devine un site public cu SEO sau o echipă web separată îl dezvoltă. Dezavantaj asumat: bundle inițial mai mare (~2 MB) → mitigat prin caching și `--wasm`.
