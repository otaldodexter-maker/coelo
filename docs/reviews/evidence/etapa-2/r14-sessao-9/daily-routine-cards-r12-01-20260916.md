---
source: "Sessão 9 da R14 (Opus 5), 16/09/2026; ADR 0041 C3 (owner.r12-01) e B1; coelo-ui (fluxo administrativo: conceito de família implementado uma vez no componente compartilhado)"
status: evidence
generated_at: 2026-09-16
---

# Rotina diária › Modelos (`daily-routine.list`) — cards de altura uniforme, "Efetivo: —" e Arquivar em todos (owner.r12-01), 16/09/2026

Trabalho **local** (worktree `r14/visual-arquivar`); rota real indisponível (PostgREST 504). Prova FE por teste de
widget e golden; nenhum estado por `action_id` alterado.

## Defeito observado (referência antiga)

`capturas/rotina-cards-1440-antes.png` (golden regravado na fatia 1, ainda com o defeito que o Owner apontou): a
grade era um `Wrap` com `minHeight: 216` por card — o tile "Criar modelo" ficava mais baixo que os cards com
ações, cards sem "Efetivo" ficavam mais baixos que os vizinhos, a linha "Efetivo" só aparecia quando havia valor e
"Arquivar" não aparecia (o harness não passava `onArchive`; na rota real o item arquivado não tinha ação nenhuma).

## Correção (coelo-ui)

- `packages/coelo_ui_admin/lib/src/directory/coelo_admin_card_grid.dart`: `CoeloAdminCardGrid` — a grade de linhas
  com altura uniforme que já existia **privada** dentro de `CoeloAdminDirectory` (`_CardGrid`: `Table` com
  `intrinsicHeight` por linha, `_RowStretch`) vira widget público; o composto passa a delegar a ele (sem mudança de
  comportamento: `coelo_ui_admin` 158/158; Perfis de acesso, consumidor do composto, golden 20/20 verde).
- `apps/superadmin/lib/features/daily_routine/daily_routine_pages.dart`: `_cards` usa `CoeloAdminCardGrid`
  (tile Criar como `leading`, mesma linha e mesma altura); linha `Efetivo: ${item.effectiveLabel ?? '—'}` sempre
  presente (`Key('daily-routine-effective-<id>')`); `_lifecycleActions` expõe **Arquivar** em todo modelo/rotina
  não arquivado e **Restaurar** no arquivado (ADR 0041 B1), com diálogo de confirmação e recarga da página após
  sucesso; novo callback `onRestore` ao lado de `onArchive`. O comportamento de servidor (RPC, versão, auditoria,
  filtro "Arquivados") é a fatia 3.

## Prova

`test/features/daily_routine/daily_routine_directory_cards_test.dart` (4/4):

| Ponto C3 | Teste | Asserção |
|---|---|---|
| altura uniforme | `cards and the create tile share the row height` | `getSize` do tile Criar e de dois cards (com e sem Efetivo) na mesma linha em 1440: alturas iguais (≥216) e larguras iguais |
| "Efetivo: —" | `every card renders the Efetivo line, with an em dash when empty` | `Efetivo: Instituição` no card com valor; `Efetivo: —` nos dois sem valor |
| Arquivar em todos | `Arquivar appears on every active card and Restaurar on the archived one` | 2 × `Arquivar` (ativo e rascunho), 1 × `Restaurar` (arquivado); confirmar chama o callback e recarrega (`pageQueries + 1`); cancelar não chama |
| sem callback | `without archive callbacks the lifecycle actions stay hidden` | nenhuma ação de ciclo de vida sem `onArchive`/`onRestore` |

Pasta `test/features/daily_routine`: **119/119 (+4 skips pré-existentes)**. Golden regravado após a fatia 1
(cabeçalho verde): `daily_routine_directory_cards_light_1440.png`, `daily_routine_directory_card_hover_light_1440.png`
(grade + Efetivo + Arquivar/Restaurar; harness passa `onArchive`/`onRestore`) e
`daily_routine_directory_table_light_1440.png` (coluna Ações ganha Arquivar/Restaurar em todas as linhas — 1.098 px
na coluna x 1245–1263). `capturas/rotina-cards-1440-depois.png`: seis cards e o tile Criar com a mesma altura por
linha, "Efetivo: —" em Médio e Maternal, Arquivar em cinco e Restaurar no arquivado.

## Estado

`owner.r12-01` → `partial / FE local-green`. Pendente: rota real (captura em 1440 e reload), e a fatia 3 (B1) para
Arquivar/Restaurar terem efeito em produção.
