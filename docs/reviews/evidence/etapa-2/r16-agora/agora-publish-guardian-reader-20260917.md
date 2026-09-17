---
source: "Sessão AGORA da R16 (Fable 5.1, coelo-5a), 17/09/2026; ADR 0044 (agora.publish executar na R16; oq048-membership); OQ-048; spec 070; R15-handoff-bloco-b.md AP-2; r15-bloco-b/agora-publish-20260917.md; autorização nominal do Owner em R16-execucao.md (17/09 ~20:35 BRT)"
status: evidence
lifecycle: current
generated_at: 2026-09-17
action_id: "agora.publish"
---

# Agora › Publicar para Famílias (`agora.publish`) — leitor reconhece o responsável (lote 81), leitura provada em produção (17/09/2026)

Ambiente: produção (`evvbomzejfijozbtgvpt`). Escrita em produção só pelo rito (lote 81). Leituras por PostgREST e pela
Edge `now-media` com a **sessão de cada identidade** (`scripts/r13-rpc-proof.mjs` e um script equivalente no scratchpad,
sem chave de serviço); metadados por `supabase db query --linked` (leitura). Nenhuma credencial, token ou URL assinada
neste documento (tickets redigidos).

## 1. Contexto e causa (R15 → R16)

A story de Famílias `d9580375-c81e-4e8a-8086-85e4eef09186` foi publicada na R15 como `qa-r06-publicacoes` (audiência
`families`, institucional: `unit_id`/`group_id` nulos, `published` v2, 1 mídia `ready`, vigente até 18/09 18:34 UTC —
metadados relidos hoje). A responsável `da915f98…` (conta `qa-r15-responsavel@coelo.me`, `guardian_links` +
`guardian_context_permissions.can_view` para 2 crianças, **sem** membership) recebia `403 42501 now_permission_denied`
porque `app_private.now_actor` exigia `has_institution_permission(inst,'now.publications.read')` e membership ativa antes
de `now_viewer_role_class`. Decisão do Owner (ADR 0044): corrigir o contrato; sem override/membership para a massa.

## 2. Contrato (spec 070) e migration `20260917203000_now_guardian_reader_v1`

- `app_private.now_reader_actor(uuid,text,uuid,uuid)` — função irmã de `now_actor` **só para leitura**: mesma validação
  de contexto; equipe como antes (permissão + membership ativa); sem permissão institucional, caminho de responsável
  (`now_viewer_role_class(pessoa, null, inst, unit, group) = 'guardian'`, isto é, `guardian_links` ativo +
  `child_contexts` ativo na instituição + `can_view` vigente + vínculo de unidade/turma quando o contexto é pedido)
  → `(person_id, membership_id null)`. Sem grant a `anon`/`authenticated`/`service_role`.
- `public.list_visible_now_publications` — mesma assinatura, projeção (lote 79) e grants; ator por `now_reader_actor`
  com `'now.publications.read'`; classificação por `now_viewer_role_class`; `can_remove` continua exigindo permissão + autoria.
- `public.redeem_now_media_read_ticket` — mesma assinatura e grants (`service_role`); a membership deixa de ser junção
  obrigatória (resolve a membership ativa, nula para o responsável); ticket único, vinculado ao visitante autenticado,
  revalidando vigência e audiência.
- `app_private.now_actor` (criar, publicar, remover, mídia de autor) **inalterado**. Sem versão otimista (nada a sinalizar
  com PT409). Candidato `20260917113000_qa_r15_guardian_membership_v1` **não aplicado** (segue só local no `migration list`).

## 3. Espelho e pgTAP (antes do rito)

Espelho `coelo_mirror_r16_agora` (`Coelo-backups/mirror-r16-agora`, portas 626xx) restaurado do dump novo de produção
`schema-producao-20260917-r16-agora-before.sql` (SHA-256 `0c6c646850c4ef8165cd7026b88e00637f1d3885831d034ddbff1930426f1d65`,
funções do Agora idênticas ao dump `lote80-before`) com a receita fiel de B′ (`restaurar-espelho.sh`: 0 erros, `anon`
executa 0 funções em `public`, catálogo completo). Pessoa técnica `Coelo Sistema` semeada no espelho (linha de referência
que existe em produção; sem ela as suítes que não a semeiam abortam por FK de `follow_links`). Migration aplicada 2× sem erro
(idempotente).

| Suíte | Linha de base (antes) | Depois da migration |
|---|---|---|
| `now_guardian_reader_v1_test` (nova) | — | **21/21** |
| `now_publication_removal_test` | 18/18 executados (plano 19) | 18/18 executados (plano 19), idêntico |
| `now_feed_removal_projection_v1_test` | 9/9 | 9/9 |
| `happens_post_withdrawal_test` | 33/33 | 33/33 |
| `now_publication_mvp_test` | 67/70 (falham 18, 19, 52 — pré-existentes) | 67/70, as mesmas |
| `now_custom_role_audience_hardening_test` | 13/13 | 13/13 |
| `now_media_private_r2_v1_test` | 21/23 (falham 16, 17 — pré-existentes) | 21/23, as mesmas |
| `now_publication_removal_cross_tenant_test` | 6/6 | 6/6 |
| `principal_internal_actor_bridge_v1_test` | 8 ok / 2 falhas (7, 9) + abort — pré-existentes | idêntico |

Cenários da suíte nova: responsável com vínculo vê só a story de Famílias vigente (equipe, expirada e removida ausentes),
`can_remove` false, ticket emitido; sem vínculo na unidade pedida → 42501; cross-tenant (A→B e B→A) → 42501; sem vínculo
algum → 42501; responsável de B lê B (`[]`); equipe continua lendo e não vê Famílias; ticket do responsável resgatado sem
membership, de uso único e preso ao visitante; `now_actor` nega `now.publications.create` ao responsável; leitura não muta a
versão. Logs: `Coelo-backups/mirror-r16-agora/pgtap-baseline.log` e `pgtap-pos-migration.log`.

## 4. Rito em produção — lote 81

| Passo | Resultado |
|---|---|
| Dump prévio | `Coelo-backups/schema-producao-20260917-r16-agora-before.sql`, SHA-256 `0c6c6468…` |
| `Sync-SupabaseCliMigrations.ps1 -Mode Clean` | OK (o `-Mode Prepare` falha por drift pré-existente do espelho do CLI — 17 cópias rastreadas + 205 canônicas = 222 ≠ 205 — mas já copia a migration antes da contagem; item `espelho-cli` da R16) |
| `supabase db query --linked --workdir packages/coelo_database -f migrations/20260917203000_now_guardian_reader_v1.sql` | 23:33:53–23:33:58 UTC, `rows: []`, sem erro |
| Pós-verificação (D1) | `app_private.now_reader_actor` sem execute a `anon`/`authenticated`; `list_visible_now_publications` usa `now_reader_actor` (execute a `authenticated`, não a `anon`); `redeem_now_media_read_ticket` sem execute a `authenticated`; `app_private.now_actor` intacto |
| `supabase migration repair --status applied 20260917203000 --linked` | `Repaired migration history: [20260917203000] => applied` |
| `supabase migration list --linked` | `20260917203000` local+remoto; `20260917113000` só local (não aplicada) |
| Ledger | lote 81 em `packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt` |

Classificador: um comando combinado (verificação + repair + list numa só chamada PowerShell) foi negado; cada passo,
executado separadamente e nomeado, foi permitido. Nada contornado. Autorização nominal do Owner registrada em
`R16-execucao.md` ("Autorizações do Owner durante a execução", item 1).

## 5. Prova E2E em produção (leitura pelo responsável, 23:39–23:41 UTC)

Publicação reutilizada: `d9580375…` (vigente; publicada pela tela/contrato na R14/R15 como `qa-r06-publicacoes`).

| Passo | Identidade | Resultado |
|---|---|---|
| `list_visible_now_publications('d0c40000-…0001', null, null, 20)` | `qa-r15-responsavel` | **200** `[d9580375…]` — caption "QA R15 Agora para Familias", `management_version 2`, `can_remove false`, `media` com 1 ticket (`image/png`) — 115 ms |
| Segunda chamada (reload) | idem | **200**, mesma story (estável) |
| Edge `now-media` `action: read` com o ticket do feed | idem | **200** `{signed_url: <presente>, mime_type: image/png, expires_in: 60}` — 648 ms |
| Mesmo ticket, segunda vez | idem | **403** `media_read_denied` (ticket de uso único) |
| `list_visible_now_publications('9f040000-…0010', …)` (outra instituição real, ativa) | idem | **403** `{"code":"42501","message":"now_permission_denied"}` |
| `list_visible_now_publications('c2300000-…00aa', …)` (instituição inexistente) | idem | **403** `42501 now_permission_denied` |
| `list_visible_now_publications('d0c40000-…0001', null, null, 20)` | `qa-r06-principal` (equipe) | **200** `[]` — a story de Famílias não aparece para equipe (isolamento de audiência) |

Antes do lote 81 a mesma chamada da responsável devolvia `403 42501 now_permission_denied` (evidência R15
`agora-publish-20260917.md` §2). Nenhuma membership, override ou dado de massa foi criado ou alterado nesta sessão;
`recipients` de cuidado não tocados.

Tela: não capturada — o Principal hospedado exige identidade interna com contexto (OQ-048, `list_my_principal_contexts`
com join em membership; shell `SAI_INTERNAL_CONTEXT_DENIED`), logo a conta só-responsável não abre tela nenhuma; a prova
por PostgREST/Edge com a sessão da responsável é a rota prevista no Prompt 2 (captura opcional).

## Separação FE / BE / E2E

- FE: **verified** (mantido — publicação pela tela, R14; nada alterado nesta sessão).
- BE: **done** — delta: lote 81 (`now_reader_actor`, feed e resgate de ticket reconhecem o responsável por vínculo);
  pgTAP 21/21 + suítes do Agora sem regressão; leitura da responsável em produção 200.
- E2E: **verified-e2e** — publicação de Famílias vigente em produção lida pela responsável com a própria sessão (feed +
  mídia), reload estável, negativas cross-tenant 42501 e isolamento de audiência (equipe `[]`).
