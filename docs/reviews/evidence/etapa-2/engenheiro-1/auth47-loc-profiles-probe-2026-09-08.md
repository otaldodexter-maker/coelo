---
title: Auth47 — catálogo de Locais e primeiro bloqueio READ de Perfis
source: Autorizações do Coordenador; fixtureLOC própria; Perfis b11c3c3e; gates5529883e; execução root
status: catálogo observado; Perfis3PASS/5FAIL por ACL anterior ao contrato
generated: 2026-09-08
executed_utc: 2026-09-08T03:48:17.3708297Z
cleanup_verified_utc: 2026-09-08T03:50:56.8629214Z
---

# Auth47: LOC ACL e Perfis READ

A base Auth45+2preflights aplicou integralmente. As duas fixtures emitiram11TAP completos: **LOC3/3PASS e Perfis3PASS/5FAIL**, exit1 pelo RED de Perfis, sem aborto.

O catálogo local observou PostgreSQL17.6, current_userpostgres e **nove entradas de ACL não proprietárias** em public.activity_locations. Contra o vetor esperado da candidataLOC947, o único extra é service_role:MAINTAIN:false; não falta nenhuma entrada. A candidata31000 e o bootstrapLOC não foram executados.

## Inputs

Wrapper5529883e18176f0dab1f51ce36ba000e01ed3485, com373PesterPASS e revisão; Invoke08910d32466dca81cc64194063547d0f9f7d8642ce23820b0e0b87d09a8b0261 e Prepare0251aad3e50d2f8659c183a4978163116244ca964a00a99038da618899486861. Auth45 usa manifesto4279e67c9651f4049329591b6e8aad82e3a9052506c1a4e16ba8bbb693249d59 e os dois preflights históricos. Não entraram Models, Forms ou235500.

| Fixture | Bytes reais LF | SHA256 LF | SHA256 CRLF |
|---|---:|---|---|
| location_catalog_legacy_acl_probe_test.sql | 2902 | 6080226e79568ae3e7152fc4dfa8bda18e1e9f0996763c4b155bc3365650cd35 | 6a6d5ed1fff66a5b417170c361e8ef977ad773e9fab220a8b37e9d0596d39a54 |
| access_profiles_internal_read_contract_test.sql | 6016 | 3a5dd87b3574875279d7e59e9c75bd686252161d95c5839b1e6ad47dbea1aa9f | 4a0f37bd116a35dad4656bacf887459c0e1fcd0fe635e9db67f40615fef54c73 |

Perfis é cópia literal do commitb11c3c3ef39fea4c61422591c33b0ff69e12ac32, blobee7467bdb4cf6f14df05aa3a8f4862f4249d234b. O par teve revisão independente sem bloqueador. RPCs são capturadas sob authenticated, TAP apósRESET exceto o controle prévio sempeople; erros individuais geram diagnóstico sem imprimir responses. LOC acessa somente catálogos, sem funções de aplicação. Ambas usam BEGIN/ROLLBACK; nenhum GRANT/REVOKE ou corretiva.

## Catálogo observado de Locais

server_version_num=170006; current_user=postgres; relation=public.activity_locations.

| Grantee | Privilégios observados | is_grantable |
|---|---|---|
| authenticated | SELECT | false |
| service_role | DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE | false em todos |

São1+8=9entradas, após excluir o owner. O PASS3 prova ator/versão/existência da tabela, não aprovação de ACL. Os diagnósticos JSON comprovam o valor observado. O único delta contra947 é MAINTAIN, coerente com o GRANTALL histórico em PostgreSQL17; não foi feita revogação nem alterado o fingerprint da candidata.

## Catálogo observado e RED de Perfis

| Função | Owner | SECURITY DEFINER | authenticated EXECUTE | PUBLIC ACL |
|---|---|---|---|---|
| public.superadmin_access_profiles_list(text,text,text,text,integer,integer) | postgres | false | true | vazio |
| app_private.superadmin_access_profiles_cursor(text,text,text,text,integer,text,uuid) | postgres | true | false | vazio |

Ambas têm search_path vazio. O wrapper é SECURITYINVOKER e o helper privado não concede EXECUTE ao ator: as quatro capturas page1/page2/scopes/statuses retornaram **SQLSTATE42501, failure_classacl-before-contract**.

Os três controles de Perfis passaram: ator interno sem vínculoPeople, chamadas authenticated e bootstrapOwnerAAL1positivo. As cinco asserções de contrato4–8 falharam porque não houve resposta do reader. Portanto são efeitos do primeiro bloqueio de ACL; **não são cinco defeitos comportamentais independentes de paginação/CSV**. Não houve troca de ator para postgres para fazer a chamada nem pontePeople/grant artificial.

Os diagnósticos completos, sem dados pessoais ou segredos, estão em auth47-loc-profiles-catalog-2026-09-08.json.

## Execução e cleanup

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 -AuthOnly `
  -TestPath @(
    'packages/coelo_database/supabase/tests/location_catalog_legacy_acl_probe_test.sql',
    'packages/coelo_database/supabase/tests/access_profiles_internal_read_contract_test.sql'
  )
```

Início03:48:17.3708297UTC (00:48:17BRT). Identidade coelo_safe_c3e8951894af4fb198f46b7bba357; staging criado03:48:24.9729830UTC, marcador lido durante a execução. Base47 aplicada, Files2/Tests11,6PASS/5FAIL,wrapperexit1.

Consulta independente03:50:56.8629214UTC: zero containers, volumes e redes próprios; staging ausente; staging histórico coelo_safe_af5bdf571cff41309f5b6845b713a preservado.

Próximos gates: frenteLOC revisar somente o delta nominalMAINTAIN com novo hash; frentePerfis tratar primeiro a barreiraACL sob nova reserva, preservando a separação da verificação do contrato. Não houve mutação remota, deploy, ledger ou promoção E2E. Plano próprio e evidência local atualizados; rastreadores centrais pertencem ao Coordenador. Nenhuma regra nova de produto foi criada.
