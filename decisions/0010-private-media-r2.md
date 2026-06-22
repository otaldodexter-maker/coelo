---
title: "Private Media R2"
status: "Proposed - spike required"
generated_at: "2026-06-22"
---

# Private Media R2

## Contexto

Ha conflito entre PRD Master e Arquitetura Macro sobre timing de R2. A decisao atual e planejar R2 desde o MVP, mas exigir spike tecnico antes da implementacao.

## Decisao

Planejar Cloudflare R2 como destino unico de midia privada desde o MVP, com metadados/permissoes no Postgres/Supabase.

## Consequencias

- A decisao orienta specs futuras, mas nao cria codigo por si so.
- Qualquer divergencia com documento oficial deve ser registrada em `docs/open-questions.md`.
- Implementacao depende de spec aprovada.
