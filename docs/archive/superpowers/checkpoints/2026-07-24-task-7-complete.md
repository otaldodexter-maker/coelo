---
title: "Checkpoint seguro da Task 7 da fundacao Coelo UI"
source: "docs/superpowers/plans/2026-07-22-coelo-ui-foundation-componentization-catalog.md; verificacoes locais de 2026-07-24"
status: "task-7-complete"
generated_at: "2026-07-24"
---

# Task 7 concluida

## Resultado obtido

A tela de instituicoes foi migrada para as primitives e padroes administrativos
aprovados, mantendo composicoes de dominio locais. As correcoes visuais
explicitamente aprovadas para marca, botao de recolher e submenu recolhido foram
incorporadas ao baseline. A cascata geografica agora deriva as UFs dos registros
acessiveis e deriva municipios e bairros do recorte selecionado.

O arquivo principal foi dividido por responsabilidade e possui duas fronteiras
estreitas de rebuild: toolbar e resultados. Repository, view model, rotas,
permissoes e `InstitutionDirectoryItem` nao foram enviados aos pacotes de UI.

## Componentes promovidos

- `CoeloSearchField`;
- `CoeloStatusChip`;
- `CoeloAdminListingToolbar`;
- `CoeloAdminPagination`;
- `CoeloAdminResizableTable`.

## Componentes mantidos locais

- estados de loading, erro, vazio e sem permissao;
- filtros multiselect e apresentacao geografica;
- card, detalhes, copy, status expansivel e acoes de arquivo;
- create card e create banner;
- adaptadores de `InstitutionDirectoryViewModel` e
  `InstitutionDirectoryItem`.

## Diferencas visuais aprovadas

- light: circulo laranja e logo Coelo branca;
- dark: circulo branco e logo Coelo laranja;
- botao circular de recolher/abrir novamente parcialmente dentro e fora da
  lateral;
- submenu recolhido 4 px acima, com espacamento, elevacao e estados
  hover/focus/pressed laranja equivalentes ao menu de tour;
- estado confirmado sem UFs exibe `Sem UFs cadastradas`.

Essas diferencas foram registradas nos goldens. Nenhuma outra diferenca visual
foi aceita.

## Verificacoes recentes

Workdir `apps/superadmin`:

- `dart analyze lib/features/institutions test/features/institutions`: limpo;
- view model + pagina: 42 testes passaram, com 2 gaps existentes ignorados;
- pagina estrutural: 32 testes passaram, com 2 gaps existentes ignorados;
- goldens: 5 casos e 26 imagens passaram apos o registro apenas das diferencas
  aprovadas;
- `flutter test --no-pub -j 1 -r silent test/features/institutions`: codigo de
  saida 0;
- `flutter build web --no-pub --dart-define=COELO_DEV_MFA=true`: concluido;
- `http://127.0.0.1:8769/main.dart.js`: HTTP 200, artefato atualizado.

Os diretorios `failures/` gerados durante comparacoes diagnosticas foram
removidos depois da verificacao.

## Localhost e inspecao

O build atualizado esta servido em `http://127.0.0.1:8769/`. A conexao de
automacao visual do navegador ficou indisponivel nesta sessao; por isso a
inspecao visual do artefato atual permanece como conferencia manual adicional,
sem invalidar testes de widget, comportamento e goldens.

## Proximo ponto

Iniciar a Task 8:

1. promover no indice somente os cinco componentes realmente consumidos;
2. implementar em TDD o scanner de exports publicos e fronteiras de pacotes;
3. executar validadores, analise e testes do catalogo;
4. submeter o resultado a revisao independente antes da Task 9.

Nao houve commit, push, deploy ou nova dependencia.
