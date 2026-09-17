---
source: "Sessão B da R15 (Fable 5.1), 17/09/2026; ADR 0037; ADR 0040; R14 (agora.create/publish pela tela); AP-1/AP-2 de B′; decisão da coordenadora 17/09 (bloqueio por contrato → OQ-048)"
status: evidence
lifecycle: current
generated_at: 2026-09-17
action_id: "agora.publish"
---

# Agora › Publicar para Famílias (`agora.publish`) — massa completa, publicação provada, leitura pela responsável recusada pelo contrato (17/09/2026)

Ambiente: produção. Publicação pelo **contrato** (`save_now_draft` → `now-media` prepare → `PUT` R2 → finalize →
`publish_now`, `scratchpad/now-publish.mjs`, PNG 64×64 sintético) como `qa-r06-publicacoes@coelo.me`; a publicação
**pela tela** já é verified (R14, `agora.create`/`agora.publish` FE) e não foi repetida nesta sessão. Leituras por
PostgREST com a sessão de cada identidade (`rpc.mjs`, sem chave de serviço); estado por `supabase db query --linked`.

## 1. Massa (fatia 2 + AP-1, lote 80)

Responsável `da915f98-bfad-49f6-9914-fe57a30584c9` ativa com conta `qa-r15-responsavel@coelo.me`
(`ff3682a1-78bb-4fcd-bb89-fb542bfb7f3c`), `guardian_links` e `guardian_context_permissions` para as crianças
`93457405…` (contexto `1a6158fe…`) e `14d70a25…` (contexto `519ef941…`), ambas com `child_unit_links` ativos na turma
`368a5cea…` (JSON completo em `massa-qa-r15-20260917.md`). A responsável **não** tem `institution_memberships`.

## 2. Publicação e leituras

| Passo | Resultado |
|---|---|
| `publish_now` de story com audiência **`families`** ("QA R15 Agora para Familias") | `d9580375-c81e-4e8a-8086-85e4eef09186` `published`, `publish_at 2026-09-17 18:34:23 UTC`, `expires_at 2026-09-18 18:34:23 UTC`; asset `f8b62158…` em R2 |
| Leitura pela responsável: `list_visible_now_publications('d0c40000-…0001', null, null, 20)` | **`403 {"code":"42501","details":null,"hint":null,"message":"now_permission_denied"}`** (187 ms) |
| Segunda leitura (reload) | idem `403 now_permission_denied` (58 ms) |
| Leitura por `qa-r06-principal` (equipe/Owner interno) | `200 []` — a story de Famílias **não** aparece para equipe (isolamento de audiência correto) |

## 3. Causa — contrato, não massa (registrada como OQ-048 pela coordenadora)

`app_private.now_actor(p_institution_id, 'now.publications.read', …)` exige
`app_private.has_institution_permission(...)` (permissão via `institution_role_assignments`/overrides, só papéis
de equipe) e depois uma linha ativa em `institution_memberships` (`active_membership_required`);
`now_viewer_role_class` (que responderia `guardian`) nunca é alcançado. B′ confirmou no espelho que nem uma membership
`guardian` libera o feed, e conceder override só à massa mascararia o defeito para responsáveis reais. Portanto
**nenhum responsável "puro" (só `guardian_links`) lê o Agora hoje**, mesmo com audiência `families`. Decisão da
coordenadora (17/09): `agora.publish` fica **bloqueado por contrato (RPC)**; a correção (`now_actor` reconhecer
`guardian_links` ativos) entra na R16 via OQ-048. Complemento (Sessão A, ADR 0037): o Principal hospedado só abre por
identidade interna com contexto; a conta só-responsável não entra em tela nenhuma — a leitura pela tela seria
inviável de qualquer modo nesta rodada.

## Separação FE / BE / E2E

- FE: **verified** (mantido — publicação pela tela R14; nada alterado nesta sessão).
- BE: **done** (contrato de publicação exercitado em produção com audiência Famílias; PT409 no lote 75).
- E2E: **pending-verification** — bloqueio por contrato (leitura da responsável `42501 now_permission_denied`),
  massa completa e registrada; reabrir após OQ-048.
