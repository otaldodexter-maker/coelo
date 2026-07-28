---
source: "Solicitação aprovada para centralizar e alinhar visualmente a paginação de Instituições"
status: "approved"
generated_at: "2026-07-28"
---

# Refinamento da paginação de Instituições no Superadmin

## Objetivo

Centralizar a paginação da listagem de Instituições nos modos de cards e tabela
e substituir o seletor genérico de quantidade por página por uma composição
compacta alinhada ao Design System Coelo.

## Composição aprovada

- O conjunto completo da paginação fica centralizado: `Itens por página`,
  seletor, navegação anterior, indicador de página, páginas visíveis e navegação
  seguinte.
- O alinhamento pertence a `CoeloAdminPagination`, para permanecer igual nos
  modos de cards e tabela e em qualquer quebra responsiva do componente.
- Quando o conteúdo ocupar mais de uma linha, cada linha do `Wrap` permanece
  centralizada.
- O seletor de quantidade continua compacto e ao lado do rótulo; ele não assume
  a aparência de um campo completo de formulário.
- O gatilho usa forma pill, borda `outlineVariant`, superfície neutra, valor
  textual e seta. Hover, foco e menu aberto usam a hierarquia laranja aprovada.
- O menu usa `colorScheme.surface`, sem tint ou fundo cinza, borda
  `outlineVariant`, `CoeloRadius.lg` e elevação semântica.
- O painel acompanha a largura do gatilho. As opções são linhas contínuas com
  alvo mínimo de 48 px, sem check ou checkbox.
- A opção selecionada, o hover e o foco usam `primaryContainer` com conteúdo
  `primary`.
- As opções continuam definidas pelo consumidor: cards usam
  `11, 20, 50, 100`; tabela usa `9, 20, 50, 100`.

## Implementação

`CoeloAdminPagination`, em `coelo_ui_admin`, continua sendo o componente público
existente. O seletor visual será uma composição privada interna baseada em
`MenuAnchor`; não será criada nova API pública, variante, dependência ou token.

`InstitutionDirectoryPage` deixa de impor alinhamento à direita. A mesma
instância de `InstitutionDirectoryPagination` continuará atendendo cards e
tabela, sem duplicação entre os dois modos.

## Responsividade e acessibilidade

- Mouse, teclado e toque podem abrir o menu e selecionar uma quantidade.
- O gatilho anuncia a quantidade atual e conserva foco visível.
- Cada opção comunica seu valor em texto; a seleção não depende somente da cor.
- `Esc` fecha o menu e o foco retorna ao gatilho pelo comportamento do
  `MenuAnchor`.
- Os controles preservam alvo mínimo de 48 px e não causam overflow nas
  larguras compactas suportadas.
- Light e dark usam apenas cores semânticas do tema.

## Aceite e verificação

- a paginação aparece centralizada nos modos cards e tabela;
- quebras do `Wrap` permanecem centralizadas;
- o menu não usa o dropdown cinza padrão do Material;
- gatilho e painel possuem a mesma largura;
- opção selecionada, hover e foco seguem `primaryContainer` e `primary`;
- não existe check ou checkbox no single-select;
- callbacks e opções atuais de tamanho de página continuam funcionando;
- testes de widget cobrem alinhamento, estilo, seleção e teclado;
- os testes focados de Instituições e o golden relevante são executados;
- os arquivos Dart alterados passam por formatação e análise estática.

## Fora de escopo

Não mudam a consulta, a contagem total, os tamanhos de página, o algoritmo de
páginas visíveis, a tabela, os cards, filtros ou regras de domínio de
Instituições.
