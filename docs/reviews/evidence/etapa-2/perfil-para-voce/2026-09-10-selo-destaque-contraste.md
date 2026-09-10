---
title: "Selo DESTAQUE de Para Você: contraste medido nos dois temas e correção pronta"
source: "Cálculo WCAG sobre as cores reais da composição (packages/coelo_tokens/lib/src/coelo_theme.dart e coelo_palette.dart) e medição do impacto em golden na rodada noturna de 2026-09-09/10"
status: "measured; correção NÃO aplicada, aguardando decisão de coelo-ui e do Owner"
generated_at: "2026-09-10"
---

# O que foi medido

O selo do herói de Para Você renderiza `item.type.label.toUpperCase()` — "DESTAQUE",
"CONTEÚDO", "PARA VOCÊ" — em `scheme.onPrimary` sobre um véu
`scheme.onPrimary.withValues(alpha: .16)`, dentro de um cartão cuja cor é
`scheme.primary`. O arquivo é
`apps/superadmin/lib/features/principal_for_you/presentation/principal_for_you_preview_page.dart`.

Contraste calculado pela fórmula WCAG 2.x sobre as cores compostas:

| Tema | Cartão | Véu | Texto | Fundo composto | Contraste | AA 4,5:1 |
| --- | --- | --- | --- | --- | ---: | --- |
| claro | `orange500` `#D63C00` | branco 16% | branco | `rgb(221, 91, 41)` | **3,75:1** | **falha** |
| escuro | `orange300` `#FF9B78` | `orange950` 16% | `orange950` | `rgb(223, 133, 101)` | **6,25:1** | passa |

O defeito é **só do tema claro**. Isso não estava no registro anterior, que
tratava o selo como um problema único.

## A causa é estrutural, não escolha de valor

No tema claro o véu e o texto são a **mesma cor**: `scheme.onPrimary` é branco
nos dois papéis. Qualquer véu branco aproxima o fundo do selo da cor do texto.
Curva medida, variando só o alfa:

| alfa | contraste |
| ---: | ---: |
| 0,00 | 4,66 |
| 0,08 | 4,21 |
| 0,16 (atual) | 3,75 |
| 0,24 | 3,32 |

**Não existe alfa de véu branco que resolva.** Só remover o véu, e isso apaga o
selo.

## Correção proposta

Inverter o véu para o tom escuro da própria marca, que é o que o tema escuro já
faz — lá `onPrimary` é `orange950` e por isso ele passa.

| véu proposto | fundo composto | contraste |
| --- | --- | ---: |
| `orange950` 16% sobre `orange500` | `rgb(188, 53, 0)` | **5,75:1** |

Passa com folga, usa token de paleta existente, mantém o selo visível e torna os
dois temas simétricos na intenção: véu escuro sob texto claro, véu claro sob
texto escuro.

## Por que não foi aplicada

O token é `scheme.onPrimary`, compartilhado por todo o produto. Trocar qual
papel de esquema o selo usa é decisão de `coelo-ui`, não preferência de executor.

E o custo foi **medido, não herdado**: aplicando a troca e rodando
`principal_for_you_preview_golden_test`, **13 de 13 casos falham**. A alteração
foi revertida e a árvore conferida limpa.

## A decisão

Entre uma tela que não cumpre AA no tema claro e treze referências aprovadas que
precisam ser regravadas. Com o número dos dois lados, que era o que faltava.

Vale a regra que esta rodada estabeleceu para rebaseline: antes de regravar,
perguntar se a captura nova exercita o que a antiga exercitava. Aqui exercita —
a mudança é de cor do véu, não de composição — então regravar é seguro quanto a
cobertura, desde que a decisão de cor tenha sido tomada primeiro.
