---
source:
  - "Coordenador Etapa 2: repin nominal LOC50 autorizado em 2026-09-08"
  - "6b0cbb3009c7184896cfd2aebd6c7a7ca0fafe10: packages/coelo_database/migrations/20260908031000_superadmin_location_catalog_v2.sql"
  - "98d166d25d18d1d0b615e244ba8af7e93f11420e: predecessor nominal LOC"
  - "115df2ca35b04e4b8f48aecb1d2a46929bd19949: bootstrap local derivado preservado"
  - "packages/coelo_database/replay/profiles/LocationCatalogV2/profile.json"
status: preparado_com_pester_focal_green_aguarda_gate_de_replay
generated_at: "2026-09-08"
---

Este pacote atualiza somente o pin da migration LOC31000 para o parse fix aprovado. Foram alterados a migration, os metadados do descriptor, seu pin no resolver e dois casos existentes do teste focal; esta nota é o único arquivo novo. Não houve comando Git, Docker ou execução SQL. Os entrypoints Invoke/Prepare, manifesto, preflights, bootstrap, três fixtures LOC e .gitattributes não foram alterados.

A seleção permanece **Auth45 + duas migrations canônicas + dois preflights herdados + um bootstrap separado = 50 inputs**, alvo **20260908031000**. São 47 canônicas, dois preflights e um bootstrap; zero bridges adicionais. A migration235500 continua na posição canônica44; LOC31000 fica na posição canônica47 e materializada50. O bootstrap local30959 ocupa a posição materializada49, imediatamente antes do alvo. Nenhum timestamp foi empilhado ou selecionado por intervalo novo.

| Fonte LOC31000 | Pin aprovado |
| --- | --- |
| Commit | 6b0cbb3009c7184896cfd2aebd6c7a7ca0fafe10 |
| Blob LF | 8d26581692ff78db923de98d7c788257857fbbdb |
| SHA256 UTF-8/LF; bytes | ec886dcbfbe88be54fb99f233e01395a8632388b2db94761f4a49b611e93ad2f; 36236 |
| SHA256 UTF-8/CRLF; bytes materializados | f6c6c842114932d96af6b2478df43827241192044cfcae778e7ca3e4132960df; 36792 |
| Predecessor CRLF | 02fb69cbff42834ffa9a9cdebb60bab7e15c6cd0cf150175020de8c8d0f823f6 |

A reconstrução determinística parte do predecessor conferido e acrescenta exatamente dois bytes: os parênteses que envolvem a expressão CASE no DO preflight, linha93. O resultado foi conferido contra os dois SHA256, as duas contagens de bytes e o identificador do blob LF antes de gravar. Remover somente esses parênteses reproduz integralmente o predecessor. Preconditions, fingerprints, ACLs, funções e grants não receberam outro delta.

```diff
-      is distinct from case when expected.client_execute then array['authenticated:EXECUTE:false'] else '{}'::text[] end then
+      is distinct from (case when expected.client_execute then array['authenticated:EXECUTE:false'] else '{}'::text[] end) then
```

| Arquivo repinado, em packages/coelo_database | SHA256 UTF-8/CRLF |
| --- | --- |
| replay/profiles/LocationCatalogV2/profile.json | 08e46ce829270e3c15e3d0b3da73365499e5a2dd869e48f6ee44835212eaa095 |
| replay/profiles/LocationCatalogV2/Resolve-LocationCatalogV2.ps1 | 3cb55af47ccee6161b6e0a59537b7453165a725bee8fbde28b122cde490478cb |
| scripts/tests/LocationCatalogV2.Tests.ps1 | 86916d348bd6b9eee44f341c3e6fdc3037f0bdc8494b256e1af3cd91aed7123c |

O resolver mudou somente o literal SHA do descriptor. O descriptor mudou somente SHA CRLF, SHA LF, commit e blob da LOC31000. O teste positivo exige os pins novos; o caso negativo candidate reconstrói exatamente o predecessor no TestDrive, confere seu SHA e exige input hash mismatch. Os outros casos permanecem: nomes/alvo/manifesto/extra input, omissão, reparse em arquivo e ancestral, bytes do bootstrap, ordem e cópia, combinações incompatíveis e sentinela antes de mutex/Docker. Os cinco casos de casing continuam exigindo 50 cópias e posição49, ou bloqueio antes de cópia para bootstrap adulterado.

Pester **3.4.0**, somente LocationCatalogV2.Tests.ps1, com Path e PassThru:

| Rodada | Total | PASS | FAIL | SKIP | Duração externa | Duração Pester | Sessão / exit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| RED antes do repin | 58 | 56 | 2 | 0 | 73.5909525s | 73.0157763s | 80059 / 1 |
| GREEN após repin | 58 | 58 | 0 | 0 | 87.6850605s | 86.477337s | 92046 / 0 |

O RED observou o hash antigo no caso positivo e zero ocorrência da âncora parentizada no caso negativo; os demais 56 passaram. Não houve afrouxamento para produzir GREEN. Parser PowerShell dos dois arquivos PS e parse JSON passaram. Isso não constitui execução do parser PL/pgSQL no banco ou prova funcional LOC. Não foi repetida a regressão global porque os entrypoints permaneceram byte a byte iguais.

Pins preservados:

| Input | SHA256 preservado |
| --- | --- |
| scripts/Invoke-SafeLocalMigrationReplay.ps1, raw/CRLF | a6511eb6e8e03d0dd51d9740030437ffb89c519cffbbd2fa8d44cac63c96f539 |
| scripts/Prepare-SafeMigrationReplay.ps1, raw/CRLF | 3e5cab9d6fbc0285474d47f97c8efd8614e0e37dde5f3b6c5962ce00ca84ccbe |
| tests/fixtures/location_catalog_v2_capability_bootstrap.sql, raw LF | 3dd0bf5c11e52a68102e3e707e48835eb676513c235daab5defcdb1e7ad24bfb |
| tests/fixtures/20260908030959_location_catalog_v2_capability_bootstrap_local.sql, raw LF | d46583bc936dfb284b5d05bdba8dea8f965d31a0f899164bfdd8a8c6bd6d2471 |
| tests/fixtures/.gitattributes, raw | 0433b9ece4fa1ff10ccd654c0c7d0bd007c94321bf36aa86f0106a623d8de6a8 |

A derivação do bootstrap continua sendo somente a linha SET LOCAL depois de BEGIN, 54 bytes, proveniência115df2ca; as duas regras nominais text eol=lf em .gitattributes preservam seus pins raw. As três fixtures existentes seguem sem edição e usam no_plan(); não se infere uma contagem TAP nova sem execução.

| Fixture em supabase/tests | SHA256 UTF-8/CRLF |
| --- | --- |
| superadmin_location_catalog_v2_test.sql | 550ddb956e1ac83a4a2f6dc91626dde613e8441dcfc96bf17e1c454659853fb6 |
| superadmin_location_catalog_v2_authorization_test.sql | f6e3b911c41b5bc416bf82c03c9961ef5b869a76efc01baa425ab4afcac25f37 |
| superadmin_location_catalog_v2_isolation_test.sql | 85f9aaa937ad71b738d08a947efd04e000678a3ebbfaffea993116535c690ede |

Comando proposto ao operador, **não executado nesta preparação**; exige revisão independente e gate central do replay nominal. Usa os mesmos entrypoints, alvo, bootstrap e fixtures, sem AdditionalMigration ou modo extra:

```powershell
$locPackage = 'C:\Users\adrie\Documents\Coelo\.worktrees\e1-replay-harness\packages\coelo_database'
$locReplay = @{
  TargetVersion = '20260908031000'
  NominalProfile = 'LocationCatalogV2'
  TestPath = @(
    (Join-Path $locPackage 'supabase\tests\superadmin_location_catalog_v2_test.sql'),
    (Join-Path $locPackage 'supabase\tests\superadmin_location_catalog_v2_authorization_test.sql'),
    (Join-Path $locPackage 'supabase\tests\superadmin_location_catalog_v2_isolation_test.sql')
  )
}
& (Join-Path $locPackage 'scripts\Invoke-SafeLocalMigrationReplay.ps1') @locReplay
```

O operador deve validar novamente os pins ao reservar a janela serial. O runner preserva os guards existentes e finally de cleanup. A próxima evidência necessária é o resultado real do replay50 e das três fixtures, com contagem TAP observada e recursos próprios removidos; esta preparação não antecipa esse resultado.
