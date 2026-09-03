---
title: "Private Media R2"
status: "superseded-for-mvp"
generated_at: "2026-06-22"
---

# Private Media R2

> **Histórica e supersedida pela ADR 0032.** Desde 2026-09-03, Cloudflare R2
> privado é o storage dos binários novos do MVP, com Stream HOT seletivo. O
> restante deste documento é preservado apenas como histórico do estudo.

## Contexto

Ha conflito entre PRD Master e Arquitetura Macro sobre timing de R2. A decisao atual e planejar R2 desde o MVP, mas exigir spike tecnico antes da implementacao.

## Decisao

Planejar Cloudflare R2 como destino unico de midia privada desde o MVP, com metadados/permissoes no Postgres/Supabase.

## Consequencias

- A decisao orienta specs futuras, mas nao cria codigo por si so.
- Qualquer divergencia com documento oficial deve ser registrada em `docs/open-questions.md`.
- O spike tecnico foi aprovado em `specs/009-media-r2-spike.md`.
- O desenho tecnico do spike esta registrado em `docs/spikes/media-r2/`.
- Implementacao de produto e decisao final dependem de verificacao live com credenciais R2 descartaveis.

## Resultado Do Spike

O spike produziu technical spec, matriz de testes, checklist de ameacas e harness descartavel para presigned URLs em `spikes/media-r2/`. O scan de segredos rastreados retornou sem matches e `npm.cmd run check` passou para o harness.

Evidencias:

- EV-001 upload authorization: bloqueado por falta de credenciais R2 descartaveis.
- EV-002 read authorization: bloqueado por falta de credenciais R2 descartaveis.
- EV-003 cross-tenant denial: desenhado em `media-gateway-technical-spec.md`.
- EV-004 expired URL behavior: bloqueado por falta de credenciais R2 descartaveis.
- EV-005 orphan cleanup: desenhado em `media-gateway-technical-spec.md`.
- EV-006 secret scan: passou sem matches rastreados.

Proxima acao necessaria: criar bucket R2 privado descartavel, preencher `spikes/media-r2/.env` localmente, executar `npm.cmd run smoke` com `R2_EXECUTE_LIVE_HTTP=true`, registrar saida redigida no evidence log e entao reavaliar esta ADR.
