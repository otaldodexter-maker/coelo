---
source: R12 C0 — R12-04 history separation diagnostic
status: blocked-product-route; no code change
generated_at: 2026-09-13
---

# R12-04 — separação do Histórico de chamadas

Recorte: Etapa 2 → `apps/superadmin` → Acompanhamento → Rotina diária →
diretório → `daily-routine.list`/`attendance.dashboard`.

O código atual ainda oferece as abas `Modelos`, `Rotinas` e `Lançamentos` no
diretório de Rotina diária. A aba de Lançamentos é funcionalmente usada pelo
fluxo D7: criar o rascunho de hoje muda para `RoutineEntryKind.launch`, e a
lista permite publicar o lançamento. Os testes existentes cobrem essa cadeia
em `daily_routine_production_page_test.dart`,
`daily_routine_create_everywhere_test.dart` e
`daily_routine_publish_launch_test.dart`.

Não foi encontrada uma rota/tela separada de `Histórico de chamadas` no
Superadmin que possa receber essa responsabilidade. Remover a aba agora
quebraria a cadeia D7 e deixaria os lançamentos sem superfície de consulta;
criar uma tela ou action_id novo excederia o apontamento do Owner. O dashboard
de Assiduidade também não foi removido por inferência.

Nenhum código, contrato, RPC ou rastreador de ação foi alterado nesta
triagem. R12-04 permanece aberto até haver decisão/rota aprovada para o
Histórico, com leitura autorizada, tabela, filtros, reload e escopo.

Próximo gate: definir a tela/rota canônica e o mapeamento com
`attendance.dashboard`; então mover a consulta sem perder o fluxo D7 nem
alterar o denominador por criação de action_id implícito.
