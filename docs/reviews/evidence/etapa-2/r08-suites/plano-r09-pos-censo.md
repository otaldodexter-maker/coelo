---
fonte: gate C0 R08 ACK200 e ciclo210 accessibility
status: plano R09 pendente; não iniciado
atualizado: 2026-09-12
---

# R09 · plano focal pós-censo para G8

## Objetivo

Validar alterações posteriores ao snapshot do C0 sem disputar o censo completo. O censo integral `flutter test test --concurrency=2` permanece pendente para R09 porque a janela R08 até 15:00 e a memória disponível inferior a 3 GB não comportam uma execução de 35–45 minutos.

## Ordem viável

1. Fixar SHA da base integrada pós-censo e preservar o resultado C0 com `inputSha256`, `done`, exit nativo e contagens reais.
2. Reprocessar o JSONL já existente com `censo-parser.js`, sem Flutter, confirmando `testID`, `suiteID`, `done`, órfãos e erros.
3. Reconciliar o artefato de acessibilidade ciclo210 já concluído pelo C0, usando somente seus arquivos committed; copiar contagens e chaves exatamente, sem inferir aprovação de produto.
4. Selecionar validação focal somente para arquivos alterados após o snapshot, com dono e slot explícitos; não iniciar automaticamente.
5. No fechamento R09, decidir se o censo integral cabe em janela e memória; se não, manter pendente, sem fracionar ou somar reruns.

## Dados preservados

R08 G8: ciclo180 `411 passed, 4 failed, 1 skipped`, `done=false/time=97850`, exit `1`, quatro errors e zero órfãos; resultado versionado com SHA de input. Matriz textual: anônimo `293 observedEvents`, `281 uniqueDisplayKeys`, `12 displayKeyCollisions`; ciclos 30/60/90 `121/238/422`. Esses números não devem ser misturados ao censo R09.

## Entrega R09

Publicar plano, SHA do snapshot, lista de arquivos pós-snapshot, comandos focais, resultados medidos, WIP retido e pendências. Não declarar conclusão global a partir de validação focal, accessibility cycle210 ou parser isolado.
