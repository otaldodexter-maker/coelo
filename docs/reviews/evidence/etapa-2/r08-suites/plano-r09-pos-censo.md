---
fonte: gate C0 R09 e ciclo210 accessibility committed
status: plano pendente; parser executado sobre artefato existente
atualizado: 2026-09-12
---

# R09 · ordem de fechamento e validação focal

## Ordem obrigatória

1. Fixar o snapshot/base integrada do C0 e seu SHA completo.
2. Executar uma única vez o censo completo autorizado, se houver janela e memória; preservar JSONL, exit nativo e resultado do parser. Não iniciar automaticamente nesta branch.
3. Somente após o censo, identificar deltas posteriores ao snapshot.
4. Validar focalmente apenas os arquivos alterados depois do snapshot, com slot e dono explícitos.
5. Fechar com feito, pendente, WIP, SHA e evidências; não somar reruns nem promover parser isolado a cobertura global.

## Ciclo210 já existente

O artefato committed foi reprocessado sem Flutter com `censo-parser.js`: base `1eccbc591d47f962092dba2f083320b28fff768e`, input SHA `9c255abc26ad276b49b7772eb59c84bf6abfdd826e4d9895404b94f5a0d99401`, `done={success:true,time:25017}`, exit `0`, `85 passed`, `0 failed`, `0 skipped`, `4 hidden`, `0 órfãos`, `0 errors`. É evidência focal de accessibility, não censo completo.

## Censo integral pendente

O censo completo permanece separado do ciclo210. O comando planejado é `flutter test test --concurrency=2 --timeout=10m --reporter=json`, em um único processo a partir de `apps/superadmin`, com saída `../../docs/...`. A previsão operacional do C0 é 35–45 minutos; não executar fora do slot.

## Dados preservados

R08 G8 mantém o resultado ciclo180 `411/4/1`, done `false/97850`, exit `1`, quatro erros e zero órfãos; a matriz textual mantém `293 observedEvents`, `281 uniqueDisplayKeys` e `12 displayKeyCollisions`. Não misturar essas contagens com accessibility210 ou com o futuro censo R09.

## Proveniência corrigida do ciclo210

O `git log` first-parent do C0 fixa a base da execução em `ff1be194f2ac00a48aac5abbac7dd838019eb8da` (merge G3 às 14:06:22; execução às 14:10). O commit `1eccbc591` não foi HEAD da execução C0 e não é usado como base do resultado.
