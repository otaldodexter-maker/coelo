---
source: D00 delegated joint wrapper integration; 5b4ac0417 and 0bc710cb
status: offline qualification only; pending integrated SQL and Auth proof
generated: 2026-09-09
---

Joint patch modifies only Prepare-SafeMigrationReplay.ps1 and Invoke-SafeLocalMigrationReplay.ps1, preserving current Clock, CHILD, AuthProof and one existing TestPath pgTAP execution. No canonical wrapper, index or commit was changed by the reviewer.

Patch SHA256: `8D8354E6383AB5B5E015DA4F63C97D9C212DA4DD079DFC7B0F4797D4E8B48C00`.
`git apply --check` passed against root at preparation. The original byte hashes are retained in baseline-sha256.txt; applying after another wrapper edit requires another check.

Auth: adds both Boundary parameters, early common guards before nominal resolution, Auth service inclusion and exactly one focal runner call. Boundary permits reviewed AdditionalMigration through existing AuthOnly validation. Boundary rejects Foundation, any nominal, lifecycle and all three concurrency modes. Assert requires Boundary. Existing concurrency predicates remain intact; common early guards exclude the new modes before reaching them.

Offline guards: 15 passed, 0 failed, skipped/pending/inconclusive zero. Test-R02JointWrapperGuards.Tests.ps1 accepts WrapperPath. It parses the supplied real wrapper and runs its unchanged prefix through the initial guard block, then throws an offline sentinel immediately before the first nominal resolver. Only synthetic comment migration filenames are created in an exclusive TEMP fixture. No valid full wrapper execution is possible in this test. Eleven invalid combinations receive the intended error; four permitted initial combinations reach only the sentinel. This proves initial guard behavior, not subsequent resources or live runners.

Test SHA256: `3C4AE5625D3A7C8E6445C4CE17A785887B0A4C61BF6A696FC42051799B5BC1FA`.

Location: both allowlists/dispatch entries retain Clock; exactly two LocationBootstrap files are included in sorted materialization, copying and total count. Both Forms branches include LocationCatalogV2 so the reviewed converter produces Forms and the original is excluded from normal copying.

Offline Prepare materialization passed: 57 files = 53 canonical + 2 preflight + 2 fixtures, Additional=4. Fixtures 20260908030958 and 20260908030959 immediately precede LOC01 20260908031000. Forms receipt and source-preservation checks passed inside the unchanged materializer checks; derived bytes=24576, SHA256 `06B71570BBB25C84EFE5EFED6A6D1F2416A33A5A6FDF71BC20B4776D01833DFE`.

Materialization uses Prepare-OfflineRootSources.ps1, a separate TEMP adapter differing only in packageRoot assignment to canonical read-only sources. It writes location-materialized under this exclusive TEMP artifact directory. Initial invocation correctly failed because destination did not exist; after explicit directory creation the single complete materialization passed. Both patched wrappers parse without errors. Nothing here establishes seven Location pgTAP passes, Auth U46, E2E completion or remote authorization. No Docker, SQL, remote access or credentials were used.
