---
title: "Texto a 200% — varredura do recorte operacoes-sistema"
source: "execução própria sobre a base d784462c1"
status: "medição; nenhuma geometria alterada"
generated_at: "2026-09-09"
group: "operacoes-sistema"
---

# Texto a 200% no recorte

WCAG 2.2 AA exige reflow com texto a 200%, e `AGENTS.md` adota WCAG 2.2 AA. As
nove telas de desenvolvimento do recorte foram abertas pelo router real, com
`TextScaler.linear(2)`, em duas larguras.

## Resultado

| Tela | 1440 × 900 | 375 × 900 |
| --- | --- | --- |
| `/dev/audit` | passa | passa |
| `/dev/catalog` | passa | passa |
| `/dev/profile` | passa | passa |
| `/dev/settings` | passa | passa |
| `/dev/home` | passa | passa |
| `/dev/plans` | **falha** | passa |
| `/dev/meal-plans` | passa | **falha** |
| `/dev/agenda` | passa | **falha** |
| `/dev/imports` | **falha** | **falha** |

## O que a matriz mostra e uma largura só não mostraria

Nenhuma das duas larguras, sozinha, encontraria os três defeitos. Planos falha
apenas em 1440; Cardápios e Agenda falham apenas em 375. Testar 200% só no
compacto — que é o hábito, porque parece o caso mais duro — deixaria Planos
passar; testar só no largo deixaria os outros dois passarem.

## Os defeitos, por mecanismo

**Planos, 1440.** Dois transbordamentos distintos. O horizontal foi corrigido em
`ac3238f7c`: `_Metric` era uma `Row` rígida dentro de um `Wrap`. O vertical
permanece: o grid usa `mainAxisExtent: 216` fixo e o conteúdo pede cerca de 470
a 200%. Escalar o extent pelo `textScaler` daria 432, então nem a solução óbvia
fecha sozinha.

**Cardápios, 375.** Transborda 37 pixels. A célula do grid tem altura fixa
`h=343`, igual à largura disponível — proporção quadrada — e o conteúdo pede 380
a 200%.

**Agenda, 375.** O caso mais extenso: 43 exceções de layout numa única abertura.
As células do calendário têm geometria fixa, e as caixas de cerca de 37 × 39,6
transbordam entre 2,4 e 56 pixels; um flex maior transborda 257.

**Importações.** Já diagnosticado à parte: a tabela administrativa não rola na
vertical, e a decisão da coordenação foi não mexer no componente compartilhado
nem esconder o sintoma limitando linhas.

## A classe

Os três primeiros são a mesma classe: **geometria fixa que não acompanha a escala
de texto** — `mainAxisExtent` fixo, proporção quadrada, célula de calendário de
tamanho fixo. Não é falta de `Flexible` num rótulo, que é o que eu corrigi em
Planos; é a moldura que não cresce.

## Nada foi alterado além do rótulo já corrigido

Mudar altura de cartão, proporção de grid ou célula de calendário é contrato
visual de telas com baseline aprovada, e a autoridade é `coelo-ui` com decisão
do Owner. Seguindo o mesmo critério que a coordenação já aplicou ao cartão de
Planos e à tabela administrativa, estas ficam registradas como decisão, não
corrigidas de madrugada.

Também não escrevi teste que trave esse contrato, porque um teste verde exigiria
antes escolher a geometria.
