---
title: "D02 ActivityAggregateConcurrency — resultado local"
source: "Saída observada da ferramenta exec, sessão 87623, 09/09/2026 14:21–14:25 BRT; assignment D00 r17"
status: "local-red; cleanup-confirmed"
generated_at: "2026-09-09"
---

O transcript PowerShell ao lado é parcial: não capturou a saída nativa do reset/pgTAP que a ferramenta exec exibiu. O bloco abaixo é uma transcrição dessa saída observada, não uma nova execução nem log bruto exportado pelo pgTAP.

```text
Applying migration 20260908154257_superadmin_activity_save_v2.sql...
Restarting containers...
Finished supabase db reset on branch main.
# Failed test 35: "unit and group swap prunes blockers and reports the child-derived final version"
# Failed test 36: "unit and group swap strictly ends old parents before adding the new chain"
# Failed test 37: "unit and group swap removes old professionals and settings"
# Failed test 38: "complex swap replays without rerunning prune stages"
#     (test result was NULL)
# Failed test 39: "complex swap request cannot be reused with another payload"
#         have: SAI_INTERNAL_ERROR
#         want: SAI_CONCURRENT_CHANGE
# Failed test 40: "late invalid participant fails after structural staging"
#         have: SAI_INTERNAL_ERROR
#         want: ACTIVITY_INVALID_INPUT
# Looks like you failed 6 tests of 46
Failed 6/46 subtests
Files=1, Tests=46, 1 wallclock secs (0.02 usr 0.03 sys + 0.01 cusr 0.02 csys = 0.08 CPU)
Result: FAIL
safe local pgTAP failed with exit code 1
```

P40/F6/E46/N46. Os três cenários de concorrência ficaram bloqueados pelo abort do pgTAP, sem execução. O comando nominal, a árvore e os hashes constam no handoff r13. Cleanup posterior por `docker ps -a`, `docker volume ls --filter name=coelo_safe_` e `docker network ls --filter name=coelo_safe_`: nenhuma linha de recurso, exit0 nos três. Nenhuma segunda execução iniciada.

Hipótese estática: falta do delta canônico `20260908235110_superadmin_activity_link_end_clock_v1.sql` no target nominal anterior. Ele altera o encerramento de vínculo para `greatest(clock_timestamp(), starts_at + interval '1 microsecond')`. A causa ainda exige prova no perfil sucessor revisado; não alterar fixture para ocultar o swap na mesma transação.
