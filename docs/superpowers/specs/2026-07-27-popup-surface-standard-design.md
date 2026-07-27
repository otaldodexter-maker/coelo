---
source: "user-approved visual references; docs/design/design-system.md; apps/superadmin/lib/app/shell/superadmin_bug_report_dialog.dart"
status: "approved"
generated_at: "2026-07-27"
---

# Padrões de popups, hover e fechamento

## Objetivo

Eliminar a criação recorrente de popups com fundo laranja-claro e de estados de
hover cinza. O diálogo de reporte de bug é a referência visual canônica para
overlays; o menu lateral do Superadmin é a referência para itens interativos
discretos. A ação de fechar também deve preservar o “X” vermelho canônico.

## Contrato visual

- Todo popup, modal ou diálogo usa `colorScheme.surface` como superfície-base.
- No tema claro, a superfície-base é branca.
- No tema escuro, a superfície-base é a superfície neutra escura semântica.
- `primaryContainer`, laranja-claro e outras tonalidades de marca não podem ser
  usados como fundo-base do contêiner.
- O laranja permanece reservado a ações primárias, bordas ativas, seleção,
  hover, foco e destaques previstos pelo Design System.
- A barreira usa preto translúcido e preserva o contraste do conteúdo.
- O diálogo de reporte de bug do Superadmin é a referência visual canônica de
  composição, sem transformar seu conteúdo de domínio em componente genérico.

## Contrato de hover

Itens discretos de navegação, menus, submenus e listas de ações usam:

- `colorScheme.primaryContainer` no hover e no foco visível;
- `colorScheme.primary` no conteúdo destacado;
- `CoeloRadius.md` para cantos de 12 px;
- margem vertical `CoeloSpacing.spaceHalf`, produzindo 4 px entre itens
  consecutivos;
- overlay ou splash adicional transparente, para não criar uma camada cinza
  sobre o laranja-claro.

O estado desabilitado não recebe hover. Light e dark resolvem as cores pelos
tokens semânticos do tema, sem HEX ou cores físicas locais.

Filtros e tabelas densas são exceções de linha contínua. Suas opções ou linhas
usam `colorScheme.primaryContainer` no hover e no foco, mas não recebem cantos
arredondados nem espaçamento entre linhas.

O menu lateral do Superadmin é a referência visual canônica desse contrato.

## Contrato da ação de fechar

Todo “X” cuja ação seja fechar ou dispensar uma superfície usa:

- `Icons.close_rounded`;
- `colorScheme.error` no ícone em repouso;
- fundo transparente em repouso;
- `colorScheme.errorContainer` no hover e no foco visível;
- `colorScheme.error` no ícone destacado;
- overlay ou splash adicional transparente;
- forma circular e alvo interativo mínimo de 48 px;
- tooltip contextual obrigatório, como `Fechar importação`.

Light e dark resolvem as cores pelos tokens semânticos correspondentes. Esta
regra representa fechamento, não exclusão de dados nem outras ações destrutivas.
O popup de reporte de bug e o modal de importação do Superadmin são as
referências visuais canônicas.

## Fontes a atualizar

1. `docs/design/design-system.md`, para oficializar a regra semântica.
2. `.agents/skills/coelo-ui`, para exigir a consulta e a aplicação do contrato.
3. O catálogo e seu índice, com exemplos recuperáveis por `popup`, `modal`,
   `dialog`, `overlay`, `surface`, `superfície`, `branco`, `laranja`, `hover`,
   `menu`, `submenu`, `lista`, `filtro`, `tabela`, `fechar`, `close`, `dismiss`
   e `vermelho`.

## Catálogo

O catálogo deve demonstrar o mesmo popup em light e dark e registrar:

- superfície-base;
- barreira;
- cabeçalho e fechamento;
- ação primária;
- estado selecionado ou ativo sem contaminar a superfície-base.

O exemplo deve apontar para a regra oficial e para o proprietário atual. Esta
mudança não aprova automaticamente um novo componente público.

O catálogo também deve comparar:

- item discreto com hover/foco laranja-claro, raio e separação;
- opção de filtro em linha contínua;
- linha de tabela densa em linha contínua;
- ausência de camada cinza sobre o estado destacado.
- ação de fechar em repouso, hover e foco, com tooltip contextual.

## Verificação

- Um cenário de baseline deve demonstrar que a orientação atual permite ou não
  impede com clareza o fundo laranja-claro.
- Outro cenário de baseline deve demonstrar a escolha incorreta de hover cinza,
  sem raio ou sem separação em um item discreto.
- O mesmo cenário deve passar após a mudança no skill.
- A consulta do índice pelos termos de popup e hover deve retornar os padrões.
- Validadores do índice e da sincronização do catálogo devem passar.
- Testes documentais ou de widget devem assegurar `colorScheme.surface` em
  light e dark e rejeitar `primaryContainer` como superfície-base.
- Testes devem assegurar `primaryContainer`, `CoeloRadius.md`,
  `CoeloSpacing.spaceHalf` e overlay transparente no hover de itens discretos.
- Testes devem assegurar que filtros e tabelas preservam linhas contínuas sem
  raio ou espaçamento entre linhas.
- Testes devem assegurar ícone `error`, fundo `errorContainer`, forma circular,
  alvo mínimo de 48 px, tooltip e ausência de overlay cinza na ação de fechar.
- As mudanças preexistentes no repositório devem ser preservadas.

## Fora de escopo

- Redesenhar os popups existentes.
- Criar automaticamente um novo componente compartilhado.
- Alterar o conteúdo ou o fluxo funcional dos diálogos.
- Usar branco literal no tema escuro.
- Aplicar cantos arredondados ou espaçamento às opções de filtro e às linhas de
  tabelas densas.
- Reutilizar o contrato de fechamento para exclusão ou outra ação destrutiva.
