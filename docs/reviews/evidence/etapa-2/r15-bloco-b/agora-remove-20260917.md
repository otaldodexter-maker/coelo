---
source: "Sessão B da R15 (Fable 5.1), 17/09/2026; ADR 0040; ADR 0041 D5; R14 Sessão 7 (agora-remove-20260916.md, handoff §5); lote 71 (contrato de remoção); lote 75 (PT409); lote 79 (projeção do feed)"
status: evidence
lifecycle: current
generated_at: 2026-09-17
action_id: "agora.remove"
---

# Agora › Remover imediatamente (`agora.remove`) — projeção pelo rito (lote 79), Edge `now-media`, rota real e negativas, 17/09/2026

Ambiente: produção; build QA `r15/bloco-b` em `127.0.0.1:3015`, Chrome CDP 9445 (perfil
`%TEMP%\coelo-r15-b-publicacoes-chrome`), sessão `qa-r06-publicacoes@coelo.me` (autora; pessoa
`92b97c39…`); leitor `qa-r06-principal@coelo.me` por PostgREST/Edge (`scratchpad/rpc.mjs`,
`now-remove-neg.mjs`, sem chave de serviço); estado por `supabase db query --linked` (leitura).
Capturas em `capturas/agora-remove-*.png`. Massa: duas stories sintéticas de audiência `school_staff`
publicadas pelo **contrato** (`save_now_draft` → `now-media` prepare → `PUT` R2 assinado → finalize →
`publish_now`, script `now-publish.mjs`; PNG 64×64 sintético) para servir de alvo — a publicação pela tela
já é verified (`agora.create/publish` R14).

## 1. Backend — lote 79 (rito) e Edge

- Migration `20260917140000_now_feed_removal_projection_v1`: `list_visible_now_publications` passa a projetar
  `management_version bigint` e `can_remove boolean` (autor = ator **e** `now.publications.remove` no contexto;
  sem direito novo). Corpo pré-lote em produção idêntico ao dump de 17/09 (md5 CRLF `3416f5b1…` = dump
  `90e6b84b…`; dump prévio `schema-producao-20260917-r15-b-lote79-before.sql`, SHA-256 `33c02622…`).
  Espelho `coelo_mirror_r15_b`: aplicada 2× sem erro; pgTAP nova `now_feed_removal_projection_v1_test`
  **9/9** (assinatura, grants, autor `can_remove true` + `management_version 2`, membro sem remove `false`,
  outro tenant `42501`, leitura não muta); suítes do Agora antes/depois iguais exceto o guard 58 de
  `now_publication_mvp_test`, atualizado para a projeção ampliada (65/5 → 66/4). Aplicada às 17:02 UTC por
  `db query --linked -f`; ledger `20260917140000` reparado/listado; lote 79 na ordem-de-aplicação.
- Produção após o lote: feed como autora → `can_remove true`, `management_version 2`; como leitora →
  `can_remove false` (mesma story).
- Edge `now-media` deployada (17:03 UTC) após `deno test` 16/16: `action: remove` trata `PT409` como
  `409 expected_version_conflict` (além de `40001`, agora extinto pelo lote 75).

## 2. Rota real — remoção imediata pela tela

| action_id | Rota normal | Escrita em produção | Reload | Negativa |
|---|---|---|---|---|
| agora.remove | `/principal-now` como autora: story "QA R15 Agora remover pela tela 2" (`ab13104e-f1f9-4399-9b96-ce1eb821f05f`) renderizada (03) → "⋯" → folha "Opções deste Agora" com **"Remover este Agora"** (02, só aparece com `can_remove true`) → diálogo "Remover este Agora? Ele sai do feed imediatamente para todos e a mídia é apagada. A remoção fica registrada." (04) → **Remover** → snackbar "Agora removido." e viewer "Nada novo no Agora" (05) | Edge `now-media remove` → `remove_now_publication`: `status removed`, `management_version 3`, `removed_at 17:15:42 UTC`; asset `7a900c37…` `deleted`; `now_media_purge_jobs` `purged` (1 tentativa, 17:15:42); auditoria `publication_removed` (id 57) pela atora `92b97c39…` com `request_id` do recibo | carga completa de `/principal-now`: "Nada novo no Agora" (06); leitora: `list_visible_now_publications` → `[]` | versão defasada (`expected_version 99`, autora) → **`409 expected_version_conflict`** em 356 ms pela Edge (PT409, sem laço), sem mutação; id de outro tenant/inexistente coberto por pgTAP `42501` (cross-tenant 6/6 e projeção 9/9) |

## 3. Achado — capacidade de remoção não é só do autor (por desenho, registrado)

A negativa "não autora" foi tentada com `qa-r06-principal` sobre a primeira story (`ff93ef01…`, v2): a Edge
respondeu **200 `removed` / `purged`** — a identidade é Owner de plataforma com membership no tenant e,
portanto, tem `now.publications.remove` pela capacidade `institution_admin` do lote 71 (ADR 0040: "autor ou
administração do contexto"). Não é defeito de autorização: a RPC continua exigindo a permissão no contexto
(cross-tenant → `42501`, pgTAP). Mas expõe uma assimetria de composição: o feed só oferece "Remover este
Agora" ao **autor** (`can_remove` = autor ∧ permissão), enquanto a RPC também aceita administradores com a
permissão — a tela é mais restrita que o contrato. Fica como observação para a coordenadora/Owner (ampliar
`can_remove` para "permissão no contexto" ou manter só autor); nada alterado.

## 4. Negativa D5 (identidade de outro tenant pela fixture) — não executada nesta sessão

`app_private.seed_qa_r14_chat_cross_tenant_user` exige um usuário Auth pré-existente
(`qa-r14-chat-cross-tenant@coelo.me`) cuja senha não está em `Coelo-backups` (nenhum `qa-r14-*.env`); sem
login não há chamada à Edge por essa identidade. Causa classificada: **sessão** (credencial ausente), não
decisão nem ambiente. Cobertura equivalente já existente: pgTAP `now_publication_removal_cross_tenant_test`
6/6 (`42501` sem mutação) e `now_feed_removal_projection_v1_test` (`42501` no feed de outro tenant), ambas no
espelho de 17/09.

## Separação FE / BE / E2E

- FE: **verified** — opção condicionada a `can_remove`, confirmação, remoção imediata, estados de sucesso e
  recarga do feed na rota real.
- BE: **done** — projeção (lote 79) + Edge deployada; contrato de remoção (lote 71) exercitado em produção com
  recibo de purge e auditoria; PT409 → 409.
- E2E: **verified-e2e** — remoção imediata pela tela em produção, reload e negativa 409 sem mutação; D5 por
  fixture pendente (sessão), coberta por pgTAP.
