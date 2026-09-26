# ADR-017: Traefik ca reverse proxy

Status: Acceptat · Data: 2026-09-26

## Context
Serverul expune API-ul și dashboard-ul pe HTTPS, cu certificate reînnoite automat.

## Decizie
Traefik (TLS automat Let’s Encrypt, rutare pe etichete Docker, rate limit de bază, headere de securitate).

## Alternative
Nginx; Caddy; HAProxy.

## De ce nu
Nginx — configurare manuală a certificatelor/rutelor; Caddy — la fel de valid (mai simplu), Traefik câștigă prin descoperirea automată a containerelor.

## Când am alege altfel
Nginx pentru control fin/performanță la fișiere statice mari.
