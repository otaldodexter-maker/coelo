---
title: "Lgpd Security Context"
status: "planning-context"
generated_at: "2026-06-22"
---

# LGPD Security Context

## Objetivo

Orientar privacidade, seguranca, midia privada, auditoria, retencao, suporte interno e protecao de criancas.

## Fontes

- `docs/security/lgpd-security-media.md`
- `docs/security/auth-multitenant-permissions.md`
- `docs/data/data-model.md`
- `decisions/0010-private-media-r2.md`

## Regras

- Melhor interesse da crianca e minimizacao de dados.
- Midia privada em Cloudflare R2 desde o MVP, com spike antes de implementacao.
- Metadados, permissoes e vinculos no Postgres/Supabase.
- Segredos nunca no cliente.
- Suporte e acoes sensiveis auditados.
