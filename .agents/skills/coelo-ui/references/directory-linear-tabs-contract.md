---
source: "Aprovação visual do Owner Coelo em 2026-08-03; apps/superadmin/lib/shared/presentation/widgets/superadmin_underline_tabs.dart; apps/superadmin/lib/features/people/presentation/person_directory_page.dart; docs/design/design-system.md"
status: "active"
generated_at: "2026-08-03"
---

# Tabs lineares de diretório

`Acessos > Pessoas` é a baseline aprovada para categorias irmãs que filtram o
mesmo diretório sem trocar de página. O padrão é sutil: labels sobre a própria
superfície, linha-base contínua e somente a categoria selecionada em laranja
com underline. Ele não usa cápsula, card, chip ou fundo cinza.

## Quando usar

Use quando três ou mais categorias irmãs preservarem a mesma toolbar, o mesmo
conjunto de resultados e a mesma estrutura de cards/tabela. Exemplos aprovados:
`Todos`, `Equipe institucional`, `Responsáveis`, `Crianças` e `Perfil duplo`.

Não use:

- para Cards/Tabela, que é um toggle segmentado em cápsula;
- para filtros independentes, status ou escolhas curtas, que usam filtros,
  chips ou controles de seleção;
- para destinos com rota, título ou contexto próprios, que usam navegação de
  página;
- quando existirem apenas duas opções binárias de modo.

## Anatomia e composição

- A toolbar ocupa uma faixa própria acima das tabs.
- Entre toolbar e tabs usar `CoeloSpacing.space4`; entre tabs e o conteúdo usar
  `CoeloSpacing.space4`.
- A faixa de tabs permanece transparente sobre `colorScheme.surface` e termina
  em uma linha-base de 1 px em `colorScheme.outlineVariant`.
- Cada tab preserva alvo mínimo de 48 px e padding horizontal
  `CoeloSpacing.space4`.
- Selecionada: label em `colorScheme.primary`, peso 700, com underline inferior
  de 2 px em `colorScheme.primary`.
- Inativa: label em `colorScheme.onSurfaceVariant`, peso 400, sem indicador.
- Em largura compacta, preservar ordem e permitir rolagem horizontal; não
  comprimir labels nem transformar tabs em dropdown silenciosamente.

## Estados interativos

- Hover e foco usam realce tonal primário muito sutil, nunca cinza. Na
  implementação aprovada, o overlay é `primaryContainer` com alpha `.48`.
- O realce ocupa o alvo da tab sem criar uma cápsula persistente; o underline
  continua sendo o principal sinal de seleção.
- Pressed mantém a família primária. Disabled, quando existir, não recebe hover.
- Foco de teclado precisa ser visível além da cor; mouse, teclado e toque devem
  selecionar a mesma categoria.
- Cada tab expõe semântica de botão e estado `selected`; a mudança de categoria
  deve ser anunciável e não pode depender só do underline.

## Implementação canônica atual

No Superadmin, reutilizar `SuperadminUnderlineTabs<T>` e
`SuperadminUnderlineTab<T>` de
`apps/superadmin/lib/shared/presentation/widgets/superadmin_underline_tabs.dart`.
Não recriar `TabBar`, `InkWell` ou indicadores locais dentro de uma feature
enquanto esse compartilhado atender. Ele é uma composição compartilhada do
Superadmin, não uma API pública de `coelo_ui_admin`.

O exemplo real permanece em `Acessos > Pessoas`, no
`people-segment-selector`. A tela não deve ser alterada para documentar o
padrão; seus testes e o widget compartilhado são a evidência executável.
