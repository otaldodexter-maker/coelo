---
source: "Sessão 1 da R14 (Opus 5), 15/09/2026; R14-execucao-paralela.md; owner.r12-03"
status: evidence
generated_at: 2026-09-15
---

# Atividades › Diretório (`activities.list`, owner.r12-03) e Atividade › Publicar (`activities.publish`) — rota real, 15/09/2026

Mesmo ambiente de `circulars-attach-20260915.md` (produção, build QA de `r14/bloco-ab` em `8b99d9a06` + esta correção,
127.0.0.1:3014, CDP 9414, sessão `qa-r06-publicacoes`, Owner de plataforma). Capturas em
`capturas/activities-list-*.png` e `capturas/activities-publish-*.png`.

## Defeito encontrado e corrigido (teste vermelho → verde)

O passo final do formulário de edição ("Salvar alterações") envia o intent `publish`, mas
`SupabaseActivityCommandRepository._supportsAggregateSave` exigia `saveDraft` e devolvia
`ActivityCommandUnavailableException` antes do HTTP — publicar pela tela era impossível em produção (pendência
R05). Correção mínima: o cliente deixa de decidir por status e envia `p_publish=true` a
`superadmin_activity_save_v2`; quem recusa uma atividade fora de `draft` é `superadmin_activity_publish_v2`
(provado abaixo com `ACTIVITY_INVALID_STATE`). Teste novo "publishes a draft through the aggregate v2 RPC
with p_publish true" (vermelho: `ActivityCommandUnavailableException`; verde depois); os dois testes que
afirmavam "publish falha fechado antes do HTTP" foram ajustados ao novo contrato; suíte 47/47;
`flutter analyze` limpo; reprova no build corrigido.

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| activities.list | `/activities`: abas "Modelos de atividade" (busca de modelo, Origem, Todos/Ativos/Rascunhos/Inativos — 01-modelos) e "Atividades" (busca, filtros Instituições/Unidades/Turmas/Origem, cards/tabela, status, paginação 11 por página — 02). "Rascunhos" + modo tabela (menu Agrupado/Por Unidades/Por Turmas) + busca "Arroba" → 1 linha "Atividade R06 Arroba · Escola R04 Estrutura · 1 · 1 · Instituição" com "Limpar filtros" (03). | leitura: `superadmin_activity_directory_v2` (filtros `statuses=[draft]`, `search`), `superadmin_activity_filter_options_v2`, `superadmin_activity_template_options`. | Carga completa de `/activities` relê o diretório (04). | escopo por pgTAP já certificado no BE; `superadmin_activity_detail_v2` de id inexistente → `ACTIVITY_NOT_FOUND` 404 (não enumerável). |
| activities.publish | `/activities/085da87e…/edit` › "Profissionais e revisão" (Revisão: Escola R04 Estrutura, 1 unidade, 1 turma — publish-01) → "Salvar alterações" → detalhe "Visualizar atividade" com Status **Ativa**, atualização 15/09/2026 10:33 (publish-02). | `superadmin_activity_save_v2` `p_publish=true` → `superadmin_activity_publish_v2`: "Atividade R06 Arroba" `085da87e-438f-4625-88d7-764d0d1bb4ad` `draft` (v5) → `active` (`management_version 12`) relida por `superadmin_activity_directory_v2`. | Carga completa de `/activities/085da87e…` relê Ativa (publish-03). | `superadmin_activity_publish_v2` na atividade já ativa com a versão corrente (12) → `409 ACTIVITY_INVALID_STATE`; com versão obsoleta → `409 SAI_CONCURRENT_CHANGE`; detalhe de id inexistente → `404 ACTIVITY_NOT_FOUND`. |

Observações: a atividade `085da87e` passa a `active` em produção (massa sintética da Escola R04 Estrutura); não
há mais rascunho com unidade+turma vinculadas para nova publicação sem criar outra atividade. Nenhuma mudança de
rótulo ou layout; `owner.r12-03` (abas/filtros/modos/paginação/reload/negativa) fica concluído por esta prova.
