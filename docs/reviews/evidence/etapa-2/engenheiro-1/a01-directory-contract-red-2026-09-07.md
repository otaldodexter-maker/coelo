---
title: A01 — replay local do contrato do diretório de Atividades
source: Reserva do Coordenador; seleção Auth45 e sete migrations Activities; fixture e927c417fd79a6b879e2e61538ec02cffc067db2; execução pelo root
status: RED funcional reproduzido; base local e harness validados
generated: 2026-09-07
executed_utc: 2026-09-08T01:10:28.3632611Z
cleanup_verified_utc: 2026-09-08T01:13:47.9138110Z
---

# A01DirectoryContractRed

O seletor fechado prepara **52 migrations canônicas + dois preflights = 54 arquivos**: Auth45 e as sete Activities v2 entre `20260831192831` e `20260831234307`. O target permanece `20260901200206`. Não inclui a corretiva `20260907222911`, ponte transitória ou o perfil Foundation67.

A análise nominal inicial e o descriptor runtime preservam os nomes, hashes e posições 44–50 das sete adições. O novo modo usa caminhos literais e a mesma validação de confinamento do N01; não altera AdditionalMigration, mutex ou cleanup.

## Gates do harness e da fixture

O writer reproduziu o seletor ausente: **26 falhas esperadas e um controle PASS**. Depois da integração mínima, reportou 89/89 Pester PASS. O reviewer conferiu 54 hashes e demonstrou, por comparação em memória, que reverter apenas a allowlist e o switch de caminhos devolvia exatamente os hashes aprovados de N01.

O root executou toda a suíte independentemente: **104/104 Pester PASS, zero falhas/skips**, em 69,58 segundos. Parse 4/4 e cinco hashes do snapshot revisado foram conferidos novamente antes do Docker.

| Artefato | SHA-256 normalizado CRLF/UTF-8 sem BOM |
|---|---|
| Invoke-SafeLocalMigrationReplay.ps1 | 690a4cbd357949bdfda329c3ecc8ec538b5904f03e171bb41b7a96ca6838481d |
| Prepare-SafeMigrationReplay.ps1 | 2360fb30a643c87381b64f5e38caaa05dde8845e3538078904d37f21f1818068 |
| A01DirectoryContractRed.Tests.ps1 | 2e57a22137a5493be0210250c6b786a3781fa4112fb61b4c9b8d9917a84aba56 |
| Resolve-A01DirectoryContractRed.ps1 | 88a12e969684fcb20677c08a07ce1893042ae4ab651aad0ee1a0932e95f20123 |
| profile.json | 7e417ac72bde47b1c84a6e2898076eada8763f77fff536328a2a7b842a521d28 |

A fixture aprovada da E2E5 foi materializada a partir do snapshot completo `e927c417fd79a6b879e2e61538ec02cffc067db2`, somente no TestPath canônico. Os bytes LF reais foram conferidos em disco: **34.900 bytes**, SHA `cf128736abb570c902456889efb0e0c63a2af8fa9496863f70ad94bac883c214`. Seu SHA normalizado CRLF é `a64cefead12b7afb00ca13f10ea7d4e68aa7ae69f54165e035ee1dec1e2143ee`.

A revisão central dessa fixture confirmou chamadas sob `authenticated`, captura do papel real e emissão de TAP após RESET ROLE. A execução manteve o arquivo exato; não houve reexecução privilegiada dos RPCs para obter resultados.

## Execução e resultado real

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 `
  -NominalProfile A01DirectoryContractRed `
  -TestPath packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_directory_contract_test.sql
```

Início em 2026-09-08T01:10:28.3632611Z (22:10:28 BRT de 7 de setembro). Identidade `coelo_safe_2d572297fffd4d28a5e42cc978f63`; staging criado em 2026-09-08T01:10:34.2487816Z e marcador conferido pelo root.

**As 54 migrations foram aplicadas até o target, sem falha de pré-requisito.** O teste executou todos os seus 89 resultados TAP: **47 FAIL e 42 PASS**, exit 1. Não houve aborto da fixture nem erro de ACL de pgTAP.

```text
Prepared 54 safe replay migrations (52 canonical + 2 preflight); profile=A01DirectoryContractRed; additional=7
Finished supabase db reset on branch main.
Failed tests: 1-4, 10-16, 20-35, 47-56, 67, 69, 75, 82-86, 88-89
Files=1, Tests=89
Result: FAIL
safe local pgTAP failed with exit code 1
```

O primeiro teste confirma a ausência de `superadmin_activity_filter_options_v2`. As demais falhas cobrem opções/hierarquia, payload e filtros em arrays, ordenação/paginação, busca literal, projeção, tipos inválidos e negativas/auditoria dependentes das opções. **Não representam 47 causas independentes**: parte é consequência do RPC ausente e do contrato ainda incompatível.

Os testes de grants 2–4 falham junto com a ausência do RPC; isso não demonstra concessão indevida. Da mesma forma, resultado nulo em filtros cross-tenant não demonstra exposição de dados. A baseline não foi adaptada para produzir GREEN.

## Cleanup e limite

Consulta independente às 2026-09-08T01:13:47.9138110Z confirmou **zero containers, zero volumes, zero redes e staging ausente** para a identidade própria. O staging histórico `coelo_safe_af5bdf571cff41309f5b6845b713a` permaneceu preservado.

A base nominal removeu do caminho os bloqueios alheios de Chat, Notices e cleanup de labels, permitindo reproduzir o contrato funcional A01. Isso não conclui a tela nem a funcionalidade. O próximo gate é receber a corretiva da E2E5 com conteúdo/hash revisados e uma nova reserva nominal. Nenhuma migration corretiva, grant novo, mutação remota, ledger ou deploy foi executado.

O README do pacote recebeu o comando e a distinção entre replay da base e resultado do contrato. Nenhuma regra de produto nova foi aprovada; não foi criada projeção de conhecimento apenas para registrar atividade.
