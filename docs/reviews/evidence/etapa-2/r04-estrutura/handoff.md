---
title: "Handoff — grupo estrutura, Rodada 4 (E2-R04-20260911)"
source: "worktree e2-r04-estrutura, branch work/etapa2-r04-estrutura; comunicacao/estrutura.json revisões 23 a 28"
status: "finalizado; mini-revisão gravada às 08:4x de 11/09 (a sessão caiu com a máquina às 00:27 e a rev 31 não foi publicada)"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Handoff — grupo estrutura (R04)

**Base:** `origin/dev 836c63215` (rebaseada), com a baseline de produção e os
lotes 1 a 8 em `migrations/`. Árvore limpa a cada commit; nenhum WIP retido.

## Feito

**Cadeia de Locais e de Atividades v2 sobre a baseline.** O que o coordenador
viu como "fixture ausente" era a cadeia inteira de Atividades v2 ausente em
produção (onze migrations históricas, 0 objetos presentes). Recarimbei tudo em
`candidatos/estrutura/` (180000 reservas, 180020..180120 Atividades v2, 180140
bindings, 180150 activity_location_create, 180200 group_location_create, 180300
unit_detail, 180310 group_detail) com a assinatura real de
`audit_append_superadmin_internal` (13 argumentos) e as fixtures na forma de
produção (`unit_type_id`, `handle`, `inherit_plan`). Prova integral em espelho
novo (baseline + seed + 46 lotes por psql + candidatos na ordem): todos aplicam
e 18 suítes ficam verdes (645 asserções). O mapa de qual suíte roda depois de
qual migration está em `estrutura.json.provaIntegral`.

**Instituições no realm interno v2.** `superadmin_institution_detail_v2`
(180330, 25/25) e o novo `superadmin_institution_create_v2` (180340, 26/26):
capacidade `institution.activate`, escopo de plataforma, validador ROOT+ADDRESS
do edit_core reutilizado, handle pelo trigger, sempre `draft`, recibo por
`request_id`, auditoria interna. O cliente cria por ele e recarrega o detalhe.
Catálogo mínimo de tipos (180320), porque produção tem zero
`institution_types`.

**Avaliações.** Nenhum objeto `superadmin_assessment_*` existe em produção e a
migration histórica nunca aplicou em lugar nenhum (parêntese a menos em
`superadmin_assessment_context_options`; ambiguidade variável × coluna em
`assessment_v2_save_configuration`). Recarimbada como 180350 com as duas
correções, pgTAP 47/47; a suíte usa o marcador interno da cadeia de Atividades
v2 e vem depois de 180120. Chave do cliente: `COELO_ENABLE_ASSESSMENT_MUTATIONS`.

**Cliente.** P5 (filtros de Turmas degradam de forma honesta, com teste), P6
(widget morto do diálogo de importar removido; o botão já era honesto), P15
(respiro `space10` no fim do conteúdo do `SuperadminFormFrame`, regra gravada em
`coelo-ui/references/form-layout-contracts.md`), `test_driver/main_driver.dart`
para a rota normal dirigida, sete goldens de formulário regravados (diferenças
só das regras transversais) e os três goldens de detalhe de Locais regravados
após o texto sem "prévia" (decisão A do Owner).

**Rota normal.** App de produção em `localhost:3020` com `qa-r03@coelo.me`,
credencial injetada pelo driver via VM Service (nunca passou pelo chat).
Instituições lista e filtra contra produção com estado vazio honesto.

## Pendências e primeiro gate

| Pendência | Primeiro gate |
| --- | --- |
| ~~Aplicar os 21 candidatos e ligar as chaves~~ | Feito pelo coordenador (lotes 10 e 11, 23:23 e 23:33); `candidatos/estrutura` vazio |
| `institutions.create/edit`, `activities.*`, `locations.*` na rota normal com escrita | Rota real por CDP (`qa_main.dart`): o assistente de Instituições travou o renderer ao avançar de Perfil, causa não isolada |
| `units.*` e `groups.*` com escrita | Ponte de ator (220400) em produção; rota real por CDP pendente |
| Contato, documento, representantes, administradores, plano e marca na criação | Próximo pacote no realm interno; hoje ficam vazios após criar |
| MENU-M: os dois goldens 375 regravados congelam o cabeçalho mobile atual | Fase 0 confirmar; reverter os dois PNG de `20f497709` se mudar |
| 180060 substitui três funções compartilhadas em produção | Code review depois do MVP (registrado) |
| 30 goldens órfãos de Locais; 16 falhas pré-existentes de widgets compartilhados | Fora do recorte; registradas |

## Testes

- pgTAP: 18 suítes verdes na prova integral (log no scratchpad da sessão,
  resumo no JSON).
- Flutter: `analyze` limpo; repositório de Instituições 37/37; view model de
  Turmas 5/5; goldens de formulário do recorte verdes após regravação; as
  falhas restantes em `test/shared` (underline tabs, footer adoption) são
  pré-existentes em `origin/dev`, medidas na worktree limpa
  `e2-r04-estrutura-base`.

## Entrega ao coordenador (validação de 11/09, manhã)

- Deltas por action_id: `deltas-r04-estrutura.json` neste diretório (46;
  40 backend → `remote-green`, 6 frontend → `local-green`; nenhum terminal),
  ensaiado com `apply-tracker-delta.cjs` + `validate-trackers.cjs` (PASS) e
  revertido. Comando: `node docs/reviews/apply-tracker-delta.cjs
  docs/reviews/evidence/etapa-2/r04-estrutura/deltas-r04-estrutura.json`.
- Skills: seções "Regras medidas pelo grupo estrutura na Rodada 4" em
  `coelo-supabase`, `coelo-flutter-review` e dois itens em
  `coelo-flutter-supabase-review`, nesta branch.
- Dados sintéticos criados em produção por esta conversa: nenhum.
- Worktrees: `e2-r04-estrutura` (branch) e `e2-r04-estrutura-base` (detached,
  só medição; pode ser removida). Projeto descartável
  `coelo_baseline_estrutura` pode ser parado.
