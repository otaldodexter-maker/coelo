---
title: "Tabela administrativa sem rolagem vertical — causa raiz de duas suítes vermelhas"
source: "execução própria do grupo operacoes-sistema sobre a base d784462c1"
status: "diagnóstico; nenhuma alteração aplicada em pacote compartilhado"
generated_at: "2026-09-09"
group: "operacoes-sistema"
branch: "work/etapa2-noturna-operacoes-sistema"
---

# Tabela administrativa sem rolagem vertical

## O que estava vermelho

Duas suítes falhavam com a mesma assinatura de overflow, e eu havia entregado a
primeira sem resolver:

- `app/router/import_development_routes_test.dart`
- `app/router/prototype_navigation_routes_test.dart`

A segunda também passa por `/dev/imports` na sua lista de destinos, o que já
sugeria causa comum.

## Isolamento

Um teste descartável abriu cada rota isoladamente, a 1440x900, sem transição
entre rotas:

- `/dev/imports/new` — passa.
- `/dev/imports` — **falha sozinho**, com `RenderFlex overflowed by 1069 pixels`.

Isso eliminou a transição de rota como causa e apontou o diretório.

## Causa

`CoeloAdminResizableTable._tableBody`, em
`packages/coelo_ui_admin/lib/src/table/coelo_admin_resizable_table.dart`:

```dart
SingleChildScrollView(
  scrollDirection: Axis.horizontal,   // rola apenas na horizontal
  child: SizedBox(
    width: tableWidth,
    child: Column(
      mainAxisSize: MainAxisSize.min, // crossAxisAlignment fica no padrão: center
      children: [_headerRow(context), ...widget.items.map(...)],
    ),
  ),
)
```

A rolagem é **horizontal**, então a restrição vertical continua limitada. A
`Column` empilha cabeçalho e todas as linhas recebidas e não tem para onde
rolar. Isso bate exatamente com o flex relatado pelo Flutter: largura 1190,
altura limitada a 612, `mainAxisSize: min`, `crossAxisAlignment: center`.

A aritmética fecha: `56` de cabeçalho mais `25` linhas de `64 + 1` dá `1681`, e
`1681 - 612 = 1069`, o overflow exato.

O diretório de Importações entrega 25 linhas à tabela — o repositório de
desenvolvimento semeia 34 registros. A página as coloca em
`Expanded(child: CoeloAdminResizableTable(...))`, que limita a altura sem
oferecer rolagem vertical.

## Por que importa além do teste

As linhas abaixo do corte não estão apenas clipadas: **não há como alcançá-las**.
Não existe rolagem vertical nem na tabela nem em volta dela. A coluna fixada
reforça o diagnóstico, porque é posicionada com
`height: headerHeight + items.length * (rowHeight + 1)`, ou seja, a altura total
do conteúdo, e não a altura disponível.

O mesmo padrão `Expanded` + `CoeloAdminResizableTable` é usado por vários
diretórios administrativos. Eles não falham hoje porque entregam menos linhas —
Planos usa página de 11. É risco latente: basta a página crescer, a altura da
linha aumentar ou o texto ampliar para 200% para o mesmo overflow aparecer.

## O que NÃO foi feito, e por quê

Nada foi alterado. A correção pertence a um pacote compartilhado do Design
System, com alcance sobre todos os diretórios administrativos, e não é de uma
linha: a coluna fixada é desenhada num `Stack` com posicionamento absoluto, de
modo que introduzir rolagem vertical exige sincronizar os dois eixos entre o
corpo e a coluna fixada. Isso é decisão de `coelo-ui` e da coordenação, não de
um executor de recorte.

Alternativa mais barata, se a decisão for adiar o componente: limitar a página
de Importações a um número de linhas que caiba no quadro, como os outros
diretórios já fazem. Isso resolve as duas suítes vermelhas sem tocar no pacote,
mas deixa o risco latente de pé para as demais telas.
