---
source: "docs/design/design-system.md; docs/superpowers/specs/2026-07-27-popup-surface-standard-design.md"
status: "active"
generated_at: "2026-07-27"
---

# Contratos de superfícies e interação

Consulta obrigatória para popup, modal, dialog, overlay, hover, menu, filtro,
close, dismiss ou “X”. Aplicar antes de escolher uma composição visual. Este
contrato não aprova componentes públicos, APIs, variantes ou mudanças de domínio.

## Popup, modal, dialog e overlay

- A superfície-base é `colorScheme.surface` em light e dark; nunca usar
  `colorScheme.primaryContainer`, laranja-claro ou tonalidade de marca como
  fundo integral do contêiner.
- Usar barreira preta translúcida, conteúdo contextual e ação primária quando
  aplicável. A barreira preserva o contraste.
- O painel de filtro usa `colorScheme.surface`, `CoeloRadius.lg`, borda
  `colorScheme.outlineVariant`, elevação e abertura a 4 px do gatilho.
- O diálogo de reporte de bug do Superadmin é a referência canônica de
  composição; seu conteúdo de domínio não é um componente genérico.

## Hover e foco

- Itens discretos de navegação, menus, submenus e listas de ações usam
  `colorScheme.primaryContainer` no hover e foco visível,
  `colorScheme.primary` no conteúdo destacado, `CoeloRadius.md` e margem
  vertical `CoeloSpacing.spaceHalf` entre itens.
- O overlay ou splash adicional é transparente; não sobrepor camada cinza. O
  estado desabilitado não recebe hover.
- Opções de filtro e tabelas densas são exceção de linha contínua: usam
  `colorScheme.primaryContainer` no hover e foco, mas não recebem raio ou
  espaçamento entre linhas.
- O menu lateral do Superadmin é a referência de item discreto.

## Close, dismiss e “X”

- A ação de fechar ou dispensar usa `Icons.close_rounded`,
  `colorScheme.error` no ícone em repouso, fundo transparente e forma circular.
- Hover e foco visível usam `colorScheme.errorContainer`; o ícone continua em
  `colorScheme.error` e o splash ou overlay adicional permanece transparente.
- Exigir alvo mínimo de 48 px, tooltip contextual e semântica de fechamento.
  Este contrato não se aplica a exclusão de dados ou demais ações destrutivas.
- Quando permitido, `Esc` fecha a superfície e devolve foco à origem. Em filtro
  multi-select, fechar ou usar `Esc` descarta rascunhos não aplicados.

## Filtros

- A toolbar ordena busca, filtros e ações à direita. Busca e gatilhos têm altura
  mínima de 48 px, forma pill com `CoeloRadius.full`, superfície neutra e borda
  `colorScheme.outlineVariant`; foco ou menu aberto usa borda
  `colorScheme.primary` de 2 px.
- O gatilho aberto usa `colorScheme.primaryContainer`; texto e seta ativos usam
  `colorScheme.primary`. As opções têm altura mínima de 48 px, são contínuas e
  não recebem camada cinza adicional.
- Multi-select mantém rascunho até `Aplicar`, possui busca interna com vazio e
  rodapé persistente com `Limpar` e `Aplicar`. O checkbox não recebe hover,
  splash ou fundo próprio; single-select não usa checkbox.
- Reutilizar `CoeloAdminMultiSelectFilter` como referência de implementação do
  multi-select administrativo. Instituições é a referência de comportamento do
  multi-select; o popup de Bug é a referência do single-select.

## Acessibilidade

- Resolver cores por tokens semânticos nos dois temas, sem HEX ou branco literal
  local. Validar contraste, foco visível, teclado, leitor de tela, tooltip e
  alvo mínimo.
- Mouse, teclado e toque devem disponibilizar os mesmos estados e ações.
