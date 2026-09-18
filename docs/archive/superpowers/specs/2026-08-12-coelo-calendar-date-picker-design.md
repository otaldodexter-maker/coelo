---
source: "Aprovação explícita do Owner Coelo em 2026-08-12; referências visuais anexadas na conversa; docs/design/design-system.md"
status: "approved"
generated_at: "2026-08-12"
---

# Calendário e seletor de data Coelo

## Objetivo

Oficializar como obrigatório o calendário compacto aprovado pelo Owner, com a
mesma hierarquia de navegação por dias, meses e anos das referências fornecidas,
localização integral em português do Brasil e identidade cromática Coelo.

## Escopo

Atualizar a skill `coelo-ui` para tornar o padrão pesquisável e vinculante. A
mudança inclui contrato visual dedicado, roteamento na skill, entrada no índice,
teste de descoberta e projeção de conhecimento durável. Não inclui implementar
ou migrar componentes Flutter nesta etapa.

## Contrato visual

- A visão de dias usa o cabeçalho `Agosto de 2026`: mês por extenso, preposição
  `de` e ano com quatro dígitos. É proibido `2026 Ago`, `Ago 2026` ou nome de mês
  em inglês.
- Os dias da semana aparecem como `Dom`, `Seg`, `Ter`, `Qua`, `Qui`, `Sex` e
  `Sáb`, começando no domingo.
- O cabeçalho permite avançar e retroceder um mês e saltar para o ano anterior
  ou seguinte. Ativar o título alterna para a visão de meses.
- A visão de meses usa o ano como título e uma grade `Jan`, `Fev`, `Mar`, `Abr`,
  `Mai`, `Jun`, `Jul`, `Ago`, `Set`, `Out`, `Nov`, `Dez`. Selecionar um mês
  retorna à visão de dias.
- Ativar o ano abre a visão de anos. Ela usa uma década inclusiva como
  `2020–2029`, com anos adjacentes fora da década em estado atenuado. Selecionar
  um ano retorna à visão de meses.
- A ação `Hoje` fica em rodapé separado e leva ao mês atual, selecionando hoje
  quando a regra do campo permitir.
- O dia selecionado usa `primary`/`onPrimary` do Coelo. Hoje, quando não
  selecionado, usa contorno `primary` e superfície neutra. Dias fora do mês e
  anos adjacentes usam papéis `onSurfaceVariant` atenuados; estados indisponíveis
  permanecem distinguíveis de valores apenas adjacentes.
- A base usa `colorScheme.surface`, `onSurface`, `outlineVariant`, raio,
  elevação e espaçamento semânticos Coelo, com `surfaceTintColor` transparente.
  Roxo, cinza local, HEX isolado e tint Material não pertencem ao padrão.

## Comportamento e acessibilidade

O controle deve oferecer paridade entre mouse, teclado e toque; alvo mínimo de
48 px; foco visível; semântica de data completa; anúncio de visão e seleção;
navegação previsível por setas, Enter e Espaço; `Esc` para fechar quando estiver
em overlay; retorno do foco ao campo de origem; texto a 200%; temas claro e
escuro; e reduced motion para animações não essenciais.

Devem existir estados verificáveis para repouso, hover, foco, pressionado,
selecionado, hoje, fora do período visível, indisponível, mínimo/máximo e
fechado/aberto. Limites de domínio e datas bloqueadas são fornecidos pelo
consumidor e não são inventados pelo componente visual.

## Responsividade e superfícies

O calendário permanece compacto e proporcional no desktop, ancorado ao campo
quando houver espaço. Em viewport estreita, reposiciona ou cresce dentro da safe
area sem truncar cabeçalho, grade ou rodapé. Nunca ocupa uma superfície desktop
enorme com calendário pequeno, nem comprime título e datas. Se inserido em
dialog, reutiliza os contratos Coelo de overlay, fechamento e ações.

## Governança e validação

Criar `pattern.calendar-date-picker` no índice. A `coelo-ui` deve exigir a
leitura do contrato para calendário, date picker, data, mês ou ano usados como
seletores. `showDatePicker` e `showDateRangePicker` crus ficam bloqueados em
novas telas; uma implementação futura exige componente compartilhado no pacote
adequado, catálogo, testes comportamentais e goldens específicos em larguras
375, 768, 1024 e 1440, light/dark e texto a 200%.

## Fora de escopo

- API pública Flutter ou Astro;
- seleção de intervalo com dois calendários;
- regras de feriados, agenda ou disponibilidade de domínio;
- migração dos usos legados existentes.

