---
title: "Checkpoint da fundacao Coelo UI"
source: "docs/superpowers/plans/2026-07-22-coelo-ui-foundation-componentization-catalog.md; sessoes de implementacao de 2026-07-22 e 2026-07-23"
status: "paused-safe"
generated_at: "2026-07-23"
---

# Checkpoint da fundacao Coelo UI

## Estado seguro

A implementacao esta em ponto seguro parcial da Task 7. Busca, status, toolbar
responsiva, paginacao e tabela de instituicoes foram promovidos com tolerancia
visual zero. A tabela generica agora reproduz a altura total de 65 px do
baseline com 64 px uteis mais borda e mantem transparente o fundo principal
ocioso. Estados e multiselects permanecem locais por decisoes de
compatibilidade. A divisao de cards/arquivos e a reducao de rebuilds seguem
pendentes.

Nao houve commit, push, deploy ou instalacao de dependencia externa. Alteracoes
preexistentes do usuario continuam no worktree e nao devem ser descartadas,
sobrescritas ou reformatadas.

O plano de referencia permanece em
`docs/superpowers/plans/2026-07-22-coelo-ui-foundation-componentization-catalog.md`.
As Tasks 1 a 6 estao marcadas como concluidas nesse arquivo.

## Concluido

### Fase 1 e gates

- Auditoria somente leitura, inventario, fronteiras, mapa de promocao e riscos.
- Estrategia do catalogo e da skill `coelo-ui` aprovada.
- Plano detalhado aprovado e colocado em execucao.

### Task 1 — baseline e submenu recolhido

- Criados 26 goldens de instituicoes cobrindo light/dark, 375/768/1024/1440,
  cards/tabela, loading, vazio, erro, sem permissao, sem resultados, paginacao,
  hover, foco, selecao e flyout recolhido.
- O flyout recolhido solicitado pelo usuario foi alinhado ao padrao do menu de
  tour: padding de 8 px, elevacao 4, deslocamento vertical de -4 px e estados
  hover/focus/pressed em laranja.
- A verificacao automatizada do shell passou, mas a validacao visual feita pelo
  usuario em `127.0.0.1:8080` estava sobre uma build estatica anterior a essa
  alteracao. A correcao de fonte permanece candidata, mas a entrega continua
  pendente de rebuild em outro endereco e confirmacao visual antes de ser
  considerada concluida.
- O botao circular de recolher/abrir deve continuar parcialmente dentro e
  parcialmente fora da lateral. O diff do submenu nao altera sua geometria e ha
  teste automatizado desse contrato, mas ele tambem sera reconfirmado
  visualmente junto do submenu.
- Lacunas preexistentes registradas, sem mudanca silenciosa: `Esc` nao fecha o
  filtro e texto a 200% gera overflow em 375/1024.

### Task 2 — indice compacto

- Criado `apps/catalog` minimo, ainda sem telas de produto.
- Criado `assets/coelo-ui.index.jsonl` com oito contratos `approved`.
- Validador estrutural usa somente biblioteca padrao e cobre schema, tipos,
  ids, status, consumidores, paths seguros, arquivos e substitutos.
- Resultado final: 11 testes, analise limpa e indice real com zero diagnostico.

### Task 3 — aliases semanticos

- Criados `actionLink`, `primaryPressed`, `focusRing` e
  `CoeloOverlayColors.scrim` sem alterar valores visuais existentes.
- Decisao aprovada e registrada em
  `decisions/0013-dark-primary-pressed-token.md`: pressed escuro = `orange500`.
- Resultado final: 10 testes, analise limpa e goldens de instituicoes identicos.

### Task 4 — `coelo_ui_core`

- Materializados exatamente `CoeloSearchField`, `CoeloStatusChip` e
  `CoeloStatePanel`.
- Nenhum contrato recebeu variante ou parametro futuro.
- Resultado final: 10 testes, `dart analyze` sem issues, scan de fronteira sem
  app/domain/repository/router/Supabase e scan de HEX/`TextStyle` local limpo.

### Task 5 — `coelo_ui_admin`

- Materializados `CoeloAdminListingToolbar`,
  `CoeloAdminMultiSelectFilter<T>`, `CoeloAdminPagination` e
  `CoeloAdminCreateAction`.
- O multiselect preserva elevacao 6, busca opcional com icone arredondado,
  autofocus, Escape local ao overlay, retorno de foco e copia defensiva do
  `Set<T>`.
- Paginacao e criacao preservam contratos publicos stateless, teclado,
  semantica acionavel e reduced motion; estado tecnico ficou privado.
- Resultado final: `dart analyze` sem issues, 19 testes, scans de fronteira e
  estilos locais limpos e revisao independente aprovada.
- O pacote agora e consumido pelo Superadmin na migracao parcial da Task 7.

### Task 6 — tabela

- Materializados `CoeloAdminTableColumn<T>` e
  `CoeloAdminResizableTable<T>`.
- Preservados `Card` com clip, scrollbar sempre visivel, scroll horizontal,
  coluna fixa duplicada sob `IgnorePointer`, conteudo de 64 px mais borda para
  altura total de 65 px, mapa unico de larguras, clamp, hover sincronizado e
  reduced motion.
- Resize aceita drag, semantica increase/decrease e setas em passos de 8 px;
  foco visivel usa `CoeloActionColors.focusRing`. A copia pinned conserva apenas
  o indicador visual e nao cria parada duplicada de Tab.
- Linhas preservam `Key(String)`, estado em reorder, selecao semantica e callback
  de toque. Celulas, copia, status, textos e `InstitutionDirectoryItem`
  permanecem locais.
- O fundo principal ocioso permanece transparente, alinhado ao baseline; a
  selecao continua explicita.
- Resultado final: 8 testes focados, 27 testes do pacote, `dart analyze` limpo,
  testes visuais de referencia de instituicoes sem diferencas e revisao
  independente aprovada.

### Task 7 — migracao parcial de instituicoes

- Promovidos busca, status, toolbar responsiva, paginacao e
  `CoeloAdminResizableTable`.
- Preservadas as keys publicas da pagina e das linhas; detalhes internos da
  tabela usam o prefixo aprovado `coelo-admin-*`.
- A primeira comparacao da tabela revelou diferencas de 0,74% a 1,20%. A causa
  real era a borda pintada dentro do `height` explicito de 64 px, reduzindo a
  altura util em relacao ao total de 65 px do baseline, somada ao fundo
  principal nao transparente.
- Depois da correcao interna do pacote, as falhas de geometria e imagem foram
  removidas e a tabela foi migrada novamente.
- Resultado final: pacote 8 testes focados/27 na suite, pagina 29 testes
  passando e 2 ignorados, instituicoes 64 passando e 2 ignorados, golden 5
  casos/26 imagens sem atualizacao, analises de `coelo_ui_admin` e
  `apps/superadmin` limpas.
- Os testes Flutter foram executados diretamente por
  `flutter_tools.snapshot --no-pub -j 1`. Nenhum comando de update de golden
  foi usado.
- A Task 7 permanece parcial: states, multiselects, cards/divisao de arquivos e
  reducao de rebuilds continuam pendentes.

## Gates aprovados para a Task 7

`CoeloAdminCreateAction` representa somente o contrato aprovado
`label/onPressed/icon`. Ele nao consegue reproduzir simultaneamente o card
vertical com descricao e o banner horizontal compacto existentes em
instituicoes. Em 2026-07-23 foi aprovado manter `_CreateInstitutionCard` e
`_CreateInstitutionBanner` como composicoes locais, usando apenas primitives
compartilhadas compativeis. Nao criar variante nem remover o subtitulo.

As chaves encapsuladas da tabela generica usam prefixo `coelo-admin-*`, enquanto
a tela atual possui chaves `institution-*` para scroll, headers, resizers,
pinned e backgrounds. Em 2026-07-23 foi aprovado preservar as chaves publicas da
pagina e das linhas, adotando `coelo-admin-*` somente para detalhes internos
encapsulados da tabela. Atualizar apenas os testes internos correspondentes, sem
criar configuracao publica de keys.

## Requisito funcional registrado para depois da migracao visual

Os filtros geograficos de instituicoes devem passar a receber somente valores
existentes nos registros acessiveis: UFs distintas, municipios das UFs
selecionadas e bairros do recorte anterior. A consulta e a cascata pertencem ao
repository/view model de instituicoes, nao ao multiselect generico. Essa mudanca
de comportamento ocorre somente depois de a Task 7 passar com tolerancia visual
zero.

## Proxima sequencia

1. Conferir `git status`, o relatorio `.superpowers/sdd/task-7-report.md` e este
   checkpoint.
2. Decidir os contratos futuros de states e multiselects sem alterar os filtros
   geograficos nesta migracao.
3. Dividir literalmente toolbar/states/cards locais em uma rodada pequena,
   preservando estrutura e keys. A composicao local da tabela ja esta em
   `institution_directory_table.dart`.
4. Avaliar reducao de rebuilds somente depois das divisoes verdes.
5. Continuar Tasks 8 a 16 somente conforme a coordenacao do plano.

## Evidencias recentes

- Instituicoes: 64 testes passaram com 2 gaps marcados; caracterizacao isolada
  passou 29 testes com 2 gaps marcados.
- Shell: 60 testes passaram.
- `coelo_tokens`: 10 testes e analise limpa.
- `coelo_ui_core`: 10 testes e analise limpa.
- `coelo_ui_admin`: 8 testes focados, 27 testes na suite, analise limpa, scans de
  fronteira/estilos limpos
  e revisao independente aprovada.
- Testes visuais de referencia de instituicoes: 5 testes passaram sem atualizar
  as 26 imagens aprovadas.
- Catalogo/indice: 11 testes, analise limpa e zero diagnostico estrutural.
- Goldens de instituicoes: 26 referencias comparadas sem atualizacao apos os
  tokens; nenhuma diferenca.
- Task 7 parcial: busca, status, toolbar, paginacao e tabela passaram 29 page
  tests, com 2 gaps ignorados, e os 5 casos golden/26 imagens sem atualizacao.
- Diagnostico concluido: a altura total correta e 65 px, formada por 64 px
  uteis mais a borda; o fundo principal ocioso deve permanecer transparente.
  As correcoes e os testes focados removeram as falhas anteriores.
- Runner Flutter final: `flutter_tools.snapshot --no-pub -j 1`.
- Analises de `coelo_ui_admin` e `apps/superadmin`: limpas.
- `git diff --check`: sem erro no ultimo checkpoint.
