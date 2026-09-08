---
title: N01 — diagnóstico local dos pré-requisitos de Avisos
source: Reserva nominal do Coordenador; scripts e SQL canônicos; Pester; execução Docker isolada pelo root
status: RED de dependência reproduzido; harness validado localmente
generated: 2026-09-07
executed_utc: 2026-09-08T00:28:14.2456650Z
cleanup_verified_utc: 2026-09-08T00:30:09.4247658Z
---

# N01PrerequisitesRed

O perfil fechado preparou 52 arquivos: Auth45, cinco migrations canônicas de Avisos e os dois preflights herdados. O target solicitado foi `20260901200206`; o replay parou antes dele, no primeiro pré-requisito ausente. Não foram acrescentadas pontes, a migration corretiva N01 ou SQL externo ao descriptor aprovado.

## Harness e verificação

- Antes da implementação, o writer executou 23 casos Pester e registrou 23 falhas pela ausência de `NominalProfile`.
- O primeiro GREEN focal passou 23/23. Review identificou a necessidade de verificar o arquivo do resolver e seus ancestrais antes da execução. A fixture adicional reproduziu três falhas e manteve um controle positivo.
- O ajuste ficou restrito ao modo nominal. O writer reportou 62/62 PASS e parse 4/4; o reviewer conferiu diff, hashes, seleção e correção dos caminhos, sem bloqueadores.
- O root executou independentemente todo o diretório de testes do harness: **77/77 PASS, zero falhas e zero skips**, em 50,79 segundos. Incluiu 27 casos N01 e regressões dos perfis, Auth, Atividades e modo CLI.
- Os testes usam cópias TestDrive; os casos Invoke param em sentinela anterior ao mutex e ao Docker. Reparse é simulado por metadata, sem criar links reais.
- O modo nominal rejeita AuthOnly, FoundationOnly, adições livres, lifecycle de Auth e concorrência de Atividades. Descriptor, manifesto e todos os 52 inputs são validados antes de criar staging ou consultar Docker. Os guards existentes de isolamento, no-seed, mutex e cleanup permanecem no fluxo.

Hashes normalizados CRLF/UTF-8 sem BOM do snapshot revisado:

| Artefato | SHA-256 |
|---|---|
| Invoke-SafeLocalMigrationReplay.ps1 | b49da451eeb99e485746456ae992811c2825790a7ef89b47af7c021097075fa9 |
| Prepare-SafeMigrationReplay.ps1 | 28d3c555b09973c861981f9a02cf0a6138501ded150c6b52a2be68f5d1dcbeda |
| N01PrerequisitesRed.Tests.ps1 | a2b4a1bf998bb49541eb00106166d9f36034487510b69acaee61d1131cc07d32 |
| Resolve-N01PrerequisitesRed.ps1 | e31282d896657d28461fc467defb2bc9fd18033c12dac7e8a148552d09362c03 |
| profile.json | 4907bca493852aabf388806c56bec617fcb7479190bc09be6ab1392c7e004ac8 |
| foundation-migrations.sha256 | 4279e67c9651f4049329591b6e8aad82e3a9052506c1a4e16ba8bbb693249d59 |

## Execução efetiva

O root foi o único operador Docker. Contexto `desktop-linux`, daemon Linux 29.7.2; CLI Supabase 2.116.0 fixado pelo wrapper. A execução começou em 2026-09-08T00:28:14.2456650Z (21:28:14 BRT de 7 de setembro).

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 `
  -NominalProfile N01PrerequisitesRed
```

Identidade: `coelo_safe_54154a03ddd946bba8e2c211dd652`. Staging criado em 2026-09-08T00:28:20.0541997Z; o root conferiu seu marcador de ownership durante a execução.

Saída decisiva:

```text
Prepared 52 safe replay migrations (50 canonical + 2 preflight); profile=N01PrerequisitesRed; additional=5
Applying migration 20260812002900_notices_status_values.sql...
Applying migration 20260812003000_notices_production.sql...
ERROR: relation "public.notice_events" does not exist (SQLSTATE 42P01)
At statement: 22
drop policy if exists notice_events_platform_read on public.notice_events
safe local db reset failed with exit code 1
```

O processo encerrou com **exit 1**, esperado neste diagnóstico. A migration de fronteiras canônica move a tabela para `analytics`; a migration histórica de Avisos ainda requer `public.notice_events`. Não se tratou de falha funcional de publicação ou de teste E2E. Nenhuma expectativa de 23502 foi forçada: Auth45 exclui a cleanup de labels e mantém os defaults do preflight herdado.

## Cleanup e limite da entrega

Consulta independente às 2026-09-08T00:30:09.4247658Z confirmou **zero containers, zero volumes, zero redes e staging ausente** para a identidade gerada. O staging histórico alheio `coelo_safe_af5bdf571cff41309f5b6845b713a` permaneceu preservado.

Este resultado fecha somente o harness e o diagnóstico do primeiro pré-requisito. Não valida Avisos, worker, materialização de recibos ou tela ponta a ponta. Não houve acesso a dados de produção, mutação remota, alteração de ledger ou deploy. O próximo gate é uma revisão nominal separada de eventual ponte transitória, suas condições de remoção e a correção N01 da frente responsável.

A documentação canônica do pacote recebeu o comando e o limite desse diagnóstico. Nenhuma regra de produto nova foi aprovada; não foi criada projeção de conhecimento apenas para registrar atividade.
