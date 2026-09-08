---
title: F-READ — replay local da base nominal 50
source: Reserva do Coordenador; perfil Auth45 e três adições históricas; fixture897ee8f7; execução pelo root
status: RED de sintaxe na dependência histórica; zero pgTAP executado
generated: 2026-09-07
executed_utc: 2026-09-08T01:30:37.9654089Z
cleanup_verified_utc: 2026-09-08T01:32:52.0891633Z
---

# FReadDirectoryContractRed

O perfil fechado seleciona **48 migrations canônicas + dois preflights = 50 arquivos**. Auth45 permanece inalterado. As adições são `20260813155005_forms_definition_and_capabilities.sql`, `20260813155116_forms_distribution_and_occurrences.sql` e `20260827235500_superadmin_internal_institution_list_filter.sql`, nas posições canônicas 42/43/46. O alvo é `20260901200206`; nenhum reader ou bridge extra integra a base50.

## Gates anteriores ao Docker

O writer reproduziu o seletor ausente: 26 falhas esperadas e um controle PASS. Depois, reportou 27/27 testes focais + 89/89 regressões. O root executou toda a suíte independentemente: **131/131 Pester PASS**, zero falhas/skips, 86,36 segundos; parse 4/4 PASS.

O reviewer conferiu os 50 hashes, nomes, versões únicas, posições e alvo. O delta dos scripts contém somente uma entrada na ValidateSet e um caminho literal em cada switch. Guards de reparse, AdditionalMigration, mutex e cleanup permanecem preservados.

| Artefato | SHA-256 normalizado CRLF/UTF-8 |
|---|---|
| Invoke-SafeLocalMigrationReplay.ps1 | 5bd69d4da8e466c732911a1b40e0cc732c9834f060b19d03890acc6578f42aa5 |
| Prepare-SafeMigrationReplay.ps1 | a834cd38fadf59d74d4b933bdc4248ec7ba92c8c3932d22da27989ca07f46e55 |
| FReadDirectoryContractRed.Tests.ps1 | 90ff4c56e6f62118a79577461aa1435bdc0cf5f0866fc0de2cda45a0a9802025 |
| Resolve-FReadDirectoryContractRed.ps1 | 3a04448d525e906e94f90c9dce37d195db8221b56c203dc39e305adaf4bfd1b2 |
| profile.json | 56455b6f7d7d388d36ea68104292f4c2c5c02d5b22eac363733cad516ebb0fe7 |

A fixture final aprovada foi materializada do snapshot `897ee8f7972f17251290cbe8cad5f08fc353f9cd`, blob `abe0c8c2d835c9d9e577db965b33b301d0e79ad0`. Os **35.594 bytes LF** reais têm SHA `c2758681c420651557cfff9078651cb60a74a9b4cb98fa75fb2f38094b83c986`; o normalizado CRLF é `ef8b3003895e2492ce392c7d1b1c1e6d0ba9d1953a93076607cf33c9a847ffb5`.

A revisão contou 18 SET/RESET ROLE, nenhum TAP sob authenticated e quatro capturas com sentinelas em três blocos DO; 117 asserções previstas. Sem endpoint, a checagem textual de has_function_privilege poderia abortar com 42883. **Essa previsão não foi alcançada no replay real.**

## Resultado observado

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 `
  -NominalProfile FReadDirectoryContractRed `
  -TestPath packages/coelo_database/supabase/tests/superadmin_forms_directory_internal_read_test.sql
```

A execução começou às 2026-09-08T01:30:37.9654089Z (22:30:37 BRT). Identidade observada durante a execução: `coelo_safe_80cd0da37c1e463090d30656f05ea`.

```text
Prepared 50 safe replay migrations (48 canonical + 2 preflight)
Applying migration 20260813155005_forms_definition_and_capabilities.sql...
ERROR: syntax error at end of input (SQLSTATE 42601)
At statement: 4
create or replace function app_private.form_item_config_valid(p_kind text, p_config jsonb)
...
if p_config - case when p_kind = 'decimal' then array['min_value','max_value','decimal_places']
safe local db reset failed with exit code 1
```

O banco abortou ao criar a função histórica `app_private.form_item_config_valid`, antes do target e antes de iniciar a fixture. **Zero pgTAP executado; não houve 117 falhas funcionais nem prova de ausência do endpoint.** O resultado é um RED de sintaxe na dependência histórica.

A leitura localizada encontrou o mesmo formato `if p_config - case ... end` nas linhas 105–109 e 145–152 da migration. A análise da causa e qualquer adaptação nominal de replay são recortes separados; o arquivo canônico e seus hashes foram preservados. Uma migration futura não contorna automaticamente uma falha anterior que interrompe a aplicação da base.

O reader `20260908000049_superadmin_forms_directory_internal_read.sql` foi somente materializado para preparação futura autorizada, com blob `a40bfb84a9e782a539d1a76d8e1c49a9ead00076` e SHA CRLF `8900f60c8951efd20550a918684b335d10d3bf77d90fc4676a9381d16b27a119`. A revisão confirmou que ele permaneceu **fora dos 50 arquivos**. A seleção51 também depende de resolver a falha histórica antes de qualquer claim funcional.

## Cleanup e limite

Verificação independente às **2026-09-08T01:32:52.0891633Z** confirmou zero containers, volumes e redes da identidade própria; staging ausente. O staging histórico `coelo_safe_af5bdf571cff41309f5b6845b713a` permaneceu preservado. A tentativa posterior de ler o marcador próprio encontrou o diretório já removido; não é reportada como inspeção bem-sucedida do marcador.

Não houve correção de SQL, grant novo, mutação remota, ledger, deploy ou alteração dos rastreadores centrais. README e plano próprio foram atualizados. Nenhuma regra de produto nova foi aprovada; não foi criada projeção de conhecimento para registrar atividade.
