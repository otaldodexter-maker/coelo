---
title: F-READ — prova do parser e materialização local de quatro caracteres
source: Autorização nominal do Coordenador; função canônica155005; testes locais do Engenheiro1
status: parser PostgreSQL17.6 validado; materializador isolado revisado; replay derivado ainda não executado
generated: 2026-09-07
executed_utc: 2026-09-08T02:03:52.9625465Z
cleanup_verified_utc: 2026-09-08T02:06:19.9920665Z
---

# Prova local da sintaxe histórica

A execução FRead50 anterior demonstrou 42601 ao compilar `app_private.form_item_config_valid` na migration `20260813155005_forms_definition_and_capabilities.sql`. A autorização posterior limitou a correção à **materialização local**, com dois pares de parênteses nas expressões CASE das linhas 105–107 e145–146. A migration canônica permanece intacta.

O conversor específico acrescenta somente `(`/`)` em cada CASE, quatro caracteres e quatro bytes, preservando o restante da origem, inclusive LF/CRLF e BOM quando presente. O source name, origem, derivado e pares literais são fixos; não há reescrita genérica, skip, alteração de check_function_bodies ou grant.

| Artefato | SHA-256 normalizado CRLF/UTF-8 |
|---|---|
| Migration canônica155005 | 3a3d2bd348948cdef78a3a0c712c9eae8a6a6fb8be59b8fd942a445f6cbb6e36 |
| Migration local derivada155005 | 06b71570bbb25c84efe5efed6a6d1f2416a33a5a6fdf71bc20b4776d01833dfe |
| Convert-FReadFormsDefinitionForLocalReplay.ps1 | c3cc8e86a075c20f608d3d34ab31f1611e56f80aabfe29958832f5ab05982dc5 |
| Convert-FReadFormsDefinitionForLocalReplay.Tests.ps1 | f480772df56560b5f221ab076ecb51bed9f39d282882eb79fa20606e774c47a4 |
| forms_config_validator_parser_test.sql final | b9e3c454410e75d81bd589a7e38fac04ccb3cfe33c76bec01f831d338766d4bf |

O SHA LF da fixture final é `71c95a341a8ec0babf1ba5cf52721ee332c90d89f4e3fca3e9c87428e7813f76`.

## Gates locais

Writer: RED17/17 com conversor ausente, depois GREEN17/17. Root: **17/17 Pester PASS**, zero falhas/skips, 2,66 segundos. Os testes cobrem quatro inserts exatos em LF/CRLF, drift fora dos trechos, ocorrências ausentes/duplicadas, hash derivado incorreto, overwrite, caminhos relativos/rede/foraTEMP/dentrorepositório e reparse em fontes/destinos/ancestrais.

O conversor exige diretório existente sob TEMP, fora do repositório e sem reparse. Valida origem, ocorrências e hash derivado antes de criar o único arquivo nominal com CreateNew. Não modifica a fonte nem sobrescreve destino.

A revisão independente confirmou os hashes, os quatro inserts e que as 95 linhas da função original na fixture são cópia literal da fonte. A função corrigida é idêntica à função da derivação. O root fortaleceu somente o primeiro TAP para exigir PostgreSQL17.x além de postgres; nova revisão comprovou esse delta isolado.

## Prova real no mesmo servidor

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 `
  -AuthOnly `
  -TestPath packages/coelo_database/supabase/tests/forms_config_validator_parser_test.sql
```

A base **Auth45 + dois preflights =47** aplicou integralmente. Não inclui Forms155005; a fixture exercita os CREATE originais/corrigidos diretamente, na mesma transação, e termina com rollback.

Início `2026-09-08T02:03:52.9625465Z` (23:03:52 BRT). Identidade `coelo_safe_a05d7df783db446f8623d637440bd`, staging criado às `02:03:58.2581957Z`; marcador conferido durante a execução.

**3/3 pgTAP PASS, exit0**:

1. Ator postgres e versão17.x.
2. CREATE original lança exatamente SQLSTATE42601.
3. CREATE com quatro parênteses compila sem exceção.

O output registrou `server_version_num=170006`: **PostgreSQL17.6**. A prova confirma compilação; não testa a semântica completa do validador, Forms inteiro ou o reader.

## Cleanup e próximo gate

Verificação independente às `2026-09-08T02:06:19.9920665Z`: zero containers, volumes e redes próprios; staging ausente. O staging histórico `coelo_safe_af5bdf571cff41309f5b6845b713a` permaneceu preservado.

O conversor ainda não está ligado ao Prepare. O futuro perfil fechado derivado deverá preservar os 50 nomes/ordem, identificar explicitamente a única cópia transformada, conferir origem/derivado e manter os demais arquivos byte-exatos. O replay derivado depende da revisão final de perfil/hashes e liberação nominal central; não foi executado nesta fatia.

Nenhuma migration canônica, dado remoto, ledger, grant ou deploy foi alterado. README e plano próprio atualizados; não há nova regra de produto nem registro de atividade na projeção de conhecimento.
