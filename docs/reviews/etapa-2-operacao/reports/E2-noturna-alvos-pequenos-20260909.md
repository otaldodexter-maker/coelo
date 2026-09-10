---
title: "Alvos de toque menores que 48 — três causas identificadas"
source: "execução própria do grupo operacoes-sistema sobre a base d784462c1"
status: "medição e proposta; nada alterado em arquivo reservado ou em pacote do Design System"
generated_at: "2026-09-09"
group: "operacoes-sistema"
---

# Alvos de toque menores que 48

`androidTapTargetGuideline` reprovou seis telas: `/dev/circulars`, `/dev/forms`,
`/dev/imports`, `/dev/institutions`, `/dev/notices` e `/dev/safety`. Esse eixo é
objetivo — tamanho em dp, sem interpretação de árvore.

Usando o mesmo caminhador de semântica que identificou o nó sem rótulo, desta vez
coletando nós com ação de toque e lado menor que 48, as causas são **três**, e duas
são compartilhadas.

## 1. Menu do usuário no shell — 242 × 44, presente em toda tela COM shell

`apps/superadmin/lib/app/shell/superadmin_shell.dart`, por volta da linha 1670.
O `InkWell` com chave `superadmin-profile-menu` tem 44 de altura:
`CircleAvatar(radius: 18)` dá 36, mais `CoeloSpacing.space1` de padding vertical
em cima e embaixo dá 44. Faltam 4.

Aparece em **todas** as telas com shell, então é a causa mais espalhada.

### Hunk proposto — shell é reserva do coordenador

```dart
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoeloSpacing.space2,
                  vertical: CoeloSpacing.space2, // era space1: 36 + 8 = 44, faltavam 4
                ),
```

**Consequência visual, declarada:** o alvo passa a 52 de altura, acima do mínimo.
O `InkWell` pinta o realce sobre a própria caixa, então o realce de hover e de
pressão cresce 8 pixels na vertical, e os goldens do shell se movem. Não é
mudança invisível como a do rótulo — por isso vai como proposta, não como commit.

Alternativa sem crescer o realce: manter o padding e envolver em
`SizedBox(height: CoeloSize.touchMin)` **fora** do `InkWell`. Isso não resolve: o
alvo continua sendo a caixa do `InkWell`.

## 2. Alças de redimensionar coluna — 12 × 56, no pacote do Design System

`packages/coelo_ui_admin/lib/src/table/coelo_admin_resizable_table.dart`, linha
241. Cada alça é rotulada corretamente — "Redimensionar coluna Tipo" — mas tem
**12 de largura**, contra 48 exigidos. Sete alças em `/dev/notices`, duas ou mais
em `/dev/circulars`, e o mesmo em qualquer tela que use a tabela com muitas
colunas.

Não alterado: é o mesmo pacote do Design System cuja rolagem vertical a
coordenação já decidiu não mexer de madrugada. Ampliar a área de toque de uma alça
de 12 para 48 sem sobrepor colunas vizinhas exige decisão de composição.

Vale notar que alça de redimensionamento é affordance de ponteiro. Se a decisão
for que ela não precisa de alvo tátil, o caminho honesto é declarar isso e
excluí-la da semântica de toque — não deixá-la reprovando indefinidamente.

## 3. Indicadores de status — 24 × 24, em Instituições

Cinco nós de 24 × 24 com ação de toque e rótulos como "Status: Em implantação" e
"Status: Suspensa", no diretório de Instituições. Pertence a estrutura; não
investiguei o widget.

## O que isto não é

Não é revisão de nenhuma das seis telas. Não verifiquei se `/dev/forms`,
`/dev/imports` e `/dev/safety` reprovam pelas mesmas três causas ou por outras —
investiguei três telas e encontrei três causas, duas delas compartilhadas e
portanto prováveis nas demais.
