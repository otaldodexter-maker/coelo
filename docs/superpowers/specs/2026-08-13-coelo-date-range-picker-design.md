---
source: "Aprovação explícita do Owner Coelo em 2026-08-13; opção A selecionada no companion visual; referências visuais anexadas na conversa; docs/superpowers/specs/2026-08-12-coelo-calendar-date-picker-design.md; docs/design/design-system.md"
status: "approved"
generated_at: "2026-08-13"
---

# Seletor global de período Coelo

## Decisão e precedência

O Coelo adota globalmente a opção A aprovada: uma família única formada por
campo compacto de período e calendário de intervalo com faixa contínua. O
padrão pertence ao núcleo visual compartilhado e deve ser usado por Admin,
Superadmin e Principal sempre que uma operação exigir início e fim.

Esta decisão amplia o padrão de calendário simples aprovado em
`2026-08-12-coelo-calendar-date-picker-design.md`. Ela substitui somente a
antiga exclusão de "seleção de intervalo com dois calendários". A localização,
os tokens, a navegação por dias/meses/anos e os estados já aprovados continuam
válidos.

## Objetivo e problema

Oferecer uma seleção de período compacta, clara e coerente entre os três apps
privados. O padrão elimina o uso de `showDateRangePicker` Material cru, evita
calendário pequeno perdido em uma superfície desktop enorme e impede variantes
locais com títulos truncados, datas comprimidas ou ações genéricas.

## Escopo

- campo fechado com label persistente `Período`, início, seta, fim e ícone de
  calendário;
- atalhos `Hoje`, `Esta semana` e `Este mês` abaixo do campo curto;
- painel ancorado com dois meses consecutivos quando houver largura expanded ou
  maior e um mês em compact/medium;
- seleção contínua de início, trecho intermediário e fim;
- rascunho, aplicação, limpeza, descarte e navegação por teclado/toque/mouse;
- limites e datas indisponíveis fornecidos pelo consumidor;
- localização pt-BR, light/dark, texto a 200% e reduced motion;
- componente compartilhado, catálogo, índice, testes e goldens focados.

## Fora de escopo

- agenda, recorrência, horário, fuso selecionável, feriados ou disponibilidade
  calculada pelo componente;
- autorização, tenant, RLS ou regra de domínio de uma feature;
- migração indiscriminada de todos os usos legados na mesma entrega;
- variante Astro antes de existir o pacote web canônico;
- presets adicionais configuráveis sem consumidor aprovado.

## Superfícies, dados e permissões

O padrão é visual e sem domínio. Recebe e devolve um `DateTimeRange?` composto
por datas normalizadas sem horário. Também recebe data mínima, data máxima e um
predicado opcional de disponibilidade. Não acessa repository, rota, sessão,
tenant, instituição, pessoa, criança ou qualquer dado pessoal.

Autorização e validação persistente continuam no backend/RLS da feature. O
controle não concede acesso, não decide escopo de tenant e não substitui a
validação server-side.

## Componentes avaliados

- `pattern.calendar-date-picker` preserva a identidade aprovada, mas cobre
  somente data única e ainda não possui componente Flutter canônico.
- `showDatePicker` e `showDateRangePicker` são explicitamente rejeitados pelo
  contrato visual e pelo validador administrativo.
- campos locais ou dois inputs independentes tornam a leitura do intervalo mais
  pesada e não representam a opção aprovada.

Por ser neutro e global, o proprietário é `packages/coelo_ui_core`. Os apps
consumidores não copiam o widget e o Principal não importa `coelo_ui_admin`.

## Anatomia visual aprovada

### Campo compacto

- label persistente `Período`;
- valores em `dd/MM/yyyy`, separados por seta direcional;
- ícone de calendário no final;
- altura mínima `CoeloSize.touchMin`;
- estado aberto/foco com contorno `colorScheme.primary` de 2 px;
- atalhos abaixo do campo, com superfície neutra, contorno
  `outlineVariant`, raio `CoeloRadius.full` e gaps `CoeloSpacing.space2`;
- `Hoje`, `Esta semana` e `Este mês` aplicam o período imediatamente.

### Painel aberto

- base `colorScheme.surface`, conteúdo `onSurface`, borda `outlineVariant`,
  `surfaceTintColor: Colors.transparent`, `CoeloRadius.lg` e elevação Coelo;
- título localizado como `Agosto de 2026`, nunca `2026 Ago` ou `Ago 2026`;
- semana `Dom`, `Seg`, `Ter`, `Qua`, `Qui`, `Sex`, `Sáb`;
- em expanded ou maior, dois meses consecutivos lado a lado; em compact e
  medium, um mês por vez, sem comprimir a grade;
- setas externas navegam meses e o título preserva a navegação hierárquica para
  meses e anos do calendário simples;
- início e fim usam `primary/onPrimary` em círculos; dias intermediários usam
  uma faixa contínua `primaryContainer/onPrimaryContainer`;
- hoje não selecionado usa contorno `primary`; dias adjacentes usam
  `onSurfaceVariant` atenuado; indisponíveis permanecem distintos;
- rodapé separado com `Limpar` como ação terciária e `Aplicar período` como
  única ação primária.

## Estados e comportamento

1. Abrir copia o valor confirmado para um rascunho e posiciona o calendário no
   início do período, ou na data atual quando vazio.
2. O primeiro dia válido inicia o rascunho. A faixa prospectiva aparece em
   hover ou foco até a escolha do fim.
3. Um segundo dia igual ou posterior conclui o rascunho. Um dia anterior
   reinicia o início, sem inverter valores silenciosamente.
4. `Aplicar período` só habilita com início e fim válidos e chama `onChanged`
   uma única vez.
5. `Limpar` remove o rascunho; a remoção só é confirmada por `Aplicar período`.
6. `Esc`, clique externo ou dismiss descartam o rascunho e devolvem o foco ao
   campo de origem.
7. Cada atalho calcula e confirma imediatamente o período local:
   `Hoje` = hoje; `Esta semana` = domingo a sábado; `Este mês` = primeiro ao
   último dia do mês atual.
8. Um atalho fica indisponível quando qualquer data do período viola mínimo,
   máximo ou predicado; o período nunca é recortado silenciosamente.
9. Uma tentativa de atravessar data indisponível mantém o rascunho incompleto e
   anuncia `O período contém datas indisponíveis` em região semântica.

Estados obrigatórios: fechado, aberto, repouso, hover, foco, pressionado,
primeiro dia, faixa prospectiva, intervalo confirmado, hoje, adjacente,
indisponível, mínimo/máximo, vazio, erro e disabled.

## API pública mínima

`coelo_ui_core` expõe somente:

- `CoeloDateRangeField`, responsável pelo campo curto, atalhos e abertura do
  overlay;
- `CoeloDateRangePicker`, painel controlado e reutilizável pelo catálogo e por
  superfícies que já forneçam a própria shell aprovada;
- `showCoeloDateRangePicker`, adaptador ancorado responsável por safe area,
  descarte e retorno de foco.

Parâmetros públicos mínimos: `value`, `onChanged`, `firstDate`, `lastDate`,
`selectableDayPredicate`, `currentDate`, `enabled`, `errorText` e
`showQuickRanges`. `currentDate` é injetável para testes determinísticos e usa
a data local quando omitido. Os textos canônicos permanecem internos e
localizados; não existe API especulativa para presets arbitrários.

## Responsividade

- a decisão de um ou dois meses usa as constraints reais do painel e os
  breakpoints `CoeloBreakpoints`, não a largura global presumida;
- o painel preserva inset mínimo `CoeloSpacing.space2` além da safe area e pode
  reposicionar acima do campo quando faltar espaço inferior;
- compact/medium exibem um mês sem scroll horizontal e mantêm todos os alvos em
  48 px;
- texto a 200% empilha o rodapé quando necessário, sem truncar título, datas ou
  ações;
- desktop nunca usa fullscreen; mobile nunca comprime dois meses lado a lado.

## Acessibilidade e teclado

- semântica de data completa, início, fim, hoje, indisponível e pertencimento à
  faixa;
- setas movem por dia/semana conforme o eixo, Page Up/Down navega meses,
  Enter/Espaço selecionam, `Esc` descarta e retorna foco;
- foco visível por tokens Coelo e paridade entre mouse, teclado e toque;
- anúncio de mudança de mês, início escolhido, período concluído e erro;
- ordem de foco previsível, alvo mínimo de 48 px, contraste WCAG 2.2 AA e
  animação não essencial removida com reduced motion.

## Erros, eventos, logs e notificações

Erro de campo pertence ao formulário consumidor. Erros temporários de seleção
ficam no painel sem alterar o valor confirmado. O componente não dispara rede,
notificação, analytics ou log de auditoria. A feature consumidora decide eventos
de produto e persistência somente após receber o valor confirmado.

## Catálogo, índice e memória

- ampliar `pattern.calendar-date-picker` com a variante `range` e os estados de
  rascunho/faixa;
- adicionar exemplos `date-range-open` e `date-range-short` ao catálogo;
- atualizar o contrato `calendar-date-picker-contract.md` para tornar esta
  especificação obrigatória;
- registrar somente a decisão durável na projeção `docs/knowledge/team`, após a
  fonte canônica;
- manter as imagens anexadas como inspiração histórica; o golden do componente
  real será a evidência persistente aprovada.

## Testes e goldens

Testes comportamentais devem cobrir abertura/fechamento, rascunho, reinício por
data anterior, aplicação única, limpeza, descarte, presets, limites,
indisponibilidade, teclado, semântica e retorno de foco.

Goldens focados mínimos:

- `coelo_date_range_picker_open_selected_light_1024.png`;
- `coelo_date_range_picker_open_selected_dark_1440.png`;
- `coelo_date_range_picker_compact_selected_light_375.png`;
- `coelo_date_range_field_short_light_768.png`;
- `coelo_date_range_picker_preview_hover_light_1024.png`;
- `coelo_date_range_picker_focus_light_1024.png`;
- `coelo_date_range_picker_today_light_1024.png`;
- `coelo_date_range_picker_disabled_light_1024.png`.

Também validar 375, 768, 1024 e 1440 px, light/dark, texto a 200%, reduced
motion, análise estática, testes do índice/catálogo e o validador visual
administrativo.

## Critérios de aceite

- Admin, Superadmin e Principal conseguem consumir a mesma API de
  `coelo_ui_core` sem dependência entre apps;
- dois meses aparecem somente quando cabem; um mês permanece íntegro no
  compacto;
- o campo curto e os três atalhos reproduzem a anatomia aprovada;
- faixa, início, fim, hoje e indisponibilidade são distinguíveis sem depender
  apenas de cor;
- nenhum uso novo de `showDateRangePicker` ou picker local é introduzido;
- catálogo, índice, contrato, testes e goldens apontam para a mesma anatomia;
- o componente não contém regra de tenant, autorização, disponibilidade ou
  persistência de domínio.

## Riscos e decisões encerradas

- Datas são normalizadas no calendário local para evitar horário residual; a
  feature continua responsável por converter o valor ao contrato de backend.
- Percorrer um período inteiro para validar o predicado deve interromper no
  primeiro dia inválido e respeitar os limites fornecidos.
- O overlay mede o espaço real e reposiciona; não depende de fullscreen ou de
  uma largura fixa.
- Não há pergunta aberta nesta proposta. A opção A e o alcance global foram
  aprovados explicitamente pelo Owner em 2026-08-13.
