---
name: coelo-backend
description: Use when a Coelo task involves Supabase, Postgres, Auth, RLS, RPCs, Edge Functions, Cloudflare R2, Media Gateway, migrations or production.
metadata:
  status: "active"
  updated_at: "2026-09-18"
---

# Coelo Back-end (modo de construção, ADR 0045 §7)

Construa, teste, aplique, mostre. Sem recorte, evidência, handoff ou rodada.
Versão anterior (com o rito completo) em `docs/archive/skills-20260918/`.

## Onde está

- Migrations: `packages/coelo_database/migrations/` (forward-only, carimbo
  `YYYYMMDDHHMMSS_nome_vN.sql`); cópia em `packages/coelo_database/supabase/migrations/`.
- pgTAP: `packages/coelo_database/tests/`. Edges: `packages/coelo_database/supabase/functions/`.
- Produção = único remoto: projeto `evvbomzejfijozbtgvpt`. Último lote: ver a
  última linha de `packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt`.

## Como aplicar

1. Escreva a migration e o pgTAP; rode o pgTAP num Postgres local ou espelho.
2. `supabase db query --linked --workdir packages/coelo_database -f migrations/<arquivo>`
3. `supabase migration repair --status applied <carimbo> --linked` (exige a cópia em `supabase/migrations/`), depois `supabase migration list --linked`.
4. Anote o arquivo no fim de `ordem-de-aplicacao-producao.txt`.
5. Edge: `supabase functions deploy <nome> --project-ref evvbomzejfijozbtgvpt --workdir packages/coelo_database`; Edge chamada por pg_cron usa `verify_jwt = false` e valida o bearer no handler.

Dump prévio, espelho de ACL e SHA-256 só quando o Owner pedir revisão formal.

## Regras que não mudam

- RLS deny-by-default; RPC valida ator, capacidade, tenant e hierarquia no servidor. Nada de IDOR/BOLA.
- `service_role`, token, CPF, dado de criança e mídia privada nunca em cliente, Git, log ou URL.
- Mídia: R2 privado via Media Gateway (ADR 0032); Postgres guarda catálogo, permissões e auditoria.
- Versão defasada: `raise exception using errcode = 'PT409', detail = '<FAMÍLIA>_STALE_VERSION'`. **Nunca 40001** (derruba o PostgREST).
- Busca por dado pessoal: mínimo de caracteres, escopo no servidor, CPF nunca no resultado.
- Responsável sem membership: leitor reconhece por `guardian_links` + `can_view` (`app_private.now_reader_actor`); escrita continua só de equipe.
- Identidades QA: `qa-r06-<area>`, `qa-r15-responsavel`; credenciais em `C:\Users\adrie\Documents\Coelo-backups\`, nunca impressas.
