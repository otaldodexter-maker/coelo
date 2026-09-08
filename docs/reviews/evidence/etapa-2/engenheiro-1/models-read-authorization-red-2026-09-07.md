---
title: Modelos READ — replay local de autorização anterior ao lookup
source: Reserva do Coordenador; fixturefa3acdba; Auth45 e migrations170731/193000; execução pelo root
status: RED funcional reproduzido; 9 PASS e 2 FAIL
generated: 2026-09-07
executed_utc: 2026-09-08T01:54:20.1018664Z
cleanup_verified_utc: 2026-09-08T01:56:41.3463502Z
---

# ModelReadAuthorizationRed

O perfil fechado seleciona **Auth45 + duas migrations = 47 canônicas + dois preflights = 49 arquivos**, com target `20260901200206`. Não inclui cleanup de labels, bridge adicional ou corretiva futura.

| Posição canônica | Migration | SHA-256 normalizado CRLF/UTF-8 |
|---|---|---|
| 45 | 20260901170731_access_profile_models_crud_and_catalog.sql | 0f82a20f05438e5711e8f4cdb61ec4ba2801be2da7f867cae4965d9f17569687 |
| 46 | 20260901193000_name_access_profile_model_rpc_arguments.sql | 13be08a98dda8e65f8d6e064ca438095d7d21f73b0ba7ed747b1610997c7fc39 |

As adições ficam após denial_audit20260901124500 e antes da policy MVP20260901200206. O timestamp correto da primeira é **17:07:31**; o comentário legado da fixture abrevia incorretamente como171731, sem afetar a seleção nominal.

## Gates do harness

O writer reproduziu 26 falhas por seletor ausente e um controle PASS; o resolver direto confirmou seleção e hashes. O root integrou somente uma entrada na ValidateSet e um caminho literal em cada switch de Invoke/Prepare, após verificar os hashes anteriores.

O root executou **187/187 Pester PASS**, zero falhas/skips, 143,77 segundos: suítes já integradas160 + novos27 de Modelos. Os arquivos de materialização FRead ainda em autoria foram excluídos. Parse4/4 PASS.

A revisão independente conferiu 49/49 hashes SQL, nomes, versões, posições, preflights e confinamento. Remover apenas a entrada ModelRead em memória recuperou os hashes de GREEN51, preservando AuthOnly/AdditionalMigration, perfis prévios, mutex e cleanup.

| Artefato | SHA-256 normalizado CRLF/UTF-8 |
|---|---|
| Invoke-SafeLocalMigrationReplay.ps1 | dffe6d45e6972100d8b7628e1af37ea24ffb700265005b55c449b6589286a960 |
| Prepare-SafeMigrationReplay.ps1 | 57f2109eb75178d5134fe4d8509450838e4b1b4d610f7f41c0526361ee88ac17 |
| ModelReadAuthorizationRed.Tests.ps1 | 3678505170f283c354c3aed4d683639745528ff51510a2b7ab9e146cfd0e0b19 |
| Resolve-ModelReadAuthorizationRed.ps1 | 6ecb064ce8a6755caf08b8bc264168432ff9dea4d46ea4f0f0cdc89ca68bb1f6 |
| profile.json | 1435a23d80b419ff31cf592aaac1a73f358f5dc5c900d1de89d981a1d43b6799 |

## Fixture e resultado

A fixture `access_profile_models_read_authorization_test.sql` foi materializada do snapshot `fa3acdba232e77cdc10c2845a9da4cf99c549f78`, blob `b8f6c6809c952d2ffbcaa7c53644ea47fc743b57`. Seus 8.611 bytes LF têm SHA `fa1b23feb4089ae597b6cc4592ff66d51bb6d6f7ae11d3a7b6ad32e8e8d2b81b`; CRLF `271aa5aca557f53ce6a9017cf6d3c29d40aa6498263deded26a7b31469f62543`.

São quatro blocos authenticated, todos com TAP após RESET ROLE; 11 asserções. A fixture mantém Owner interno AAL1 sem people, uma contraprova global, três domínios, negativas de sessão/capability e auditoria do ator interno.

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 `
  -NominalProfile ModelReadAuthorizationRed `
  -TestPath packages/coelo_database/supabase/tests/access_profile_models_read_authorization_test.sql
```

Início `2026-09-08T01:54:20.1018664Z` (22:54:20 BRT). Identidade `coelo_safe_9e2db95db1a348cea1a22fb01ebb4`, staging criado às `01:54:24.3469896Z`, marcador conferido durante a execução.

**A base49 aplicou integralmente.** Todos os 11 TAP foram emitidos: **9 PASS, 2 FAIL**, exit1, sem aborto ou falha ACL.

| Assert | Obtido | Esperado |
|---|---|---|
| 5 — sessão inexistente, detalhe existente/inexistente | SAI_SESSION_INVALID / SAI_PERMISSION_DENIED | SAI_SESSION_INVALID em ambos |
| 7 — pessoa global, detalhe existente/inexistente | SAI_INTERNAL_CONTEXT_DENIED / SAI_PERMISSION_DENIED | SAI_INTERNAL_CONTEXT_DENIED em ambos |

Os demais nove controles passaram, incluindo os readers autorizados nos três domínios, list/catalog, negativa por capability e auditoria interna. A causa localizada é o lookup que lança P0002 antes de autorizar o detalhe inexistente; o handler converte esse erro em SAI_PERMISSION_DENIED. Não foi aplicada corretiva nem adaptada a baseline.

## Cleanup e próximo gate

Verificação independente às `2026-09-08T01:56:41.3463502Z` confirmou **zero containers, volumes e redes próprios; staging ausente**. O staging histórico `coelo_safe_af5bdf571cff41309f5b6845b713a` foi preservado.

O próximo gate pertence à E2E1: corretiva nominal para a ordem entre autorização e lookup, seguida de validação local autorizada. Este resultado não conclui o E2E da tela. Não houve mutação remota, grant novo, ledger ou deploy.

README e plano próprio foram atualizados; os rastreadores centrais permanecem com o Coordenador. Nenhuma regra nova de produto foi criada; não houve projeção de conhecimento para registrar atividade. A indicação de E2E2 na evidência Usersmin anterior foi corrigida para E2E1 conforme orientação central.
