---
title: F-READ — seleção nominal 51 com reader auditado
source: Reserva do Coordenador; reader897ee8f7/blob a40bfb84; gates estáticos do harness
status: preparação estática validada; execução não realizada
generated: 2026-09-07
---

# FReadDirectoryContractGreen

O nome do perfil identifica a seleção com reader; **não representa resultado SQL GREEN**. O replay50 anterior abortou com 42601 na migration histórica de definição de Formulários. Esta seleção mantém esse SQL canônico e não contorna a falha.

A base contém Auth45, Forms155005/155116, helper institucional235500 e somente o reader `20260908000049_superadmin_forms_directory_internal_read.sql`: **49 canônicas + dois preflights = 51 arquivos**. As posições das adições são 42/43/46/49. A boundary Auth permanece `20260901200206`; o target único passa a `20260908000049`. Nenhuma bridge ou migration adicional é aceita.

## Snapshot nominal

| Artefato | SHA-256 normalizado CRLF/UTF-8 |
|---|---|
| Invoke-SafeLocalMigrationReplay.ps1 | 506bcefca612fed8019a2e605166a2c20d08b7d2c1e97a2eac869534fa146319 |
| Prepare-SafeMigrationReplay.ps1 | 055e561cb15058531611c5f6c515963eeddac2e47dbd34851ee9a50f49477e5e |
| FReadDirectoryContractGreen.Tests.ps1 | 8d4ff834d7bc514f4f25038d86369d7a37fa4dfa31167ccef453d9e4dbd5aa48 |
| Resolve-FReadDirectoryContractGreen.ps1 | 4c706a2e634c062264aca4438d2350985b752b85acfe30089e80021ce0b46812 |
| profile.json | baa720662ebb022633d01f2ce512b613a681046a39ff9ada97ba9abc510e6fda |
| Reader20260908000049 | 8900f60c8951efd20550a918684b335d10d3bf77d90fc4676a9381d16b27a119 |

O reader foi materializado do snapshot `897ee8f7972f17251290cbe8cad5f08fc353f9cd`, blob `a40bfb84a9e782a539d1a76d8e1c49a9ead00076`. A fixture preservada no pacoteRED tem blob `abe0c8c2d835c9d9e577db965b33b301d0e79ad0`, SHA LF `c2758681c420651557cfff9078651cb60a74a9b4cb98fa75fb2f38094b83c986` e 117 asserções previstas, ainda não executadas.

## Validação e limites

O RED inicial do seletor teve 28 falhas por ausência da opção e um controle PASS. Após integração mínima, o writer obteve 29/29 focais + 131/131 regressões. O root executou a suíte dos perfis integrados independentemente: **160/160 PASS**, zero falhas/skips, 109,16 segundos; parse 4/4 PASS. A única exclusão foi `ModelReadAuthorizationRed.Tests.ps1`, que pertencia a uma próxima fatia ainda sem integração.

O delta compartilhado acrescenta somente a opção nominal e um caminho literal ao switch de cada entrypoint. Os testes verificam o reader obrigatório, bytes, alvo único, adições, confinamento e rejeição de mutações. As APIs AuthOnly/AdditionalMigration permanecem as existentes.

A revisão independente foi aprovada para preparação: conferiu 51/51 hashes SQL e demonstrou em memória que remover apenas as duas entradas nominais recupera os hashes anteriores de Invoke/Prepare, incluindo o caminho AuthOnly + Users48 preservado.

Nenhum Docker, SQL, ledger ou deploy foi executado por esta fatia. A correção local derivada da sintaxe histórica foi autorizada posteriormente para preparação e prova de parser, com revisão e liberação próprias antes de replay. Não integra este perfil nem modifica a fonte canônica.

README e plano próprio registram essa distinção. Nenhuma regra de produto foi criada; a memória de produto não recebe registro de atividade.
