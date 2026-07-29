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

- A superfície-base é `colorScheme.surface` em light e dark.
- `surfaceTintColor` é sempre `Colors.transparent`; tint de Material não pode
  recolorir a superfície.
- É proibido usar `colorScheme.primaryContainer` como fundo-base, assim como
  laranja-claro ou outra tonalidade de marca, do contêiner.
- Usar barreira preta translúcida, conteúdo contextual e ação primária quando
  aplicável. A barreira preserva o contraste.
- O painel de filtro usa `colorScheme.surface`, `CoeloRadius.lg`, borda
  `colorScheme.outlineVariant`, elevação e abertura a 4 px do gatilho.
- O diálogo de reporte de bug do Superadmin é a referência canônica de
  composição; seu conteúdo de domínio não é um componente genérico.
- Composições administrativas reutilizam `CoeloAdminDialogShell`: uma ação
  ocupa a largura útil e duas ações dividem a largura igualmente com
  `CoeloSpacing.space3`. O corpo rola sem deslocar cabeçalho ou rodapé.

## Hover e foco

- Itens discretos de navegação, menus, submenus e listas de ações usam
  `colorScheme.primaryContainer` no hover e foco visível,
  `colorScheme.primary` no conteúdo destacado, `CoeloRadius.md` e margem
  vertical `CoeloSpacing.spaceHalf` entre itens.
- O overlay ou splash adicional é transparente; não sobrepor camada cinza. O
  estado desabilitado não recebe hover.
- Opções em filtros e tabelas densas são linhas contínuas: usam
  `colorScheme.primaryContainer` no hover e foco, mas não recebem raio ou
  espaçamento entre linhas.
- O menu lateral do Superadmin é a referência de item discreto.

## Ações primárias, tonais e por ícone

- Ação primária usa `colorScheme.primary` e `onPrimary`; hover, foco e pressed
  permanecem na paleta primária aprovada, sem overlay branco ou cinza.
- Ação tonal, chip acionável e sugestão preservam `primaryContainer` e
  `onPrimaryContainer` no hover e foco. O overlay adicional é transparente.
- Disabled é neutro por padrão. Somente ação primária antecipada e ainda
  indisponível pode usar `primaryContainer` e `onPrimaryContainer`, com
  `onPressed: null`, sem hover e sem depender apenas de opacidade.
- Botão de ícone usa alvo mínimo `CoeloSize.touchMin`. Glifo assimétrico usa
  caixa quadrada `CoeloSize.iconMd` centralizada, sem `Transform.translate` ou
  padding assimétrico não aprovado.
- A Home da Central de ajuda do Superadmin é a referência visual.

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
  rodapé persistente com `Limpar` e `Aplicar`. A busca interna é limpa ao reabrir.
- O multi-select selecionado usa texto e checkbox em `colorScheme.primary` e
  fundo transparente até hover ou foco. O checkbox não recebe hover, splash ou
  fundo próprio.
- O single-select usa `colorScheme.primaryContainer` no estado selecionado, hover e foco,
  com conteúdo em `colorScheme.primary`; não usa checkbox nem check. O painel
  acompanha exatamente a largura do gatilho, abre 4 px abaixo, exibe no máximo
  seis opções e reduz sua altura ao espaço inferior disponível. A busca
  permanece fixa e somente as opções rolam.
- Reutilizar `CoeloAdminMultiSelectFilter` como referência de implementação do
  multi-select administrativo. Instituições é a referência de comportamento do
  multi-select; o popup de Bug é a referência do single-select.

## Tabela administrativa

- Para lista administrativa ampla, consultar `admin.resizable-table` no índice
  e reutilizar `CoeloAdminResizableTable`; a tabela de Instituições é a
  referência canônica. Não substituir esse padrão por `DataTable` ou uma tabela
  local paralela sem aprovação explícita.
- A superfície é card em `colorScheme.surface`, com borda
  `colorScheme.outlineVariant`, raio do card e clip anti-alias. O cabeçalho usa
  `colorScheme.surfaceContainer` e as linhas permanecem contínuas.
- Cada linha mede 64 px mais divisor de 1 px `colorScheme.outlineVariant`.
  Hover, foco e seleção usam `colorScheme.primaryContainer`, sem zebra, raio ou
  espaçamento entre linhas.
- Manter coluna fixa visual durante o scroll horizontal e excluir sua cópia da
  semântica. Exibir scrollbar horizontal visível quando necessário e aceitar
  mouse, toque, caneta e trackpad.
- Oferecer redimensionamento por mouse e teclado, com cursor de coluna, foco
  visível e rótulo semântico para o redimensionador. Usar truncamento sem quebra
  (`ellipsis`), sem wrap; tooltip apenas para informação não crítica.
- Status semântico usa chip com texto, cor e ícone opcional. Ações compactas
  expõem no máximo duas ações rápidas ou um menu contextual, separando ações
  sensíveis.

## Acessibilidade

- Resolver cores por tokens semânticos nos dois temas, sem HEX ou branco literal
  local. Validar contraste, foco visível, teclado, leitor de tela, tooltip e
  alvo mínimo.
- Mouse, teclado e toque devem disponibilizar os mesmos estados e ações.
