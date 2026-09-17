---
source: "Sessão B da R15 (Fable 5.1), 17/09/2026; ADR 0041 D4; ADR 0042 E1 (lote 75); R14 Sessão 8 (child-safety-lifecycle-504); r14-sessao-1/child-safety-child-20260915.md; owner.r12-13/15/16"
status: evidence
lifecycle: current
generated_at: 2026-09-17
action_id: "child-safety.edit, child-safety.suspend, child-safety.create"
---

# Segurança da criança › criar, editar, aprovar e suspender pela tela (`child-safety.create/edit/suspend`; owner.r12-13/15/16) — rota real, 17/09/2026

Ambiente: produção, build QA de `r15/bloco-b` (`bcf47d636` + correção FE abaixo) em `127.0.0.1:3015`,
Chrome CDP 9415, sessão `qa-r06-acessos@coelo.me` (Owner de plataforma). Criança sintética "Crianca QA R04"
(`d0c40000-…0003`), contexto QA R04 Cuidado › Unidade QA R04 (`child_context d0c40000-…0004`). Pessoa
autorizada: "QA R04 Profissional" (`9f040000-…0061`, adulto ativo). Negativas por PostgREST
(`scratchpad/rpc.mjs`, mesma sessão, sem chave de serviço); releituras por `supabase db query --linked`
(leitura). Capturas em `capturas/child-safety-*.png`. Autorização criada: **`3f3650b0-9738-4014-b183-7ec18fd13a81`**.

| action_id | Rota normal | Escrita em produção | Reload | Negativa |
|---|---|---|---|---|
| child-safety.create (já verified-e2e; reexercitado) | `/safety/new`: Criança (busca server-side "Crianca" → 2 contextos, escolhido QA R04 Cuidado · Unidade QA R04) → Pessoa autorizada (UUID `9f04…0061`, motivo, Relação "Outros" + detalhe "Tio sintetico QA R15") → Validade e capacidades (Retirada) → Revisão → "Enviar para aprovação" (01–04) | `child_safety_request_authorization` → `3f3650b0…` `pending`/`inactive`, versão 1, 14:21:27 UTC | diretório volta com "Aguardando aprovação (1)" e o card do contexto com 3 autorizações (04) | pessoa em `draft` (`da915f98…`, responsável QA R15) → `500 P0002 child safety record unavailable` (a RPC exige adulto `active`); relação `grandparent` → `400 22023 invalid relationship` (ver defeito FE abaixo) |
| child-safety.edit | `/safety/children/d0c4…0003` › Gerenciar (estado pendente: Aprovar/Rejeitar/Editar/Concluir, 05) › Editar → `/safety/children/…/authorizations/3f3650b0…/edit` com criança pré-selecionada (06) → motivo "R15 Bloco B motivo editado pela tela" → capacidades + Contato de emergência (07) → Revisão → salvar | `child_safety_edit_pending_authorization` → versão **2**, `request_reason` relido, capacidades `pickup, emergency_contact` (08) | `db query`: versão 2, `pending`; diálogo relê "Capacidades: Contato de emergência, Retirada" e o motivo editado (10) | `child_safety_edit_pending_authorization` com `p_expected_version 99` → **409 `PT409` CHILD_SAFETY_STALE_VERSION** em 1,4 s (sem 504); versão permanece 2 |
| child-safety.suspend | Gerenciar › **Aprovar** (estado pendente) → linha "Aprovado · Ativa" (09); Gerenciar (estado aprovado-ativo: Situação Ativa, "Suspender autorização", Concluir; 10) → "Suspender autorização?" (11) → Suspender → linha "Aprovado · Suspensa" (12) | `child_safety_decide_authorization` → versão **3** `approved/active`; `child_safety_change_lifecycle(suspended)` → versão **4** `approved/suspended` | carga completa de `/safety/children/d0c4…0003` relê "QA R04 Profissional · Tio sintetico QA R15 · Aprovado · Suspensa" (13) | `child_safety_decide_authorization` v99 → **409 `PT409`** (0,14 s); `child_safety_change_lifecycle` v99 → **409 `PT409`** (0,11 s); id inexistente/alheio → `500 P0002 child safety record unavailable`; versão permanece 4 (sem mutação) |

Owner items:

- **r12-13** (wizard Criar/Editar na rota normal, escopo e reload): criar e editar percorridos pela rota normal
  com escopo real (busca server-side restrita ao escopo; contexto correto na revisão), persistência e reload —
  **done**.
- **r12-15** (diálogo Gerenciar por estado): estados **pendente** (05: Aprovar/Rejeitar/Editar/Concluir),
  **aprovado-ativo** (10: Situação Ativa, Suspender, Concluir) e **suspenso** (já provado 15/09; 12/13) — **done**.
  Observação de composição (sem alteração): o diálogo mostra "Contexto: Escola R04 Estrutura · Unidade Centro
  R04" (cabeçalho da criança, primeiro contexto) para uma autorização que pertence a QA R04 Cuidado · Unidade
  QA R04 — a tabela e a revisão do wizard mostram o contexto certo.
- **r12-16** (stepper sem salto): em `/safety/new`, clicar "Revisão" na etapa 1 não avança (14); voltar de
  Revisão para "Pessoa autorizada" preserva os dados (feito durante a criação) — **done**.

## Defeito FE encontrado e corrigido (local-green)

A opção "Avó/Avô" do wizard enviava `relationship_code='grandparent'`, inexistente em
`family_relationship_types` (produção: `grandmother`/`grandfather`); a RPC recusa com `22023 invalid
relationship` e a tela mostra "Revise os dados da autorização." sem indicar o campo. Correção em
`safety_pages.dart`: opções `grandmother` ("Avó") e `grandfather` ("Avô") no seletor, no normalizador
`_relationshipCode` e no rótulo `_relationshipLabel`. Teste: `flutter test test/features/safety` (resultado na
seção abaixo). Não provado na rota real (o build QA desta sessão é anterior à correção); "Outros" foi usado
na prova.

## Observações

- A busca de crianças do wizard não lista as crianças `QA R15` (vínculo de unidade `pending`); a massa E2 só
  entra em Segurança da criança depois do aceite do vínculo (AP-1/B′).
- A pessoa autorizada precisa ser adulto `active`: adultos criados por Pessoas nascem `draft` e não servem
  para autorização até a ativação (também na fixture de B′).

## Separação FE / BE / E2E

- FE: rota normal de create/edit/suspend percorrida em produção; correção de catálogo (Avó/Avô) local-green.
- BE: RPCs `request/edit_pending/decide/change_lifecycle` em produção, versões 1→2→3→4, PT409 em < 1,5 s
  (lote 74 + 75), P0002 para id alheio/inexistente.
- E2E: `child-safety.edit` e `child-safety.suspend` → verified-e2e; `child-safety.create` permanece verified-e2e.
