---
title: "Institution Directory Multiselect Filters"
source: "Ajustes aprovados pelo usuario em 2026-07-20"
status: "approved-design"
generated_at: "2026-07-20"
---

# Institution Directory Multiselect Filters

## Objetivo

Permitir múltiplas seleções nos filtros do Diretório de Instituições e diferenciar visualmente uma opção selecionada de uma opção apenas sob hover, preservando a consulta paginada no servidor e o fluxo geográfico dependente.

## Escopo

- Tornar multisseleção os filtros exibidos de Tipo, Status, UF, Município e Bairro.
- Manter a busca por nome como campo textual simples.
- Manter o menu aberto enquanto opções são marcadas ou desmarcadas.
- Aplicar todas as alterações de um menu em uma única consulta pelo botão `Aplicar`.
- Oferecer `Limpar` dentro de cada menu para limpar somente sua seleção provisória.
- Preservar `Limpar filtros` na toolbar para remover, de uma vez, todos os filtros já aplicados.
- Diferenciar repouso, hover, selecionado e selecionado com hover usando somente cores semânticas do tema Coelo.
- Levar a multisseleção ao modelo de consulta, view model, repositório fictício e repositório Supabase.

## Fora de escopo

- Adicionar filtro de Plano ou alterar a ordem atual da toolbar.
- Alterar tabelas, views, migrations, RLS ou dados do Supabase.
- Alterar a taxonomia ou as cores dos status institucionais.
- Aplicar filtros sobre uma página já carregada no cliente.
- Disparar consulta de diretório a cada marcação provisória dentro do menu.

## Comportamento do menu

Cada `_DirectoryFilterMenu<T>` manterá duas coleções distintas:

- valores aplicados, recebidos do view model;
- valores provisórios, mantidos localmente enquanto o menu está aberto.

Ao abrir, os valores provisórios serão sincronizados com os aplicados. Marcar ou desmarcar uma opção altera apenas os provisórios e mantém o menu aberto. `Limpar` esvazia os provisórios sem fechar o menu. `Aplicar` envia uma coleção imutável ao view model, fecha o menu, reinicia a página em zero e executa uma única carga. Fechar o menu sem aplicar descarta as alterações provisórias.

O rótulo do gatilho seguirá estas regras:

- nenhuma opção: rótulo geral atual, como `Todos os status`;
- uma opção: nome da opção;
- duas ou mais: `<quantidade> selecionados` ou `<quantidade> selecionadas`, conforme o filtro.

O menu continuará oferecendo pesquisa interna somente para UF, Município e Bairro. A pesquisa filtra as opções visíveis, mas não desmarca opções ocultadas pelo texto.

## Estado visual das opções

As opções continuarão usando `MenuItemButton`, com indicador de seleção e estilos explícitos:

- repouso: fundo transparente e texto padrão;
- hover/foco: `colorScheme.primaryContainer` e texto `colorScheme.primary`;
- selecionado: fundo `colorScheme.primary` com opacidade de 14% no tema claro e 22% no tema escuro, com texto/ícone `colorScheme.primary`;
- selecionado com hover/foco: fundo `colorScheme.primary` com opacidade de 20% no tema claro e 30% no tema escuro, preservando texto/ícone `colorScheme.primary`;
- overlay Material: transparente, evitando película cinza.

Nenhum HEX será criado na feature.

## Consulta e estado

`InstitutionDirectoryQuery` substituirá os campos escalares por coleções imutáveis:

- `statuses`;
- `typeIds`;
- `states`;
- `cities`;
- `districts`.

Coleção vazia significa ausência de restrição. Igualdade e `hashCode` compararão o conteúdo das coleções, e toda alteração aplicada reiniciará a paginação. `hasActiveFilters` continuará controlando o botão global `Limpar filtros` e os estados vazios.

O view model exporá setters de coleção e preservará a cascata:

- aplicar UFs substitui `states` e limpa `cities` e `districts`;
- aplicar Municípios substitui `cities` e limpa `districts`;
- aplicar Bairros, Tipos ou Status altera apenas seu próprio conjunto;
- `clearFilters()` restaura todas as coleções vazias, limpa a busca textual e volta para a página zero.

## Repositórios

O repositório fictício usará semântica OR dentro de cada filtro e AND entre filtros. Exemplo: `SP` ou `PR`, e `Ativa` ou `Em implantação`, combinados com o restante da consulta.

O repositório Supabase usará filtros `IN` somente quando a coleção correspondente não estiver vazia. A busca, ordenação, contagem e paginação continuarão no servidor.

`fetchFilterOptions` passará a receber coleções de UFs e Municípios:

- Municípios serão a união das opções pertencentes às UFs aplicadas;
- Bairros serão a união das opções pertencentes aos Municípios aplicados dentro das UFs aplicadas;
- quando o filtro pai estiver vazio, o filtro dependente não será exibido;
- aplicar uma nova seleção no pai limpará as seleções dos filhos antes da próxima carga.

## Toolbar e limpeza global

O botão global `Limpar filtros` existente será preservado. Ele aparecerá quando houver busca ou ao menos uma seleção aplicada em qualquer filtro, e removerá busca, Tipos, Status, UFs, Municípios e Bairros em uma única ação.

As seleções provisórias ainda não aplicadas não alteram o diretório nem o estado global do botão. Ao reabrir um menu após fechar sem aplicar, ele refletirá somente os valores aplicados.

## Estados e acessibilidade

- Cada opção será anunciada como selecionada ou não selecionada.
- Os botões `Limpar` e `Aplicar` terão altura mínima `CoeloSize.touchMin` e navegação por teclado.
- `Aplicar` poderá ficar desabilitado quando os valores provisórios forem idênticos aos aplicados.
- O filtro pesquisável continuará exibindo `Nenhuma opção encontrada.` sem perder seleções ocultas.
- O indicador visual não dependerá somente de cor: checkbox/check e semântica comunicarão a seleção.

## Testes

- Modelo: igualdade, `hashCode`, filtros ativos e paginação com coleções.
- View model: multisseleção, uma carga por aplicação, reset de página e cascata UF → Município → Bairro.
- Repositório fictício: OR dentro de cada coleção e AND entre filtros.
- Repositório Supabase: construção de filtros `IN`, preservando busca e paginação.
- Widget: menu permanece aberto ao marcar, aplica uma vez, descarta ao fechar, limpa localmente e exibe contagem no gatilho.
- Widget: `Limpar filtros` global permanece visível após aplicação e limpa todos os conjuntos.
- Widget: estados visuais de hover, selecionado e selecionado com hover são distintos em light e dark.
- Widget: pesquisa geográfica mantém seleções não visíveis pelo texto.
- Análise estática, suíte Flutter completa e build web.

## Critérios de aceite

- Tipo, Status, UF, Município e Bairro permitem selecionar mais de uma opção.
- Marcar opções não fecha o menu nem dispara carga antes de `Aplicar`.
- Cada `Aplicar` dispara no máximo uma carga e reinicia a paginação.
- O botão global `Limpar filtros` continua aparecendo para filtros aplicados e limpa tudo.
- A opção selecionada tem fundo persistente diferente do hover simples, texto laranja e indicador não baseado apenas em cor.
- Múltiplas UFs alimentam as opções de Município; múltiplos Municípios alimentam Bairro.
- A rota real continua filtrando e paginando no Supabase; a rota `/dev/*` continua usando apenas dados fictícios.
- Nenhuma mudança de banco é necessária.
