---
title: "Handoff — grupo estrutura, Rodada 4 (E2-R04-20260911)"
source: "worktree e2-r04-estrutura, branch work/etapa2-r04-estrutura; comunicacao/estrutura.json revisões 23 a 28"
status: "em andamento; atualizado na mini-revisão das 04:20"
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

**Cliente.** P5 (filtros de Turmas degradam de forma honesta, com teste), P6
(widget morto do diálogo de importar removido; o botão já era honesto), P15
(respiro `space10` no fim do conteúdo do `SuperadminFormFrame`, regra gravada em
`coelo-ui/references/form-layout-contracts.md`), `test_driver/main_driver.dart`
para a rota normal dirigida, sete goldens de formulário regravados (diferenças
só das regras transversais).

**Rota normal.** App de produção em `localhost:3020` com `qa-r03@coelo.me`,
credencial injetada pelo driver via VM Service (nunca passou pelo chat).
Instituições lista e filtra contra produção com estado vazio honesto.

## Pendências e primeiro gate

| Pendência | Primeiro gate |
| --- | --- |
| Aplicar os 20 candidatos e ligar `structureMutationsEnabled` | Coordenador (preflight no espelho dele em curso) |
| `institutions.create/edit`, `activities.*`, `locations.*` na rota normal com escrita | Chave ligada na base conjunta (o classificador desta sessão bloqueou a edição) |
| `units.*` e `groups.*` com escrita | P22 ponte de ator (RPCs people-based negam qa-r03) |
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
