---
title: F-READ — preparação nominal do reader na base derivada51
source: Autorização do Coordenador; baseb236f2c6/9a969eee; reader897ee8f7; writer/reviewer independentes; gates root
status: preparação local; execução SQL depende de liberação nominal
generated: 2026-09-08
---

# FReadDirectoryContractGreenDerived

O novo seletor mantém os50inputs do RED derivado e acrescenta somente20260908000049_superadmin_forms_directory_internal_read.sql. São49canônicas+2preflights=51, target20260908000049. A cópia local155005 recebe os mesmos quatro parênteses; os50outros arquivos são preservados byte a byte. O nome GREEN não implica resultado funcional: nenhum replaySQL51 foi executado nesta preparação.

O RED derivado50 já aplicou integralmente e alcançou duas asserções de ausência do reader, abortando na terceira chamada por undefined_function. Este pacote prepara o próximo teste com a fixture117 imutável.

## Pins finais

| Artefato | SHA256 CRLF UTF8 sem BOM |
|---|---|
| Descriptor GreenDerived51 | b6b1232c7e67e978747b784ba71de43afd8e85b3102645d91d53c66a457b2542 |
| Resolver GreenDerived51 | d8caf37a298f8d92348613f21af79b3de4afb08224554736f3b802b51d66690b |
| Pester41 | 4ab1b8ca69f6ec9e41a0c3e0ad8c1053402f7f7d478b52422ae4835fa65eae37 |
| Invoke | 08910d32466dca81cc64194063547d0f9f7d8642ce23820b0e0b87d09a8b0261 |
| Prepare | 0251aad3e50d2f8659c183a4978163116244ca964a00a99038da618899486861 |
| Descriptor pai Green canônico | baa720662ebb022633d01f2ce512b613a681046a39ff9ada97ba9abc510e6fda |
| Resolver pai Green canônico | 4c706a2e634c062264aca4438d2350985b752b85acfe30089e80021ce0b46812 |
| Conversor RED existente | c3cc8e86a075c20f608d3d34ab31f1611e56f80aabfe29958832f5ab05982dc5 |
| Source155005 | 3a3d2bd348948cdef78a3a0c712c9eae8a6a6fb8be59b8fd942a445f6cbb6e36 |
| Derived155005 | 06b71570bbb25c84efe5efed6a6d1f2416a33a5a6fdf71bc20b4776d01833dfe |
| Reader20260908000049 | 8900f60c8951efd20550a918684b335d10d3bf77d90fc4676a9381d16b27a119 |
| Fixture117 | ef8b3003895e2492ce392c7d1b1c1e6d0ba9d1953a93076607cf33c9a847ffb5 |

Reader e fixture são do commit897ee8f7972f17251290cbe8cad5f08fc353f9cd, blobs a40bfb84a9e782a539d1a76d8e1c49a9ead00076 e abe0c8c2d835c9d9e577db965b33b301d0e79ad0. Fixture real35594bytesLF/c2758681c420651557cfff9078651cb60a74a9b4cb98fa75fb2f38094b83c986.

## Delta e gates

Invoke: somente allowlist e caminho literal. Prepare: os mesmos itens e exatamente duas condições por lista literal RedDerived/GreenDerived para materialização e para não recopiá-la. O corpo de validação de recibo, hashes, destino TEMP/reparse, arquivo real, delta4 e origem intacta continua igual. O comentário agora diz remaining input copies, abrangendo os dois totais.

O resolver novo usa o pai Green fixado e o conversor existente no diretório RED, sem copiá-lo. Valida ambos antes de execução do pai; não materializa SQL. Nenhuma seleção ocorre por metadados abertos.

- Autor: RED23 por resolver ausente, depois23/23PASS. Três expectativas de mensagem herdadas de Red foram corrigidas somente no Pester para o pai Green.
- Root antes da integração:41casos,23PASS/18FAIL exclusivamente por seletor ausente,zeroSKIP,28.8365586s.
- Root após integração:41/41PASS,zeroSKIP,43.3116846s; incluindo reader ausente/hash incorreto e recibos/arquivos adulterados.
- Root:4PS+JSONparsePASS e cinco hashes finais conferidos.
- Revisão independente final aprovada: revertendo em memória só os itens indicados, entrypoints recuperam5ef2fc4e exatamente normalizados. Demais perfis, AdditionalMigration, mutex e teardown preservados.

Regressão independente final:332/332PASS,zeroFAIL/zeroSKIP,exit0,250.2959671s de Pester (250.5108214s total),17arquivos excluindo os41jáexecutados pelo root. Total não duplicado: **373/373 Pester PASS**.

## Proposta de execução para o gate central

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260908000049 `
  -NominalProfile FReadDirectoryContractGreenDerived `
  -TestPath packages/coelo_database/supabase/tests/superadmin_forms_directory_internal_read_test.sql
```

Aguardar liberação nominal sobre commit/pins/gates. Não usar perfil50 para reader51, alterar a fixture ou improvisar dependências caso o resultado não corresponda à expectativa. Nenhuma SQLremota, grant, ledger, deploy ou conclusão E2E de tela. README e plano próprios atualizados; nenhuma regra nova de produto ou conhecimento de atividade.
