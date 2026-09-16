---
title: "R14 — handoff da Sessão 7 (Agora e Momentos)"
source: "briefing comum R14 (16/09); R14-pendencias.md; ADR 0037; ADR 0040; ADR 0041; inventario-etapa-2.json"
status: "active"
lifecycle: "current"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
audience: "team"
---

# R14 — handoff da Sessão 7

Sessão 7 (Opus 5), worktree `C:\Users\adrie\Documents\Coelo.worktrees\r14-agora-momentos`,
branch `r14/agora-momentos`, base `dev dbe518101`. Servidor em `127.0.0.1:3020` (a porta designada
`3018` não está na allowlist CORS de `now-media`/`moments-media`; `3020` está e não pertence a outra
sessão), Chrome CDP `9418`, perfil `%TEMP%\coelo-r14-agora-chrome`, espelho `mirror-r14-agora`
(`coelo_mirror_r14_agora`, portas 618xx). Só a Sessão 7 escreve aqui; a coordenadora integra por
cherry-pick.

## Reivindicações

| Tela | action_ids | Desde |
|---|---|---|
| Coelo (Principal) › Agora | agora.create, agora.publish, agora.view, agora.expire, agora.remove | 16/09 11:40 BRT |
| Coelo (Principal) › Momentos | momentos.view, momentos.publish, momentos.remove (+ momentos.create se o bloqueio de ambiente tiver caído) | 16/09 11:40 BRT |

## Fatias entregues

| SHA | action_ids → estados | Owner items | Evidência |
|---|---|---|---|
| cf8139e8c | agora.create FE verified, BE done, E2E verified-e2e; agora.view FE verified, BE done, E2E verified-e2e; agora.publish FE verified, BE done (E2E pending: audiência Famílias sem identidade responsável, D6); agora.expire BE done (E2E pending: 24 h reais) | — | r14-sessao-7/agora-20260916.md + deltas-agora-20260916.json |
| d0cb90dd4 | agora.remove FE local-green (opção "Remover este Agora", confirmação, estados, releitura; 67/67 testes); E2E pending | — | r14-sessao-7/agora-remove-20260916.md |

## Avisos para as outras sessões

- **Incidente de produção (12:35 BRT em diante):** PostgREST respondeu `504`/`PGRST003 Timed out
  acquiring connection from connection pool` e depois ficou mudo para todas as chamadas REST/Edge
  (Auth continuou ok; projeto `ACTIVE_HEALTHY` na Management API) por mais de 50 minutos. Gatilho
  observado nesta sessão: `publish_now` do rascunho `1cb15b83…` por identidade não autora (primeira
  resposta `504 upstream request timeout`). Não consegui ler `pg_stat_activity`/locks (classificador
  negou). Se outra sessão estava com chamadas longas (`child_safety_change_lifecycle`), pode ser a
  mesma causa. Nenhum SQL foi executado por mim em produção.
- Massa `R14 S7` criada em produção, instituição `d0c40000-…0001`: publicações do Agora `a4e65c73…`
  (published, families), `655e437b…` (published, school_staff, criada por RPC) e rascunho `1cb15b83…`.
- O publicador do Agora hospedado publica **só para Famílias**; nenhuma identidade QA é responsável
  com criança, então nada publicado pela tela aparece em feed algum (nem para o autor). Não é
  defeito de RLS; é regra de audiência + massa. Detalhe em `agora-20260916.md`.
- O FE de `agora.remove` só mostra a opção quando `list_visible_now_publications` projetar
  `management_version` e `can_remove` (candidato de migration no scratchpad da sessão; a criação do
  arquivo em `packages/coelo_database/migrations` foi recusada pelo classificador). Em produção a
  opção não aparece (fail-closed); nenhum comportamento existente muda.
- Espelho `coelo_mirror_r14_agora` tem o candidato aplicado; foi parado ao fim da sessão.

## Sobra para a R15 (sugestão)

1. `agora.remove`: aplicar a projeção `management_version`/`can_remove` pelo rito (lote novo),
   atualizar o guard 58 de `now_publication_mvp_test` (assinatura literal da projeção), rebuild e
   prova pela tela; negativa D5 com a fixture (migration mínima + revogação) ou identidade QA de
   escopo `institution` em outro tenant com credencial no cofre.
2. Agora: alinhar audiências do publicador (chips como Momentos/Acontece com validação
   server-side) ou incluir as publicações do próprio autor no feed; corrigir a copy fixa
   "Somente famílias e responsáveis deste contexto" na story.
3. `agora.publish` E2E: depende de identidade responsável (ou do item 2); `agora.expire` E2E:
   observação após 24 h (a4e65c73 e 655e437b expiram em 17/09 ~15:06/15:16 UTC).
4. Momentos: ver seção Bloqueios.

## Bloqueios

| Item | Causa classificada | Gate |
|---|---|---|
| agora.publish E2E | massa/decisão — audiência Famílias exige responsável com criança vinculada; D6 veda massa fictícia | identidade responsável QA ou audiência de staff no publicador |
| agora.expire E2E | tempo/ambiente — expiração automática de 24 h; relógio/dados não alterados | reobservar em 17/09 |
| agora.remove BE/E2E | ambiente — classificador recusou criar migration (projeção e fixture D5) e `supabase db query`; sessão — senha da identidade sintética `qa-r14-chat-cross-tenant` não disponível | coordenadora aplica o candidato e a fixture pelo rito |
| momentos.* | ambiente — PostgREST de produção sem resposta (pool esgotado) a partir das 12:35 BRT; ver seção abaixo quando/se recuperar | PostgREST responder |

## Contadores

`validate-trackers.cjs` após cf8139e8c: PASS — FE 188/232, BE 171/219, E2E 161/186 (ativo 186),
Owner 21/53 (linhas de Owner não alteradas por esta sessão).
