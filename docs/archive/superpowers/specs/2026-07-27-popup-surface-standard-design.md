---
source: "user-approved visual references; docs/design/design-system.md; apps/superadmin/lib/app/shell/superadmin_bug_report_dialog.dart; apps/superadmin/lib/features/help_center/presentation/screens/superadmin_help_center_page.dart"
status: "approved"
generated_at: "2026-07-27"
---

# Padrões de popups, hover, fechamento e filtros

## Objetivo

Eliminar a criação recorrente de popups com fundo laranja-claro e de estados de
hover cinza. O diálogo de reporte de bug é a referência visual canônica para
overlays; o menu lateral do Superadmin é a referência para itens interativos
discretos. A ação de fechar também deve preservar o “X” vermelho canônico, e
filtros devem reproduzir a anatomia validada em Instituições e Bug.

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

## Contrato de ações de marca

Ações primárias, ações tonais e sugestões preservam a hierarquia laranja:

- a ação primária usa `colorScheme.primary` e `colorScheme.onPrimary`;
- hover, foco e pressionamento permanecem na paleta primária aprovada;
- `overlayColor`, splash ou tint adicional são transparentes quando poderiam
  produzir uma camada branca ou cinza sobre o laranja;
- ações tonais e sugestões usam `colorScheme.primaryContainer` e
  `colorScheme.onPrimaryContainer`, inclusive no hover e foco;
- o estado desabilitado padrão continua neutro;
- uma ação primária antecipada que permanece visível, como enviar antes de
  existir conteúdo, pode usar `primaryContainer` e `onPrimaryContainer` enquanto
  `onPressed` for nulo, sem hover e com semântica de indisponibilidade;
- essa exceção tonal não autoriza opacidade isolada nem faz o controle parecer
  acionável.

Botões de ícone usam alvo mínimo `CoeloSize.touchMin`. Glifos assimétricos,
como `Icons.send_rounded`, ficam centralizados em uma caixa quadrada
`CoeloSize.iconMd`, sem deslocamento manual. A Home da Central de ajuda do
Superadmin é a referência visual desse conjunto.
O catálogo registra os estados primário, tonal, antecipado desabilitado e a
centralização do glifo como comparação recuperável.

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

## Contrato de filtros

### Toolbar

- Busca aparece primeiro, seguida dos filtros e das ações no extremo direito.
- Controles possuem altura mínima de 48 px.
- Espaçamentos usam tokens Coelo e a composição quebra responsivamente sem
  deformar os controles.

### Busca e gatilhos

- Usam forma pill com `CoeloRadius.full`.
- Usam superfície neutra e borda `colorScheme.outlineVariant`.
- Foco visível ou menu aberto usa borda `colorScheme.primary` de 2 px.
- O gatilho aberto usa `colorScheme.primaryContainer` no fundo.
- Texto e seta usam `colorScheme.primary` no estado ativo.

### Painel

- Usa `colorScheme.surface`.
- Usa `CoeloRadius.lg`, borda `colorScheme.outlineVariant` e elevação.
- Abre a 4 px do gatilho.
- Nunca usa laranja como fundo da superfície inteira.

### Opções

- São linhas contínuas com altura mínima de 48 px, sem raio ou espaço entre
  linhas.
- Hover e foco usam `colorScheme.primaryContainer`, com overlay adicional
  transparente.
- Multi-select usa checkbox e texto em `colorScheme.primary` quando
  selecionado, mantendo o fundo transparente até hover ou foco. O checkbox não
  possui hover, splash ou fundo independente.
- Single-select não usa checkbox; seleção, hover e foco usam
  `colorScheme.primaryContainer` no fundo e `colorScheme.primary` no conteúdo.

### Busca interna e rodapé

- Busca interna permanece no topo, usa forma pill e borda primária no foco,
  filtra localmente e possui estado vazio.
- O rodapé do multi-select permanece visível, separado por divisor.
- `Limpar` é ação textual e `Aplicar` é ação primária.
- Estados desabilitados usam tokens semânticos.

### Comportamento

- Alterações do multi-select permanecem em rascunho até `Aplicar`.
- `Esc` ou fechamento descarta alterações não aplicadas e devolve o foco ao
  gatilho.
- A busca interna é limpa ao reabrir.
- Mouse, teclado e toque acessam os mesmos estados e ações.

A tela de Instituições é a referência canônica do multi-select. O popup de Bug
é a referência canônica do single-select.

## Fontes a atualizar

1. `docs/design/design-system.md`, para oficializar a regra semântica.
2. `.agents/skills/coelo-ui`, para exigir a consulta e a aplicação do contrato.
3. O catálogo e seu índice, com exemplos recuperáveis por `popup`, `modal`,
   `dialog`, `overlay`, `surface`, `superfície`, `branco`, `laranja`, `hover`,
   `menu`, `submenu`, `lista`, `filtro`, `tabela`, `fechar`, `close`, `dismiss`
   `vermelho`, `multi-select`, `single-select`, `busca`, `gatilho`, `painel`,
   `limpar` e `aplicar`.

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
- toolbar com busca, filtros e ações;
- multi-select fechado, aberto, pesquisando, selecionado, hover, foco, vazio,
  rascunho, aplicação e limpeza;
- single-select fechado, aberto, selecionado, hover e foco.

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
- `DialogTheme.surfaceTintColor` e o tint explícito de diálogos devem ser
  transparentes; elevação não pode reintroduzir tonalidade laranja.
- Menus de seleção única devem herdar a largura exata do campo e não devem
  exibir check ou checkbox redundante.
- Testes devem assegurar `primaryContainer`, `CoeloRadius.md`,
  `CoeloSpacing.spaceHalf` e overlay transparente no hover de itens discretos.
- Testes devem assegurar que filtros e tabelas preservam linhas contínuas sem
  raio ou espaçamento entre linhas.
- Testes devem assegurar ícone `error`, fundo `errorContainer`, forma circular,
  alvo mínimo de 48 px, tooltip e ausência de overlay cinza na ação de fechar.
- Testes devem assegurar forma pill, altura mínima, bordas de repouso e foco,
  superfície neutra do painel, raio, elevação e distância do gatilho.
- Testes devem assegurar linhas contínuas, checkbox sem camada própria,
  seleção, hover, busca interna, rodapé, rascunho, aplicação, limpeza, `Esc` e
  restauração de foco.
- As mudanças preexistentes no repositório devem ser preservadas.

## Fora de escopo

- Redesenhar os popups existentes.
- Criar automaticamente um novo componente compartilhado.
- Alterar o conteúdo ou o fluxo funcional dos diálogos.
- Usar branco literal no tema escuro.
- Aplicar cantos arredondados ou espaçamento às opções de filtro e às linhas de
  tabelas densas.
- Reutilizar o contrato de fechamento para exclusão ou outra ação destrutiva.
- Criar regras de domínio ou opções de seleção dentro dos componentes visuais.
