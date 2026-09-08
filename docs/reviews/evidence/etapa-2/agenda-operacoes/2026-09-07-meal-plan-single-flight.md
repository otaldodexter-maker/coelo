---
title: "Cardápios — comando único durante persistência"
source: "meal_plan_wizard_page.dart; development_meal_plan_wizard_test.dart; revisão independente"
status: "local-green; E2E aberto"
generated_at: "2026-09-07"
---

# Recorte e causa

Salvar rascunho e Enviar e publicar no wizard de Cardápios. O footer desabilitava seus botões após rebuild, mas `_persist` não recusava callbacks repetidos antes desse rebuild. Duas variantes RED (primeiro salvar ou primeiro publicar) observaram três chamadas de gravação onde deveria existir uma. Isso também substituía a geração do comando que já estava em andamento.

## Correção e verificação

Um guard no início de `_persist` recusa a operação quando a página foi descartada ou já está salvando. Ele precede a validação e o acesso a controllers. Não há mudança de protocolo, payload, chave de idempotência, mídia ou backend.

As duas variantes exercitam callback repetido no mesmo frame, callback da ação concorrente, callback retido após rebuild durante pendência e callback após dispose. Confirmam uma gravação e somente a cadeia de revisão/publicação escolhida na primeira ação.

- RED: 2/2 falhas por contagem 3 em vez de 1 antes da correção.
- Wizard completo: 11/11 PASS.
- Regressão data + wizard + diretório: 34/34 PASS.
- Analyzer dos dois arquivos: PASS.
- Validador de contratos visuais: PASS.
- Revisão independente read-only: sem blocker.
- `git diff --check`: PASS.

## Limites

Single-flight local não substitui idempotência/autorização server-side. O fake de publicação existente valida a sequência de chamadas, não seu status final; a validação do estado publicado é uma pendência distinta. Falhas após save confirmado e antes da publicação também permanecem fora deste pacote. Nenhum teste SQL ou runtime produtivo foi executado. Memória de conhecimento: no-op, sem nova regra aprovada de produto.
