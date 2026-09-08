---
title: Atividades — GREEN local da auditoria de leitura v2
source: Autorização do Coordenador; corretiva96de811b; fixture97 ee212cb5; pacote464a947d; execução root
status: 97 pgTAP PASS; validação local do recorte
generated: 2026-09-08
executed_utc: 2026-09-08T03:15:37.4841733Z
cleanup_verified_utc: 2026-09-08T03:18:51.6615675Z
---

# A01DirectoryAuditGreen55

**A base55 com v2 aplicou integralmente e os97TAP passaram**, exit0. A mesma fixture havia registrado91PASS/6FAIL na v1. Os89 contratos anteriores, controles de ator, auditoria de sucesso minimizada/correlacionada e falha simulada de auditoria passaram com a corretiva.

## Inputs e gates

V2 nominal: commit96de811b8ce02333f302117e9ee8c4e7d5dc445d, blob2472a89b61cd34e3be866d80b33a042f5456d6c8. Arquivo20260907222911_superadmin_activity_directory_v2_client_contract.sql, hash CRLF e72e11c5d0f8fd8d49bfe098a230530edb3d4070d80ca5b4ae04b61b72eb196f; LF e4b02a2100030c36a0895d04036685cafae623326872f3141902d00043fe66f2.

Fixture superadmin_internal_activities_v2_directory_contract_test.sql preservada, fonteee212cb56e9dc18400a8d105aeeba3a5f77bbbf4, blob3d7d25ab24a738a03a1f1f11e4a500c13706ca6a:38905bytesLF, fc492972051e741e37d0dd7b1d7056eec24a57c4b02e98bb6ffccb9a4ca3b3b1; normalizadoCRLF f028b86a065f7ea50c1447a62a2b0131ec8cc9119f117c5947355979b1c9648f. Hash real conferido imediatamente antes do replay.

Pacote464a947dff729acfaabb5ee6fbdd7faa242b6b1e:332PesterPASS, setePSparse, revisão independente dos pins, TestDrive histórico e entrypoints. DescriptorGREEN bbd606be64e366502d84389f4a66e9e32ba500f29b043c5cf21cb332a14424ba; resolver6b055f0c09b0a918ce5c027e2b59504d7662646535bdcf065e24cdcecde863f2. A v1 e seu RED estão preservados no históricod74 e na fixture Pester isolada, sem trocar seu pin silenciosamente.

## Resultado observado

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260907222911 -NominalProfile A01DirectoryAuditGreen `
  -TestPath packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_directory_contract_test.sql
```

Início03:15:37.4841733UTC (00:15:37BRT). Identidade reportada pelo wrapper:coelo_safe_f5bae794c349427f918606a50459f.

```text
Applying migration 20260907222911_superadmin_activity_directory_v2_client_contract.sql...
Finished supabase db reset on branch main.
All tests successful.
Files=1, Tests=97
Result: PASS
Safe local replay completed through 20260907222911 with isolated identity coelo_safe_f5bae794c349427f918606a50459f and zero residual resources.
```

Na v1, as asserções91–94/96–97 falhavam por ausência de append de sucesso; não havia prova de append executado e capturado indevidamente. Na v2, os dois appends de sucesso ficam fora da captura de erro. O PASS97 confirma os controles específicos de correlação/minimização e o retorno esperado diante da falha injetada na auditoria, mantendo os89 anteriores.

## Cleanup e limites

Consulta independente03:18:51.6615675UTC: zero containers, volumes e redes próprios; staging ausente; staging histórico coelo_safe_af5bdf571cff41309f5b6845b713a preservado. A tentativa de ler o marcador durante a execução ocorreu após o staging já ter sido removido; esta evidência não declara leitura independente do marcador nem horário de criação. O wrapper revisado validou propriedade no teardown e reportou exit0/zeroresiduais.

Validação restrita ao contrato SQL local e às97asserções. Não prova uso real da tela Flutter, concorrência completa de produção ou implantação remota. Não houve grant novo, mutação remota, ledger ou deploy. README/plano próprios atualizados e Coordenador informado; nenhuma regra nova de produto foi criada.
