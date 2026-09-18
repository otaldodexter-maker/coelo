---
source: "specs/013-ui-packages-componentization.md; docs/superpowers/plans/2026-07-22-coelo-ui-foundation-componentization-catalog.md"
status: "completed-local-foundation-with-operational-gates"
generated_at: "2026-07-27"
---

# Checkpoint - Task 16

## 1. Resultado obtido

A matriz final de formatacao, analise, testes, acessibilidade, responsividade,
goldens, fronteiras, sincronizacao e builds esta verde. A revisao independente
nao encontrou problemas criticos ou importantes. As duas observacoes menores
foram incorporadas: larguras preservadas da tabela agora respeitam novos
`minWidth`/`maxWidth`, e a skill registra metadados documentais sem violar seu
schema oficial.

## 2. Arquivos alterados nesta task

- `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- `apps/superadmin/lib/features/institutions/presentation/widgets/institution_directory_cards.dart`
- `apps/superadmin/lib/features/institutions/presentation/widgets/institution_directory_toolbar.dart`
- `apps/superadmin/lib/features/institutions/presentation/widgets/institution_directory_table.dart`
- `apps/superadmin/lib/features/institutions/presentation/widgets/institution_file_actions.dart`
- `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`
- `apps/catalog/assets/coelo-ui.index.jsonl`
- `apps/catalog/assets/catalog-sync-report.json`
- `apps/catalog/test/presentation/showroom_content_equivalence_test.dart`
- `packages/coelo_ui_admin/lib/src/table/coelo_admin_resizable_table.dart`
- `packages/coelo_ui_admin/test/table/coelo_admin_resizable_table_test.dart`
- `.agents/skills/coelo-ui/SKILL.md`
- `specs/013-ui-packages-componentization.md`
- `specs/README.md`
- READMEs de `apps/catalog`, `apps/superadmin` e `packages/coelo_tokens`
- `.superpowers/sdd/task-16-final-verification-report.md`

Alteracoes preexistentes e nao relacionadas do worktree foram preservadas.

## 3. Componentes criados, promovidos ou mantidos locais

Nenhum novo componente, variante, token ou dependencia foi criado nesta task.
O multiselect de status, cards e composicoes de instituicao continuam locais
porque carregam contrato e geometria de dominio. As primitives aprovadas
continuam em `coelo_ui_core`; os padroes administrativos aprovados continuam em
`coelo_ui_admin`. A tabela existente recebeu apenas reconciliacao defensiva de
constraints, sem nova API publica.

## 4. Diferenca visual encontrada

Os goldens da tela de instituicoes e das telas de autenticacao passaram sem
atualizacao ou diferenca. Em texto a 200%, o teste encontrou overflow real no
header e nos cards; alturas fixas foram convertidas em alturas minimas,
preservando exatamente os 88 px e 216 px no baseline e permitindo crescimento
apenas quando a acessibilidade exige.

As correcoes visuais aprovadas anteriormente permanecem entregues: submenu
recolhido com hover laranja e espacamento/elevacao aprovados, botao de recolher
na geometria original e marca circular coerente em shell e auth.

## 5. Testes executados

- analise estatica limpa nas cinco unidades materializadas afetadas;
- 425 testes completos aprovados, zero skips;
- Superadmin: 278;
- catalogo: 98;
- tokens/core/admin: 10/10/29;
- goldens de instituicoes e auth passaram sem atualizacao na Task 16;
- quatro scans de estilos/fronteiras: zero ocorrencia;
- tres validadores: zero diagnostico;
- `git diff --check`: zero erro;
- builds web de Superadmin e catalogo: concluidos;
- Superadmin final: 40 arquivos, 43.908.594 bytes e `main.dart.js` com
  3.379.267 bytes.

Detalhes, comandos e medidas estao em
`.superpowers/sdd/task-16-final-verification-report.md`.

## 6. Pendencias

- A publicacao futura depende de autenticacao Coelo no host/edge para todos os
  artefatos e CSP `frame-ancestors` restrito ao Superadmin.
- O aviso transitivo de fonte `CupertinoIcons` dos builds e nao bloqueante; nao
  existe uso direto nem foi adicionada dependencia.
- Astro permanece somente planejado; nenhum arquivo Astro foi implementado.
- Nenhum localhost foi iniciado, conforme solicitado pelo usuario.

## 7. Decisao que precisa de aprovacao

Nenhuma decisao nova de produto ou Design System. Infraestrutura, configuracao
de host privado e qualquer deploy continuam exigindo autorizacao explicita.
