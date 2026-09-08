---
title: F-READ — preparação do replay nominal derivado de 50 arquivos
source: Reserva do Coordenador; pacote e607a5d5; revisão independente replay_runner; testes root e replay_auth_rls
status: harness validado; execução completa pendente de liberação nominal
generated: 2026-09-07
verified_utc: 2026-09-08T02:52:00Z
---

# FReadDirectoryContractRedDerived

O perfil fechado mantém os 50 nomes e a ordem da base FReadDirectoryContractRed, com alvo 20260901200206. Somente a cópia local de 20260813155005_forms_definition_and_capabilities.sql recebe quatro parênteses. Os outros 49 arquivos permanecem byte a byte iguais; o SQL canônico é preservado.

O parser isolado já passou 3/3 em PostgreSQL17.6 (e607a5d5), mas não prova a aplicação das demais migrations ou o contrato do reader. Este pacote não foi executado em Docker/SQL. O reader20260908000049 continua fora do RED50.

## Inputs fixos

| Artefato | SHA256 normalizado CRLF, UTF8 sem BOM |
|---|---|
| profile.json | 4545585ed64dd72e98d2f70c08fa23141d7a60f25c61d2dfc6b74419dc03a5f5 |
| Resolver Derived | aa425ed5125eae6c54d7c3aa3735e427cb1ad29489b73e2836dfd694e9680398 |
| Converter existente | c3cc8e86a075c20f608d3d34ab31f1611e56f80aabfe29958832f5ab05982dc5 |
| Invoke | f884782693140b62580b5bcf6703e191b6e6d5e7addf9ae0d4d75486dc8bdaa0 |
| Prepare | 846085771167221ca6258d26f03423f459f2c420407667bc8055976eee863b49 |
| Pester Derived | f9407c0979bfc523e83c5b17f09d70116682acfa0208ae01d013e6f21379f2d2 |
| Source155005 | 3a3d2bd348948cdef78a3a0c712c9eae8a6a6fb8be59b8fd942a445f6cbb6e36 |
| Derived155005 | 06b71570bbb25c84efe5efed6a6d1f2416a33a5a6fdf71bc20b4776d01833dfe |

O descriptor fixa o perfil pai (56455b6f7d7d388d36ea68104292f4c2c5c02d5b22eac363733cad516ebb0fe7) e seu resolver (3a04448d525e906e94f90c9dce37d195db8221b56c203dc39e305adaf4bfd1b2). A fixture117 permanece a aprovada em897ee8f7: LF c2758681c420651557cfff9078651cb60a74a9b4cb98fa75fb2f38094b83c986; CRLF ef8b3003895e2492ce392c7d1b1c1e6d0ba9d1953a93076607cf33c9a847ffb5.

## Guards e evidências

O Prepare chama o conversor uma única vez, após validar origem, conversor, destino absoluto TEMP fora do repositório e ausência de reparse points. Exige exatamente um recibo com nome, caminho, hashes e delta quatro corretos. Confere o arquivo derivado real, tamanho original+4 e origem intacta antes de copiar os demais49. O continue do foreach apenas evita copiar novamente a migration já materializada; não elimina uma migration da execução.

Testes negativos cobrem mistura de modos, target incorreto, hashes, reparse points, recibos adulterados/duplicados, derivado ausente/incorreto e origem alterada. Repins para simular conversores defeituosos existem somente nas cópias TestDrive.

- Writer: 39 específicos +233 regressões =272 PASS, zero FAIL.
- Root independente: 39/39 PASS, zero skips, 36.6370895 segundos.
- Parse root: cinco PowerShell e JSON válidos; seis hashes reconferidos.
- Revisão independente: aprovada; AuthOnly/AdditionalMigration, mutex e teardown preservados.
- Runtime de teste: Windows PowerShell5.1, Pester3.4.0; Invoke-Pester -Path ... -PassThru, sem parâmetro -Output.

## Próximo gate

Entregar este pacote ao Coordenador para liberação da execução nominal completa. Com a base aplicada, a fixture sem reader pode registrar ausência de funções e abortar no has_function_privilege (42883). Essa expectativa estática não é resultado observado e não autoriza adaptar a fixture. Nenhuma mutação remota, ledger, deploy ou conclusão E2E. Fonte operacional README e plano próprio atualizados; nenhuma regra durável de produto mudou.
