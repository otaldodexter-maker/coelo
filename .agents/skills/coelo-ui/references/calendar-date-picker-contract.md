---
source: "packages/coelo_ui_core/lib/src/date_range/coelo_date_range_picker.dart; packages/coelo_ui_core/test/date_range/coelo_date_range_picker_test.dart; apps/catalog/assets/coelo-ui.index.jsonl"
status: "active"
generated_at: "2026-09-08"
---

# Descoberta do calendário Coelo

Referência recuperada a partir da implementação existente; não aprova uma
variante nova. Consultar `CoeloDateRangeField`, `showCoeloDateRangePicker` e
`CoeloDateSelectionMode` em
`packages/coelo_ui_core/lib/src/date_range/coelo_date_range_picker.dart`.
O componente suporta intervalo e data única. Conferir a API antes de usar.

Abrir os testes comportamentais e visuais em
`packages/coelo_ui_core/test/date_range/`. Verificar seleção, limites de datas,
teclado, foco devolvido ao gatilho, desabilitado e responsividade. Ler o golden
do estado afetado, sem atualizar imagens apenas para encobrir divergência.

Reutilizar o componente quando o contrato atender; não introduzir picker
Material cru paralelo. Agenda de eventos é outra superfície. Exemplos de
mês/ano no índice são dados ilustrativos, nunca datas fixas da interface.
O consumidor mantém sua família visual administrativa ou Principal.
