---
fonte:
  - "Autorização nominal do Engenheiro 1: regressão independente de 23 arquivos estáveis, excluindo somente F-AUTHOR"
  - "Snapshot local E1 de 2026-09-08; revisão do delta contra HEAD 0833bbfbaa0502f32a6bc72f497a34948487a3a7"
status: "597/597 Pester PASS no snapshot estável; revisão do delta sem bloqueador novo"
data_geracao: "2026-09-08"
---

# Regressão compartilhada Agenda54 e A01 local

A regressão independente passou em **597/597 testes, zero falhas, zero skips e zero pendências**, com Pester **3.4.0**, em **451,6866725 segundos** (exit code 0). A lista explícita de 23 suítes e os hashes raw e normalizados CRLF de **33 arquivos** permaneceram iguais antes e depois da execução.

O recorte contém as 20 suítes anteriores (488 testes), Agenda GREEN54 (34), a integração A01 no wrapper (31) e o helper A01 (44): **597 testes esperados em 23 arquivos explícitos**. A enumeração com `rg --files` encontrou 24 arquivos `*.Tests.ps1`; a única exclusão é `FormsAuthoringRuntimePreflight.Tests.ps1`, que permanece em alteração por outro colaborador. A lista abaixo foi fixada antes da execução, sem descoberta dinâmica de suítes durante o Pester.

Somente este Markdown foi escrito pelo revisor. Nenhum código, SQL, perfil, migration, entrypoint ou arquivo de teste do checkout foi alterado; não houve execução de Docker, SQL, HTTP, replay ou mutação de Git. A execução usa Pester 3.4.0, `Invoke-Pester -Path $regPaths -PassThru -Quiet`, com os 23 caminhos absolutos da lista explícita. Os testes operam por mocks, sentinelas e fixtures no TestDrive.

## Snapshot e hashes

Hash anterior capturado em **2026-09-08T05:37:01.613032+00:00**. Hash posterior capturado em **2026-09-08T05:45:33.443967+00:00**. A comparação exigiu os mesmos 23 nomes e igualdade de caminho, SHA256 raw e SHA256 CRLF em todos os 33 registros: **33/33 iguais; zero divergências**.

Os hashes raw medem os bytes físicos; CRLF significa texto UTF-8 sem BOM normalizado para finais de linha CRLF. Ambos devem permanecer iguais entre as duas leituras. As tabelas registram o snapshot anterior; a comparação posterior verifica cada campo pelo mesmo caminho.

### Lista explícita das 23 suítes

Caminhos relativos a `packages/coelo_database/scripts/tests/`, na ordem passada ao Pester.

| Arquivo | SHA256 raw | SHA256 CRLF |
| --- | --- | --- |
| `A01DirectoryAuditGreen.Tests.ps1` | `28c7a8108fff89c441f839956fa646744783e6bf54ab1b9a311ddad66dab83ae` | `28c7a8108fff89c441f839956fa646744783e6bf54ab1b9a311ddad66dab83ae` |
| `A01DirectoryAuditRed.Tests.ps1` | `772047862a472344ac8f45fc8d9337ac77f5e657fc41d664f0217a0f43ed50e1` | `772047862a472344ac8f45fc8d9337ac77f5e657fc41d664f0217a0f43ed50e1` |
| `A01DirectoryContractRed.Tests.ps1` | `673e3c48e740181163226c3d3e0f557852bdfc952da39b234d1513bb3b8d8f9e` | `2e57a22137a5493be0210250c6b786a3781fa4112fb61b4c9b8d9917a84aba56` |
| `A01LocalRuntimeIntegration.Tests.ps1` | `6b88a4057b897ab078ec21461f60c88677dd05f8fe3ee5e2fe71df4e384bdd5d` | `6b88a4057b897ab078ec21461f60c88677dd05f8fe3ee5e2fe71df4e384bdd5d` |
| `AgendaReadContractGreen.Tests.ps1` | `f42aa964045bcd36dda354ca6799480c7fa9bff6abe6bb302ffa5f13d70b07f9` | `f42aa964045bcd36dda354ca6799480c7fa9bff6abe6bb302ffa5f13d70b07f9` |
| `AgendaReadContractRed.Tests.ps1` | `4e7a20bc33a5c7a6d510856ddea9cd088d52a7de1967031cd783d2f359454d7a` | `4e7a20bc33a5c7a6d510856ddea9cd088d52a7de1967031cd783d2f359454d7a` |
| `AuthOnlyAdditionalMigration.Tests.ps1` | `446950f7c964e546aa0258fa3b8b99b12313b40e9bc14bb6f713bbf98a6cf05e` | `ec64577610ec0672632ace7e898d98decad1e61d717b99fe5e92a597250f7806` |
| `Convert-FReadFormsDefinitionForLocalReplay.Tests.ps1` | `f21635d43cfc5020a21c78cf29698bd9cfce0174c7ffe62b51891ab312749425` | `f480772df56560b5f221ab076ecb51bed9f39d282882eb79fa20606e774c47a4` |
| `FReadDirectoryContractGreen.Tests.ps1` | `384ee433c61803b9156879cfbd192049ae9bb432a7cad1865d6f12348cbecf4c` | `8d4ff834d7bc514f4f25038d86369d7a37fa4dfa31167ccef453d9e4dbd5aa48` |
| `FReadDirectoryContractGreenDerived.Tests.ps1` | `a14f7a7f4dba813147d042e62ead0865064a50933bc07bab9441c7cb8fad874d` | `4ab1b8ca69f6ec9e41a0c3e0ad8c1053402f7f7d478b52422ae4835fa65eae37` |
| `FReadDirectoryContractRed.Tests.ps1` | `699720463766ad22478af5eac412b6bc1951710e9c6784496e4c539c1170d0eb` | `90ff4c56e6f62118a79577461aa1435bdc0cf5f0866fc0de2cda45a0a9802025` |
| `FReadDirectoryContractRedDerived.Tests.ps1` | `d8148f743d6b83858a47acbefb63f526259506999b9c123041ce25209da6c389` | `f9407c0979bfc523e83c5b17f09d70116682acfa0208ae01d013e6f21379f2d2` |
| `Invoke-SafeLocalMigrationReplay.AgentMode.Tests.ps1` | `db066d3959d43adf0b00d2b9c4a60117fe5dce19841275ca0cecd2d7d37088c7` | `204dc034d48273e61b4b32a8a87245bdd0166013063e42043239e719b3071ea6` |
| `LocationCatalogV2.Tests.ps1` | `86916d348bd6b9eee44f341c3e6fdc3037f0bdc8494b256e1af3cd91aed7123c` | `86916d348bd6b9eee44f341c3e6fdc3037f0bdc8494b256e1af3cd91aed7123c` |
| `ModelReadAuthorizationGreen.Tests.ps1` | `d244d5e86820829aee2cdc385a8e453d9d3ec7d7f80c1a2fee7b7d95c3850f6c` | `d244d5e86820829aee2cdc385a8e453d9d3ec7d7f80c1a2fee7b7d95c3850f6c` |
| `ModelReadAuthorizationRed.Tests.ps1` | `fb3d15431ef7a46a600825341ec6d2d2e3b25062a183c82726d0916cbce91994` | `3678505170f283c354c3aed4d683639745528ff51510a2b7ab9e146cfd0e0b19` |
| `N01PrerequisitesRed.Tests.ps1` | `6cc1488187e07a5ac6d0f681e73f92b81d2c164c0c9028b3fce2e8ce31f12730` | `a2b4a1bf998bb49541eb00106166d9f36034487510b69acaee61d1131cc07d32` |
| `Prepare-SafeMigrationReplay.Additional.Tests.ps1` | `46946adafb5d62c7da2ac4cf527d38c2f540c37fe9cd779028ece3d9f795a416` | `507c11013c2692246c565cc22e6b96470ec7d4b0e956b8e96cdafa1cfa9f2fcd` |
| `Prepare-SafeMigrationReplay.Tests.ps1` | `a3a4fc3b654a449f2b82e14b07add1c9a112861c88845d041151e2df6e377f95` | `1e5e43fe883ba4a23994f8339b0eaf9e14d14f09eb2a87ab0013cf43d93091ab` |
| `Test-ActivityV2Concurrency.Tests.ps1` | `d562bc80b78eadaa3b2d950e8f76d03990701edba1c544afba128f6fdadfcdec` | `8694b476bc1d40b6f561a4b03472851733666fd1e48e9bd4a818f51a0bfa2ff6` |
| `Test-FoundationReplayProfile.Tests.ps1` | `86e89173133faef304b5e9cca4b2aa0dc5190f9f20164e8a7054cd4884a03d9d` | `eead7330a0a571a04a8e21420fa9b2596d9ea75fbac6fa3e13a0511ce062b588` |
| `Test-LocalA01Runtime.Tests.ps1` | `d0bc7658dd266742149d28a57a3ba5583f3a3978a34c2d95d1f5bf5fc2d6b21b` | `d0bc7658dd266742149d28a57a3ba5583f3a3978a34c2d95d1f5bf5fc2d6b21b` |
| `Test-LocalAuthLifecycle.Tests.ps1` | `4e6922f367ba3519b11dc63a9d0a791191872f364d504f9e3588eb070ef84c0a` | `2265a117e8d8e05ccc4547abdbda202ccb2038e42d8c64350050b6772f02b2a7` |

### Runtime, perfis e seed fixados

Caminhos relativos a `packages/coelo_database/`.

| Arquivo | SHA256 raw | SHA256 CRLF |
| --- | --- | --- |
| `scripts/Invoke-SafeLocalMigrationReplay.ps1` | `1083f3dec80a3bfef965d0be5f5c30df3607a5d1c7e83533f6c485cdbacf494d` | `1083f3dec80a3bfef965d0be5f5c30df3607a5d1c7e83533f6c485cdbacf494d` |
| `scripts/Prepare-SafeMigrationReplay.ps1` | `7a1e8b57c70b8db2db54f747f4136a91369e97efc36a7065cd7044c483440ad4` | `7a1e8b57c70b8db2db54f747f4136a91369e97efc36a7065cd7044c483440ad4` |
| `scripts/Test-LocalA01Runtime.ps1` | `ab8947303545c311d644b62dcee2a04daefcfa535ee6f433259ed5daafd8172b` | `ab8947303545c311d644b62dcee2a04daefcfa535ee6f433259ed5daafd8172b` |
| `replay/profiles/AgendaReadContractGreen/profile.json` | `ec71fcca12d79b8e89051bf4f9e2f63f99bca17c0517d5ca9a4a7c4cd30c9051` | `ec71fcca12d79b8e89051bf4f9e2f63f99bca17c0517d5ca9a4a7c4cd30c9051` |
| `replay/profiles/AgendaReadContractGreen/Resolve-AgendaReadContractGreen.ps1` | `2eb4f82db7770661aac783cdc4a534e481fbe95e0ae60eb8f019d65f7185347b` | `2eb4f82db7770661aac783cdc4a534e481fbe95e0ae60eb8f019d65f7185347b` |
| `replay/profiles/AgendaReadContractRed/profile.json` | `ba5e2b94e3f245bdeb634d86c7f4db2f39b23a6831e0bfbd7a7511031b8c0385` | `ba5e2b94e3f245bdeb634d86c7f4db2f39b23a6831e0bfbd7a7511031b8c0385` |
| `replay/profiles/AgendaReadContractRed/Resolve-AgendaReadContractRed.ps1` | `dd2d76099fffb393df040ea910981908e0a65e149964a311df7af1a36864bf15` | `dd2d76099fffb393df040ea910981908e0a65e149964a311df7af1a36864bf15` |
| `replay/profiles/A01DirectoryAuditGreen/profile.json` | `bbd606be64e366502d84389f4a66e9e32ba500f29b043c5cf21cb332a14424ba` | `bbd606be64e366502d84389f4a66e9e32ba500f29b043c5cf21cb332a14424ba` |
| `replay/profiles/A01DirectoryAuditGreen/Resolve-A01DirectoryAuditGreen.ps1` | `6b055f0c09b0a918ce5c027e2b59504d7662646535bdcf065e24cdcecde863f2` | `6b055f0c09b0a918ce5c027e2b59504d7662646535bdcf065e24cdcecde863f2` |
| `tests/fixtures/a01_local_http_seed.sql` | `758e6b4b3c8ad237ec709acd17c0fe59c9d554f6c789c76bbb81ab13a67adf99` | `758e6b4b3c8ad237ec709acd17c0fe59c9d554f6c789c76bbb81ab13a67adf99` |

## Revisão estática do delta

`Prepare-SafeMigrationReplay.ps1` recebe somente o item `AgendaReadContractGreen` no `ValidateSet` (linha 11) e o caminho literal de seu resolver no `switch` (linha 87). A resolução continua passando pelas guardas existentes. Não há branch novo para alterar cópias, materiais derivados, bootstrap, contagens ou `AdditionalMigration`.

`Invoke-SafeLocalMigrationReplay.ps1` recebe o mesmo seletor Agenda (linhas 11 e 114), os parâmetros tipados `RunA01LocalRuntime` e `A01ClientRoot` (linhas 24–26) e os seguintes pontos A01:

- Linhas 95–104: exige somente `A01DirectoryAuditGreen`, alvo `20260907222911` e raiz de cliente informada; rejeita Foundation/Auth, extras, lifecycle, concorrência, TestPath e lint. Raiz de cliente sem opt-in também é rejeitada.
- Linhas 217–239: valida existência, arquivo e ancestrais do helper, hash literal `ab894730…`, checkout do cliente, seleção Green55 e seed `758e6b4b…`. O helper é dot-sourced para carregar funções; sua cauda só executa o runtime quando a invocação não é `.`. Esses gates ficam antes do mutex da linha 245 e antes de criar staging.
- Linhas 326–341: o opt-in reutiliza o grupo de serviços Auth existente, mantendo o output de start suprimido. A execução sem opt-in preserva o grupo DB-only.
- Linhas 361–365: invoca o helper nominal somente depois de `db reset` retornar sucesso, dentro do mesmo `try` protegido pelo `catch/finally` existente. O helper propaga falhas terminantes; não cria keepalive ou caminho livre de seed/SQL.

A comparação em memória com o HEAD confirmou igualdade textual após normalização LF de três regiões: guardas Foundation/Auth/AdditionalMigration; bloco de mutex, ownership e preparação; e toda a cauda `catch/finally` e reporte final. A cauda preservada tem SHA256 LF `7e983d2e0c56984e97b25837c14a8d7c716c043c78bb735099e516b7d01d9618`. Ela mantém stop nominal `--no-backup`, marker/created, rejeição de reparse point antes de remover o diretório próprio, auditoria de resíduos e liberação do mutex.

No helper A01 pinado, o diagnóstico local rejeita overrides, valida o named pipe local e fixa `--host` para os comandos Docker próprios (linhas 311–330). O status da CLI revalida contexto/endpoint e usa ambiente filho em allowlist com `DOCKER_HOST` explícito (linhas 363–373). A validação de seed passa por `Assert-A01Path`, incluindo seus ancestrais. Esses pontos foram lidos estaticamente; a presente regressão não conecta ao daemon.

## Qualidade da evidência e limites

A suíte A01 de integração recorta o wrapper antes do mutex, substitui apenas na cópia do TestDrive o pin pelo hash de um helper inerte observável e termina em sentinela. A asserção separada sobre o arquivo fonte exige o pin verdadeiro exatamente uma vez. Os casos de argumentos rejeitam `ParameterBindingException`, evitando confundir parâmetro ausente com guard nominal. As asserções AST verificam ordem do reset/helper/finally, mas não constituem prova de cleanup Docker real.

Agenda54 comprova igualdade raw de cada arquivo preparado com sua origem; os testes dos perfis legados e os testes do helper A01 continuam com seus próprios limites. PASS neste recorte não comprova Auth/Kong/PostgREST ativos, layout de configuração da CLI, execução das migrations, pgTAP, tráfego Flutter, auditoria SQL ou fim a fim.

O Engenheiro 1 informou separadamente smoke nativo Windows do Job Object aprovado (stdin de 65.536 bytes, stdout/stderr, pai encerrado e descendente terminado em 2,04857 segundos, PID 45584 ausente e marker removido) e `Assert-A01Client` no checkout f0 aprovado. Essa evidência externa é atribuída ao operador; não foi reproduzida pelo revisor nesta rodada.

Não foi encontrado bloqueador novo no delta revisado. A aprovação deste recorte cobre preparação, integração estática e regressão por mocks/sentinelas no snapshot identificado. O replay e a janela HTTP real continuam sendo gates operacionais separados, com execução e cleanup a cargo do Engenheiro 1.

Não houve alteração durável de regras de produto, domínio ou permissões; esta evidência registra somente o gate técnico nominal.

## Ajuste posterior de EOF, separado do snapshot testado

Depois do GREEN e da comparação estável de 33/33 hashes, o Engenheiro 1 removeu somente uma linha vazia final de `scripts/tests/A01LocalRuntimeIntegration.Tests.ps1`. A prova independente de **2026-09-08T05:52:58.663207+00:00** comparou os bytes atuais com os bytes do arquivo testado, preservados em memória: o arquivo passou de **17.992 para 17.990 bytes**, retirando exatamente dois bytes CRLF. O conteúdo novo é byte a byte `old.rstrip(b'\r\n') + b'\r\n'` e é prefixo idêntico do conteúdo anterior.

- Pin raw/CRLF efetivamente testado: `6b88a4057b897ab078ec21461f60c88677dd05f8fe3ee5e2fe71df4e384bdd5d`.
- Pin raw/CRLF final, após o ajuste de whitespace: `8e25dba1ecb0698bbef3bcdc701e2e9b73e720db5a19e7aec4ad22e2336af765`.

Os **597 testes** pertencem ao snapshot anterior registrado nas tabelas. Não houve nova execução do Pester após essa formatação; a aceitação do pin final se baseia na prova byte exata de que apenas o CRLF excedente no EOF foi removido. Nenhum helper, wrapper ou perfil foi editado pelo revisor.
