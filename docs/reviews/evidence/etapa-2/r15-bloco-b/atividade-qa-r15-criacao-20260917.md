---
source: "Sessão B da R15 (Fable 5.1), 17/09/2026; spec 2026-08-31 activities-cross-app-backend-v2 (participação por turma); R14 Sessão A (d5f8bbe70, p_publish liberado no cliente)"
status: evidence
lifecycle: current
generated_at: 2026-09-17
action_id: "activities.create"
---

# Atividades › Criar atividade — `ACTIVITY_INVALID_REFERENCE` na rota real: dois defeitos de FE corrigidos, atividade "QA R15 Atividade Assiduidade" criada e publicada pela tela (17/09/2026)

Ambiente: produção; build QA `r15/bloco-b` em `127.0.0.1:3015`, Chrome CDP 9435, sessão `qa-r06-operacoes@coelo.me`
(Owner interno). Corpo das RPCs capturado por CDP (`Network.getResponseBody`), estado relido por `supabase db query
--linked` (leitura). Diagnóstico por reprodução **com rollback** em produção (`begin … rollback`, ator = sessão real
de `qa-r06-operacoes`, sub-comandos `superadmin_activity_*_v2` chamados um a um). Capturas em
`capturas/activities-create-qa-r15-*.png`.

## 1. Sintoma

Assistente `/activities/new` completo (Identidade, Estrutura QA R04 Cuidado › Unidade QA R04, Vínculos › Turma
`368a5cea…` com participação **"Toda a turma"**, sem profissionais) → **"Criar atividade"** → painel "Não foi possível
salvar a atividade. Confira a conexão…". Corpo real: `superadmin_activity_save_v2` respondeu
`{"ok":false,"error":{"code":"ACTIVITY_INVALID_REFERENCE","http_status":422}}` com todos os catálogos ativos
(taxonomia `202f640e…` `artes-cultura`, unidade, turma, 8 capacidades ativas, participante válido pelo validador).

## 2. Diagnóstico (reprodução com rollback, passo a passo)

| Passo | Resultado |
|---|---|
| `create_v2` → `set_units_v2` → `set_groups_v2` (`{"368a5cea…":"all"}`) | ok, v1 → v3 |
| `set_participants_v2` com `[{"group_id":"368a5cea…","child_group_link_id":"8d766ca8…","belongs":true}]` | **`ACTIVITY_INVALID_REFERENCE`** |
| idem com `participants: []` | ok; `set_professionals`, `set_permissions`, `publish` → `active` v7 |

Causa: a RPC exige `activity_group_links.participation_mode='selected'` para qualquer participante explícito
(`belongs=true`); a spec é explícita ("Groups `all` não aceitam entradas"). O assistente marca todos os alunos como
"Pertence" e o roteador enviava **toda** a seleção mesmo com a turma em modo `all` → o snapshot inteiro era
recusado. Nada no backend a corrigir.

## 3. Correções no FE (`apps/superadmin`, testes 50/50)

1. `supabase_activity_command_repository.dart` — `_activitySavePayload` só envia `participants` de turmas em modo
   `selected` (teste "sends explicit participants only for groups in selected mode").
2. Mesmo arquivo — a validação da resposta recusava `status: active` na criação; com **"Criar atividade"**
   (`p_publish: true`, liberado na R14) o servidor cria **e publica** e a tela mostrava o painel de erro apesar do
   sucesso (segunda tentativa desta sessão: `ok:true`, `status: active`, v6, e o painel apareceu). Agora a criação com
   publicar aceita `active` e a criação de rascunho continua exigindo `draft` (2 testes novos). **Não reconstruído para
   a web nesta sessão** — a prova de tela abaixo usa o build com a correção 1; a correção 2 fica local-green.
3. Achado registrado (não corrigido): `_mapEnvelopeError` mapeia `ACTIVITY_INVALID_REFERENCE`/`INVALID_INPUT` (422)
   para "Confira a conexão" — mensagem desonesta para erro de dados; e o gate `_supportsAggregateSave` sem sigla
   mostra a mesma mensagem sem chamada de rede.

## 4. Rota real após a correção 1

| Passo | Resultado |
|---|---|
| Assistente idêntico (captura 00: Vínculos "Toda a turma"; 01: Revisão) → **Criar atividade** | request `participants: []`, `group_participation {"368a5cea…":"all"}`, `p_publish true` → **`ok:true`**, `activity_id 1bd6bc74-d0bd-4a9b-af89-7c51347d18c0`, `status active`, `management_version 6` |
| Produção (leitura) | `activity_definitions` `1bd6bc74…` "QA R15 Atividade Assiduidade" `active` v6, taxonomia `202f640e…`; `activity_unit_links` unidade `d0c4…0002` active; `activity_group_links` `227563b6…` turma `368a5cea…` `mode=all` active |
| Tela | painel de erro apesar do sucesso (defeito 2, captura 02) — corrigido no código, não reconstruído |

## Separação FE / BE / E2E

`activities.create` já era verified-e2e (R14) para rascunho; esta evidência **não altera estado** de tracker: registra
dois defeitos de FE corrigidos (local-green) e a massa "QA R15 Atividade Assiduidade" em produção, insumo de
`owner.r12-05` (contexto Atividade na chamada).
