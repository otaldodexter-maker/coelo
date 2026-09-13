---
source: R12 C0 — triagem do próximo gate R12-01
status: blocked-diagnostic; no product change
generated_at: 2026-09-13
---

# R12-01 — diagnóstico dos goldens de Rotina diária

Recorte: Etapa 2 → `apps/superadmin` → Acompanhamento → Rotina diária →
Modelos → `daily-routine.list`.

Execução local Windows:

- `flutter test test/features/daily_routine/daily_routine_golden_test.dart
  test/features/daily_routine/daily_routine_table_status_test.dart`;
- os testes de golden falharam em múltiplos estados, com diferenças de 194 px
  em alguns estados e aproximadamente 3 mil px nos diretórios/formulários;
- a imagem `isolatedDiff` do diretório tabela mostra diferenças somente no
  cabeçalho global do Superadmin (avatar/ícones/texto sobreposto), fora da
  composição de Rotina diária e do recorte R12-01;
- nenhuma implementação, golden ou dado foi alterado nesta triagem.

Conclusão: a falha é uma pendência visual global/ambiental a reconciliar com a
referência do cabeçalho antes de usar esses goldens como prova. Não é seguro
regenerar os baselines nem atribuir a diferença ao card de modelos. R12-01
continua aberto; o próximo gate deve comparar a tela em referência autorizada,
incluindo alturas/rodapés e ações alinhadas, depois de estabilizar o cabeçalho.
