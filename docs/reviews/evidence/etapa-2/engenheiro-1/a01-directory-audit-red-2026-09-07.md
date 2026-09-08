---
title: A01 — RED local de auditoria dos readers v2
source: Reserva do Coordenador; base54 e corretiva2fd8227d; fixture97ee212cb5; execução pelo root
status: RED funcional reproduzido; 91 PASS e 6 FAIL
generated: 2026-09-07
executed_utc: 2026-09-08T02:18:38.8591511Z
cleanup_verified_utc: 2026-09-08T02:22:12.9588312Z
---

# A01DirectoryAuditRed

O perfil fechado mantém a base A01DirectoryContractRed54 e acrescenta **somente** `20260907222911_superadmin_activity_directory_v2_client_contract.sql`: **53 canônicas + dois preflights =55 arquivos**, com target único `20260907222911`. A corretiva ocupa a posição canônica53; as sete Activities herdadas permanecem nas posições44–50. Não há bridge extra.

O objetivo desta fatia é medir auditoria dos readers. O nome e o resultado RED não devem ser confundidos com conclusão funcional de Atividades.

## Snapshots exatos

Migration v1: commit `2fd8227d83a0c286b73ca8a0985d6f542280af3b`, blob `f9e3e99aea883c54a42aff7aae76a1ca96119e7b`.

- LF: `6770c9bcbf5a3c3f6560021c0ca6e03d7bb1f12449878a2e98df64105cc04f92`.
- CRLF: `77b248f6d60661ebf1fff941107b8fd148d9e2a19e9c27d1b4f45be01571847f`.

Fixture97: commit `ee212cb56e9dc18400a8d105aeeba3a5f77bbbf4`, blob `3d7d25ab24a738a03a1f1f11e4a500c13706ca6a`, mesmo TestPath `superadmin_internal_activities_v2_directory_contract_test.sql`.

- 38.905 bytes LF; SHA `fc492972051e741e37d0dd7b1d7056eec24a57c4b02e98bb6ffccb9a4ca3b3b1`.
- CRLF: `f028b86a065f7ea50c1447a62a2b0131ec8cc9119f117c5947355979b1c9648f`.

A fixture acrescenta 71 linhas e oito TAP. Remover apenas esse bloco recupera exatamente o blob89 `c208b711270720094bb1e6d7abc9f8b546a3de8d`, idêntico tanto no RED original e927c417 quanto no parent2fd8227d. Os 89 testes anteriores foram preservados.

## Gates do harness

| Artefato | SHA-256 normalizado CRLF/UTF-8 |
|---|---|
| Invoke-SafeLocalMigrationReplay.ps1 | 6059420f263892da812bf066323883be782e3ab779b552f2039d610e52eb4c7c |
| Prepare-SafeMigrationReplay.ps1 | 0a6f24b09508c4bf94cea8d0cef84c553447dd87dc504cff715d1609f5fb50ea |
| A01DirectoryAuditRed.Tests.ps1 | 808de5aca82c3ca1f36282ea241758bcef23603bc9621098fd17fc3318e6b973 |
| Resolve-A01DirectoryAuditRed.ps1 | f5ae75b900d2c571e784b89f3718c77acc6df41dc7a39aa5e88c10fc16578750 |
| profile.json | c850cec6380744d71a1c390cf0010d81d5fbd3f5a9b21cdeeb8e02051dc05648 |

Writer: 28 falhas esperadas por seletor ausente e um controle PASS; depois **29 focais +204 regressões rastreadas =233/233 PASS**, zero falhas/skips, excluído somente o perfil FReadDerived ainda em autoria. O root executou independentemente os **29 focais:29/29 PASS**, 22 segundos, e reconferiu sete hashes de runtime e parse4/4.

A revisão independente verificou 55/55 hashes SQL e o delta mínimo de allowlist/switch. Identificou e corrigiu uma expectativa no teste de migration alvo ausente: o guard de target do Invoke precede o resolver. A revisão confirmou que esse foi o único ajuste do teste e que os demais perfis, guardas, mutex e cleanup permaneceram preservados.

A fixture usa sete blocos authenticated, nenhum TAP sob esse papel. Criação/remoção do trigger de falha, leitura da auditoria e TAP ocorrem após RESET ROLE. As capturas exigem a exceção P0001/A01_AUDIT_FAILURE exata; erros ACL diferentes não produzem PASS.

## Execução real

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260907222911 `
  -NominalProfile A01DirectoryAuditRed `
  -TestPath packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_directory_contract_test.sql
```

Início `2026-09-08T02:18:38.8591511Z` (23:18:38 BRT). Identidade `coelo_safe_62c1841331af48739c1e2b4bea00f`; staging criado às `02:18:44.3787725Z`, marcador conferido durante a execução.

**A base55 e a v1 aplicaram integralmente. Todos os 97 TAP foram emitidos:91 PASS/6 FAIL**, exit1. Não houve aborto ou erro ACL.

| Asserções | Resultado real |
|---|---|
| 1–89 — contrato anterior | 89 PASS |
| 90 e95 — ator real authenticated nas novas chamadas | 2 PASS |
| 91–92 — auditoria interna correlacionada dos dois readers | 2 FAIL |
| 93–94 — auditoria com somente contagens minimizadas | 2 FAIL |
| 96–97 — falha do append propagada sem envelope de sucesso/dados | 2 FAIL |

No ensaio de falha, os dois RPCs devolveram `ok:true` com dados, em vez de `P0001/A01_AUDIT_FAILURE/data:null`. A v1 apenas retorna success_envelope; não chama append de sucesso, portanto o trigger que simula a falha de auditoria não chega a ser acionado. Esse resultado não prova que um append executado foi engolido; prova que os readers ainda não passam por ele.

## Cleanup e próximo gate

Verificação independente às `2026-09-08T02:22:12.9588312Z`: **zero containers, volumes e redes próprios; staging ausente**. O staging histórico `coelo_safe_af5bdf571cff41309f5b6845b713a` permaneceu preservado.

Próxima fatia: E2E5 entregar a corretiva de auditoria com snapshot/hash/review para nova validação nominal. Não houve alteração da v1, grant novo, mutação remota, ledger, deploy ou conclusão E2E da tela.

README e plano próprio atualizados. Nenhuma regra nova de produto foi criada; não houve registro de atividade na projeção de conhecimento.
