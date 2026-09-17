---
title: "R15 — handoff do Bloco B (migrations aplicadas + massa + OQ-047; backend + rota real)"
source: "Sessão B da R15 (Fable 5.1), 17/09/2026; R15-prompts.md (Prompt B); ADR 0042 E1/E2/E6/E7; R14-handoff-sessao-8/9/10.md; docs/reviews/evidence/etapa-2/r15-bloco-b/"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R15 — handoff do Bloco B

Worktree `Coelo.worktrees\r15-bloco-b`, branch `r15/bloco-b` (base `dev` `b98299d13`). Porta 3015 / CDP 9415,
perfil `%TEMP%\coelo-r15-b-chrome`; espelho `coelo_mirror_r15_b` (portas 622xx, `Coelo-backups/mirror-r15-b`),
restaurado do dump novo `schema-producao-20260917-r15-b-before.sql` (SHA-256 `c87f4d67`). Sessões QA usadas até
aqui: `qa-r06-publicacoes` (negativa PostgREST), `qa-r06-acessos` (rota real). Nenhuma credencial em log.

## Reivindicações

- Fatia 1 — OQ-047 (E1): **entregue e aplicada em produção (lote 75)**.
- Fatia 2 — massa `QA R15` (E2): **em andamento** (tela do superadmin com `qa-r06-acessos`); Blocos A e C2
  aguardam este handoff para `agora.publish`/B5/B6 — IDs serão listados aqui na próxima entrega.
- Fatias 3–7 (Segurança da criança, Assiduidade, Medicação B8+E7, Arquivar B1, Agora): reivindicadas pelo Bloco B,
  ainda não iniciadas.

## Fatias entregues

| SHA | Fatia | action_ids → estados | Owner items | Evidência |
|---|---|---|---|---|
| (este commit) | OQ-047 (E1) — migration única `20260917090000_pt409_stale_version_v1` (126 funções, 175 raises 40001 → PT409, 18 handlers de envelope, 28 famílias) + pgTAP `pt409_stale_version_v1_test` 37/37 + 8 suítes ajustadas + 22 repositórios FE e Edge `now-media` mapeando PT409; **aplicada em produção às 12:30 UTC, ledger `20260917090000` confirmado, lote 75** | nenhum estado alterado (nenhum delta JSON) | nenhum | `r15-bloco-b/oq047-pt409-20260917.md` |

## Avisos para as outras sessões e para a coordenadora

1. **Produção já responde PT409 em todas as famílias** (0 `raise serialization_failure`, 0 `errcode='40001'`):
   negativas de versão defasada por PostgREST são seguras (HTTP 409 `PT409`, sem laço). Provado com
   `remove_now_publication` (versão 99 → 409 `PT409` `NOW_STALE_VERSION`, sem mutação). O laço aberto pela
   Sessão A em `superadmin_access_profile_save` terminou com o lote 75 (`pg_stat_activity` sem backend PostgREST).
2. **FE**: 22 repositórios Dart do superadmin ganharam `'PT409'` ao lado de `'40001'` (uma linha cada — lista na
   evidência §4). Integrar em `dev` antes que A/C1/C2 toquem os mesmos arquivos. `flutter analyze` limpo; 1319
   testes de dados verdes. Edge `now-media` (`action: remove`) trata `PT409` como 409 — **deploy pendente**
   (`supabase functions deploy now-media`), previsto na fatia 7 (agora.remove); até lá o Edge devolve 422
   `publication_remove_denied` para versão defasada (a remoção pela tela ainda não existe em produção).
3. **Detail por família** quando o raise não tinha `detail`: `<FAMÍLIA>_STALE_VERSION` (ACCESS_PROFILE, ACTIVITY,
   AGENDA, CHILD_SAFETY, CIRCULAR, GROUP, HAPPENS, HEALTH_CARE, INSTITUTION, INTERNAL_USER, MEDICATION, MOMENTS, NOW,
   PERSON, PLAN, PROFILE_ABOUT, ROUTINE, SUPPORT, UNIT), `FORMS_STALE_VERSION`/`FORMS_COMMAND_CONFLICT`,
   `FORMS_WORKER_CONFLICT`. Details já existentes (`SAI_CONCURRENT_CHANGE`, `CIRCULAR_CONFLICT`, `NOTICE_CONFLICT`)
   e mensagens preservados; wrappers de envelope continuam devolvendo 200 `SAI_CONCURRENT_CHANGE`.
4. **Regra durável**: já em `current-state.md`/ADR 0042; falta projetar em `coelo-supabase`/`docs/knowledge`
   (coordenadora/knowledge). OQ-047 recebeu nota de resolução em `docs/open-questions.md`.
5. **Incidente de sessão** (09:00–09:06 BRT): instância duplicada da Sessão B (subagente da coordenadora)
   sobrescreveu a migration nesta worktree e contaminou o espelho; regerada e espelho recriado (evidência, seção
   "Incidente de sessão"). Nenhum efeito em produção.
6. `ap_models_nominal_rollback_test.sql` recria `public.superadmin_access_profile_models_cursor` fora da
   transação (linha 10) e polui o espelho para as suítes seguintes — pré-existente, não corrigido nesta fatia.
7. Lotes: C1 usa 76 e C2 77+ (coordenadora, 12:45 UTC).

## Pedidos de apoio

Nenhum até agora.

## Bloqueios

| Gate | Causa classificada | Detalhe |
|---|---|---|
| Prova comportamental por família no espelho (Formulários, Planos, Suporte, Acontece) | ambiente (drift do espelho: fixtures param antes da asserção de versão defasada; idêntico antes/depois) | coberto por suíte estrutural 37/37 + antes/depois de 234 suítes sem regressão + negativa em produção |

## Contadores

`node docs/reviews/validate-trackers.cjs` → PASS, inalterados (FE 189/232, BE 172/219, E2E 162/186, Owner 21/53).
