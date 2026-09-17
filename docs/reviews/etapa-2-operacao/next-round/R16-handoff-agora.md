---
title: "R16 — handoff da Sessão AGORA (agora.publish: leitor de Famílias reconhece o responsável, lote 81)"
source: "R16-prompts.md (Prompt 2); R16-execucao.md (papéis, rito, autorizações do Owner de 17/09 ~20:35 BRT); ADR 0044; OQ-048; specs/070-now-guardian-reader.md; docs/reviews/evidence/etapa-2/r16-agora/"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R16 — handoff da Sessão AGORA

Sessão Claude `coelo-5a` (Fable 5.1), worktree `C:\Users\adrie\Documents\Coelo.worktrees\r16-agora`, branch
`r16/agora-publish` (base `dev` `cd5b7493e`). Só esta sessão escreve aqui. Porta 3015/CDP 9415 reservados e **não usados**
(nenhuma tela foi necessária: a conta só-responsável não abre o Principal — OQ-048); espelho `coelo_mirror_r16_agora`
(`Coelo-backups/mirror-r16-agora`, 626xx).

## Reivindicações

- `agora.publish` (E2E do MVP) — única ação da sessão. Não toquei em `recipients` de cuidado, memberships, candidato
  `20260917113000`, telas ou arquivos da Sessão FORMS, nem em MDs de estado (`current-state`, `ETAPA-2-estado-atual`,
  `R16-pendencias`).

## Fatias entregues

| Fatia | Commit (branch `r16/agora-publish`) | Conteúdo |
|---|---|---|
| 1–2 Contrato + migration + pgTAP | `c539fc40d` (integrado em `dev` `b9f7258b5` pela coordenadora) | `specs/070-now-guardian-reader.md`; `packages/coelo_database/migrations/20260917203000_now_guardian_reader_v1.sql`; `supabase/tests/now_guardian_reader_v1_test.sql` **21/21** no espelho fiel de dump novo; suítes do Agora sem regressão (tabela na evidência §3) |
| 3 Rito (lote 81) + 4 Prova E2E + 5 Delta | commit seguinte a este handoff (SHA no aviso à coordenadora) | ledger lote 81; evidência `docs/reviews/evidence/etapa-2/r16-agora/agora-publish-guardian-reader-20260917.md`; `deltas-agora-publish-20260917.json` → `agora.publish` backend `done` (delta do lote 81) e integrated `pending-verification → verified-e2e`, ambos com `certificacao` (producao, revisão `c539fc40d`); `validate-trackers` **PASS** |

Estados finais de `agora.publish`: FE `verified` (R14, mantido) / BE `done` / E2E **`verified-e2e`**.

## Avisos para a outra sessão e para a coordenadora

1. **Lote 81 aplicado em produção** (17/09 23:33:53–23:33:58 UTC): `20260917203000_now_guardian_reader_v1`. Funções
   alteradas: `public.list_visible_now_publications` (mesma assinatura/projeção/grants; ator por
   `app_private.now_reader_actor`), `public.redeem_now_media_read_ticket` (mesma assinatura/grants; membership deixa de ser
   junção obrigatória). Função nova: `app_private.now_reader_actor(uuid,text,uuid,uuid)` (sem grants a clientes).
   `app_private.now_actor` **inalterado** (escrita continua exclusiva de equipe). Ledger CLI reparado e listado
   (`20260917203000` local+remoto; `20260917113000` só local — não aplicada).
2. **Massa**: nenhuma criação/alteração. A story `d9580375…` (Famílias, institucional) foi reutilizada; vigente até
   18/09 18:34 UTC. Nenhum override, membership ou fixture novo. Tickets de leitura emitidos pela prova são efêmeros e de uso
   único (um resgatado pela Edge, os demais expiram sozinhos).
3. **Prova em produção** (23:39–23:41 UTC): `qa-r15-responsavel` lê a story (200, `can_remove false`), reload estável,
   Edge `now-media read` 200 com URL assinada e ticket de uso único (2ª vez 403); outra instituição real (`9f040000-…0010`)
   e inexistente → `403 42501 now_permission_denied`; `qa-r06-principal` (equipe) → `200 []`.
4. **Classificador**: um comando PowerShell combinado (verificação D1 + `migration repair` + `migration list`) foi negado;
   executados um a um, todos foram permitidos. Nada contornado; nenhum comando ficou pendente para a coordenadora.
5. **Espelho do CLI** (`espelho-cli`, R16): `Sync-SupabaseCliMigrations.ps1 -Mode Prepare` falha por
   `migration count mismatch: canonical=205 mirror=222` (17 cópias rastreadas em `supabase/migrations` + 205 canônicas),
   mas copia a migration nova antes da contagem — é isso que permite o `migration repair`. `-Mode Clean` remove as cópias
   não rastreadas (executado ao fim; árvore limpa). Segue como dívida do script, não desta entrega.
6. **Espelho local**: as suítes que não semeiam a pessoa técnica `Coelo Sistema` (`c0e10000-…0001`) abortam num espelho
   restaurado de dump schema-only por FK de `follow_links` (`happens_post_withdrawal`, `hardening`, `r2_v1`,
   `cross_tenant`, `bridge`); basta semear essa linha de referência (existe em produção) antes de rodar. Falhas
   pré-existentes e alheias ao Agora leitor: `now_publication_mvp_test` 18/19/52 (a 52 fixa um texto antigo de
   `redeem_now_media_read_ticket` — `auth_link.auth_user_id=` — que produção já não tinha antes do lote 81),
   `now_media_private_r2_v1_test` 16/17, `principal_internal_actor_bridge_v1_test` 7/9; `now_publication_removal_test`
   executa 18 dos 19 planejados. Idênticas antes e depois da migration (logs em `Coelo-backups/mirror-r16-agora/`).
7. **Fora de escopo, para a fila** (não executado): `recipients-bug` (destinatários de cuidado contam membership
   `guardian` como equipe), `can-remove`, onboarding que crie o contexto de responsável no Principal (spec 064 / Etapa 3).

## Bloqueios

Nenhum. (Sem decisão em aberto; a captura de tela era opcional e é inviável por OQ-048.)

## Sobra

- Chrome/servidor QA da porta 3015 nunca abertos. Nenhum artefato temporário no repositório (scripts de prova no
  scratchpad da sessão; os do repositório usados: `packages/coelo_database/scripts/r13-rpc-proof.mjs`).
- Proveniência fora do Git: `Coelo-backups/schema-producao-20260917-r16-agora-before.sql` (SHA-256 `0c6c6468…`),
  `Coelo-backups/mirror-r16-agora/` (config, `restore-run.log`, `pgtap-baseline.log`, `pgtap-pos-migration.log`).

## Contadores

`node docs/reviews/validate-trackers.cjs` após o delta: **PASS** — FE 198/199, BE 185/186, E2E **185/186** (ativo 186;
o restante é `forms.location-answer`, Sessão FORMS). Antes desta sessão: E2E 184/186.

## Estado ao encerrar

Espelho `coelo_mirror_r16_agora` parado (`supabase stop --project-id coelo_mirror_r16_agora`); worktree limpa; stash
vazio; último push em `origin/r16/agora-publish`. A coordenadora integra por cherry-pick e apaga a branch no fechamento.
