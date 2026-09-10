---
title: "Proposta medida — alvo de toque do indicador de status de Instituições"
source: "residual de estrutura assumido às 23:30; varredura de alvos menores que 48"
status: "proposta; medida e NÃO aplicada, porque move goldens aprovados"
generated_at: "2026-09-09"
group: "operacoes-sistema (residual estrutura)"
---

# Alvo de toque do indicador de status de Instituições

## O defeito

`ExpandableInstitutionStatusIndicator`, em
`apps/superadmin/lib/features/institutions/presentation/widgets/institution_status_presentation.dart`,
é um controle tocável — `GestureDetector` com `onTap`, dentro de `Semantics` com
`button: true` — e mede **24 × 24** no estado recolhido. `androidTapTargetGuideline`
exige 48.

Está corretamente **rotulado** ("Status: Ativa" e afins). O problema é só tamanho.

A altura é a restrição real: ela é fixa em `CoeloSpacing.space6`, ou seja 24,
**mesmo quando expandido** — a animação cresce só a largura, de 24 para cerca de 56.

## A mudança que eu medi

```dart
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expandedByTap = !_expandedByTap),
            child: SizedBox(
              height: CoeloSize.touchMin,
              child: Center(child: TweenAnimationBuilder<double>(
                // ... corpo inalterado
              )),
            ),
          ),
```

O pill continua com 24 de altura e fica centralizado numa caixa transparente de
48. `HitTestBehavior.opaque` faz a caixa inteira receber o toque.

## Por que NÃO foi aplicada: a medição

Capturei as porcentagens de diferença dos goldens de Instituições **antes** e
**depois**, na mesma máquina e na mesma base. O resultado é inequívoco:

| Golden | Antes | Depois |
| --- | ---: | ---: |
| `institution_directory_cards_light_1440` | 14,13% | 15,29% |
| `institution_directory_cards_light_1024` | 14,87% | 16,10% |
| `institution_directory_cards_dark_1440` | 14,50% | 15,66% |
| `institution_directory_cards_dark_1024` | 15,68% | 16,90% |
| `institution_directory_card_hover_light_1440` | 14,62% | 15,73% |

E o número de goldens falhando subiu de **32 para 36**. Os quatro novos:

- `institution_directory_files_hover_light_1440`
- `institution_directory_filter_option_hover_light_1440`
- `institution_directory_logout_hover_light_1440`
- `institution_directory_status_expanded_light_1440`

Ou seja: a caixa de 48 aumenta a altura da linha do cartão onde a coluna vizinha
era mais baixa, e isso reflui o cartão inteiro. **Não é mudança invisível.**

A alternativa que manteria a pegada de layout — `OverflowBox` com a pegada em 24
e o alvo em 48 — não serve aqui porque a expansão por foco e toque hoje empurra os
vizinhos; pinar a pegada mudaria esse comportamento, que é parte da composição
aprovada.

## Recomendação

Decisão do Owner com `coelo-ui`, junto com as outras quatro da mesma natureza —
cartão de Planos, célula de Cardápios, célula do calendário de Agenda e a tabela
administrativa. Todas trocam pixel aprovado por conformidade de acessibilidade, e
nenhuma tem versão invisível.

Peso para priorizar: este é o **menos** severo do conjunto. É alvo de toque
pequeno num controle que está rotulado, alcançável por teclado e cuja informação
também aparece no próprio cartão. Não há perda de função nem de informação — só o
alvo é menor que o mínimo.
