---
title: "Handoff — R06 · Estrutura (E2-R06-20260911)"
source: "comunicacao/estrutura.json revs 54–57; deltas-r06-estrutura.json; capturas em rota-real/"
status: "entregue ao coordenador em 11/09/2026 21:0x"
generated_at: "2026-09-11"
---

# R06 · Estrutura — handoff

Branch `work/etapa2-r06-estrutura` (base `origin/dev` ca60b096b, merge de
fcdded416 / lote 49). Só o coordenador escreve em `dev`, inventário e
rastreadores; os deltas estão em `deltas-r06-estrutura.json` (16 entradas,
ensaio `apply-tracker-delta.cjs` + `validate-trackers.cjs` PASS, revertido).
Usuário sintético da rodada: `qa-r06-estrutura@coelo.me` (Chrome próprio,
CDP 9571; login e taps pelo Flutter Driver web exposto por `qa_main`).

## Item 1 — regra do @ no cliente (fechado)

| Tela | O que o cliente faz agora | Prova na rota real |
| --- | --- | --- |
| Unidades | Identificador = @ (regex do @, sem hífen; valor legado tolerado), `handle` no payload de `create_unit_for_superadmin`, "Alterar @" por `superadmin_structure_handle_set_v1` | `units-handle-*.jpg`: @ atual, troca para `@centro.r04estrutura`, segunda troca negada com "O @ só pode ser alterado uma vez a cada 30 dias.", reload mantém |
| Turmas | campo Identificador (@) novo na etapa Identidade com disponibilidade enquanto digita, `handle` no payload de `superadmin_group_save` (criação), "Alterar @" | `groups-create-handle-*.jpg` (Turma R06 Arroba criada com `@arroba.centro.r06`), `groups-handle-alterado.jpg` (→ `@arroba.r06.centro`), `groups-handle-reload.jpg` |
| Atividades | `definition.handle` só na criação (precisa do pacote abaixo), "Alterar @" no controller/seção | `activities-handle-alterado.jpg` (→ `@estrutura-r06`) |

Commits: `0434548b9` (cliente, 179/179 em `test/features/units`; analyze limpo),
`9c14eddeb` (candidato SQL), `102a80b58` e seguintes (docs).

## Pacote SQL pronto

`candidatos/estrutura/20260912180000_structure_handles_client_v1.sql`:
`superadmin_activity_save_v2` aceita `definition.handle` na criação
(repassa ao `create_v2` do lote 211100) e recusa troca na edição com
`ACTIVITY_INVALID_INPUT` (a lista fechada de `activity_v2_normalize_error`
não deixa passar `SAI_HANDLE_USE_SET`); `group_management_payload` devolve
`handle` e `handle_last_changed_at`. pgTAP
`structure_handles_client_v1_test` 9/9; regressão `save_v2` 46/46, 211100
18/18, handles 24/24, `internal_group_detail` 33/33 no espelho
`coelo_estrutura_r06` (baseline + 197 lotes da ordem real). Sem `ALTER
TYPE`; sem chave de composição a ligar.

## Item 2 — parcial

`units.list` e `groups.list` provados na rota real com o usuário da rodada
(deltas BE done + E2E). `groups.members`, `groups.location`, `units.error`
e `units.access-denied` não alcançados.

## Item 3 — Avaliações: gate encontrado, sem pacote

Não é vínculo profissional: `superadmin_assessment_context_options` lista
os `activity_group_links` ativos de atividades ativas, e o Owner de
plataforma já vê "Escola R04 Estrutura · Unidade Centro R04 · Turma R05
Estrutura · Atividade R05 Estrutura" em `/assessments/entry`. O gate é
**"Nenhum período avaliativo"**: períodos nascem só de
`superadmin_assessment_save_configuration` + `activate_configuration`
(`activities.assessment`). Pela tela: (a) "Salvar rascunho" do assistente
com avaliação habilitada falha antes do HTTP (`_supportsAggregateSave`
exige `enabled=false`) com a mensagem enganosa "Confira a conexão"; (b) a
rota própria `/activities/:id/assessment-settings?institutionId=…` abre
"Não foi possível carregar" (envelope de `configuration_read` a inspecionar).
Próximo passo concreto: corrigir (b) e provar salvar + ativar; só então
`assessments.entry/gradebook/close/reopen/detail`.

## Item 5 — goldens de `activity_golden_test` (analisados, não regravados)

31 imagens em 9 testes. Diretório (cards/tabela/hover/filtro/paginação/tour/
bug/perfil, claro e escuro, 375–1440): a única diferença é a pílula do chat
("Mens." truncado na referência vs "Mensagens" inteiro no atual); regravar
quando o coordenador confirmar que o launcher atual é o aprovado. Formulários
e detalhe em 375: cabeçalho mobile (hambúrguer vs breadcrumb "Coelo") — MENU-M
retido —, ausência do balão (Decisão 7) e etapas "1 de 4" → "1 de 6";
ficam retidos. Nada regravado nesta rodada.

## Item 6 — não iniciado

`institutions.status/files/error/access-denied`.

## Pendências de code review e segurança

- Campo "@ da atividade" abre vazio na edição: o mapeamento do `detail_v2`
  no cliente não expõe `handle_stem` (Alterar @ funciona mesmo assim).
- Taps do Flutter Driver web falham de forma intermitente em botões logo
  depois de digitar; clique por coordenada via CDP resolve.
- **Credencial exposta:** às 20:10 o `enter_text` do driver digitou a senha
  de `qa-r06-estrutura` no campo de e-mail (o tap na senha não tinha
  mudado o foco) e ela apareceu numa captura temporária, apagada e não
  versionada. Rotacionar a senha desse usuário no fim da rodada (painel
  Supabase → Authentication → Users → reset password, ou Admin API) e
  regravar só em `Coelo-backups/qa-r06-estrutura.env`.

## Dados sintéticos em produção (P42: ficam até o fim da Etapa 2)

`groups` ea3986b7 (Turma R06 Arroba, `@arroba.r06.centro`, Escola R04
Estrutura / Unidade Centro R04); `units` f5284f2f com `handle` →
`centro.r04estrutura`; `activity_definitions` 95b98978 com `handle_stem` →
`estrutura-r06`. Nenhuma chave ou segredo criado.
