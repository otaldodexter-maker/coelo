---
source: "Sessão RESERVA da R16 (Opus 5, coelo-8d), 18/09/2026; R16-prompt-reserva-20260918.md (Bloco 4, D6 padrão 'o feed segue a RPC'); dívida can-remove (ADR 0044); ADR 0040; lotes 79 e 81; r16-agora/agora-publish-guardian-reader-20260917.md"
status: evidence
lifecycle: current
generated_at: 2026-09-18
action_ids: "agora.remove (projeção), agora.publish"
---

# Agora › `can_remove` segue a RPC (D6) — lote 82 e prova em produção (18/09/2026)

## 1. Contrato

`remove_now_publication` (lote 71/75) aceita qualquer ator com `now.publications.remove` no tenant/contexto (autor OU
papel institucional). A projeção `can_remove` do feed (lote 79, preservada no 81) exigia também autoria, então o botão
"Remover este Agora" não aparecia para administradores que a RPC aceita. Padrão D6 adotado (Owner não escolheu a outra
opção no início da sessão): **o feed segue a RPC**. `20260918140000_now_feed_can_remove_follows_rpc_v1` (lote 82,
14:46 UTC) recria `list_visible_now_publications` com o corpo vigente extraído do dump de produção de 18/09 (`9bb98a47`,
inclusive `now_reader_actor` do lote 81) e altera só a linha `can_remove := actor_can_remove`. Nenhum direito novo.
pgTAP no espelho fiel: `now_feed_can_remove_follows_rpc_v1_test` **11/11** (antes da migration falhavam só as 3
asserções da projeção — a RPC já aceitava o administrador: exatamente a divergência), `now_feed_removal_projection_v1`
9/9 (asserção estrutural alinhada), `now_guardian_reader_v1` 21/21, `now_publication_removal` 18/18(19),
`now_publication_mvp` 67/70 (18/19/52 pré-existentes). Pós-verificação em produção: projeção sem autoria, com
`now_reader_actor`, grants iguais.

## 2. Prova em produção (3014; identidades Owner com membership de serviço na QA R04 Cuidado — todas com `now.publications.remove`)

| Passo | Resultado | Captura |
|---|---|---|
| Autora `qa-r06-operacoes`: `/principal-now/publication` › Adicionar mídia (seletor interceptado por CDP, PNG de teste sem dados pessoais) › Salvar rascunho | rascunho `fcfe2865-d901-4d04-9a4c-dbea13377577` com `media.asset_id 15b914e7…` (Edge `now-media`, R2 privado) | `agora-01-publicar-midia.png` |
| Público "Equipe" (`school_staff`) e publicação (`save_now_draft` v2 + `publish_now`, mesmo contrato da tela — o painel "Público e contexto" não abriu por clique de coordenada) | `published`, vigente até 19/09 15:14 UTC, `management_version 3` | — |
| Viewer da autora (`/principal-now`) | story "QA R16 RESERVA D6 can_remove" visível; menu "…" mostra **"Remover este Agora"** (`can_remove true`) | `agora-02-story-publicada.png`, `agora-03-remover-este-agora.png` |
| Não autora com capacidade (`qa-r06-publicacoes`, PostgREST `list_visible_now_publications`) | **`can_remove true`** (antes do lote 82 seria `false`: autoria exigida) | — |
| Sem capacidade (`qa-r15-responsavel`) | feed dela não mostra a story de equipe (só a de Famílias `d9580375`, `can_remove false`); `remove_now_publication(fcfe2865)` → **403 `42501` now_permission_denied**; id inexistente → 403 `now_remove_denied` | — |
| Não autora remove (`remove_now_publication` como `qa-r06-publicacoes`, `p_expected_version 3`) | **200 `removed`** (`management_version 4`, `purge_status queued`); feed dela → `[]` | — |
| Viewer da autora após a remoção | story ausente (viewer vazio) | `agora-04-removida.png` |

Resíduo observado (sem action_id, para a revisão de telas): no 2º Chrome (perfil novo, CDP 9415) logado como
`qa-r06-publicacoes`, a faixa "Agora" da Home e `/principal-now` não mostraram a story (redirect para
`/principal-happens`) enquanto a mesma sessão do navegador, chamando `list_visible_now_publications` por `fetch` com
`p_institution_id = d0c40000…`, recebia a story; com `9f040000…` recebia `[]`. Hipótese: o shell escolhe por padrão o
contexto "QA R04 Instituicao Sintetica" para essa identidade (o seletor "Coelo ›" não respondeu ao clique por
coordenada). Não é a projeção `can_remove`; fica anotado no handoff.

**Resultado:** dívida `can-remove` → concluída (feed segue a RPC, em produção). Nenhum `action_id` muda. Massa: story
`fcfe2865` removida (purge enfileirado); asset `15b914e7` segue o ciclo de purga do Agora.
