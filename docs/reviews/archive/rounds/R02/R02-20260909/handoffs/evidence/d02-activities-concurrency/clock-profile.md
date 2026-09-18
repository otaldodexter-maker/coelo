---
title: "D02 — sucessor nominal com relógio dos vínculos"
source: "D00 r19; resultado local 40P/6F do perfil56; commit integrado 258593e4"
status: "static-green; sql-not-executed; wrapper-patch-not-applied"
generated_at: "2026-09-09"
---

`ActivityAggregateConcurrencyClock` preserva o perfil56 anterior e acrescenta somente `20260908235110_superadmin_activity_link_end_clock_v1.sql`, já integrado. Total **55 canônicas + 2 preflights = 57 SQL**, target `20260908235110`, nenhuma bridge extra ou lista livre. O hash nominal CRLF/UTF-8 da migration é `be66e47436dfaf61bc3655fa5c1bedbeb88725077912e5c8fb28155bbcb7b069`. Nenhum arquivo SQL foi normalizado ou alterado: a normalização declarada pertence somente ao cálculo do hash, conforme os perfis pais.

Pester focal: inicialmente 1 PASS/2 FAIL pela ausência do resolver; após implementá-lo, **3 PASS/0 FAIL/0 skipped/pending/inconclusive**, 5,81 s. Provas: cadeia herdada exata, alvo histórico recusado e hash do clock. Nenhum pgTAP ou cenário de concorrência foi executado neste sucessor.

`activity-clock-wrapper-hunks.patch` contém somente allowlist, dispatch e guarda para os dois pares fechados perfil/target. Foi construído por leitura da base D00 já contendo CHILD e `RunR02AuthProofConcurrency`, e `git apply --check` nessa base terminou exit0. Não apliquei o patch nem substituí wrappers compartilhados. A primeira tentativa de check falhou pelo CRLF do arquivo patch; gravei o patch em LF e o check passou, sem mudar os wrappers ou SQL.

Hashes normalizados CRLF/UTF-8 dos wrappers lidos para esse patch:

- Prepare: `27ab616fcec60149f2024e095c17a7adc549620da45f70562d7cd2c2c6249bf9`.
- Invoke: `e5d9c3d1301b21018006f35a6d63b7fcb909d535ddbc64f261e5186dce71ca12`.

Depois da integração/revisão e nova janela D00, comando nominal proposto no package:

```powershell
./scripts/Invoke-SafeLocalMigrationReplay.ps1 -TargetVersion 20260908235110 -NominalProfile ActivityAggregateConcurrencyClock -TestPath 'supabase/tests/superadmin_activity_save_v2_test.sql' -RunActivityV2Concurrency
```

Permanece o plano 46 pgTAP + corrida de versão + expiração real + revogação real. Os 40 PASS do perfil anterior são histórico dessa árvore, não resultado do sucessor.
