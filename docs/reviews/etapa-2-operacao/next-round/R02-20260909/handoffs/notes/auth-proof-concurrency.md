---
title: "R02 D00 — harness local de revalidação Auth pós-lock"
source: "Executor D01 corrigido; AuthOnly; Test-ActivityV2Concurrency.ps1; guard canônico internal Auth; delegação D00"
status: "prepared-local-harness; pester-pass; sql-not-executed; wrapper-hook-integrated-local"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

Recorte: apps/superadmin → Auth → provision/cleanup da persona de prova; suporte
a auth.login/recover/reset/logout. Não é execução Auth real nem aceite E2E.
Único executor SQL futuro: D00, após slot D02/D03, no replay descartável existente.

## Artefatos e prova atual

- `packages/coelo_database/scripts/Test-R02AuthProofConcurrency.ps1`:
  SHA256 `DD6B6336C967AB1A06491D0F01D6B04F2789F3898E2E696FE08131791CE8579E`.
- `packages/coelo_database/scripts/tests/Test-R02AuthProofConcurrency.Tests.ps1`:
  SHA256 `B24F1B11B9BE85B2B5E5E1F35E16A880F99C942FB3C8E5115B96DDF163DBD10C`.
- Dependência fixada, `r02-d01-auth-proof-executor.mjs`:
  SHA256 `8A5ABFBAECB1DC4134542F3F016837CC51521C3CCF1C6F61BD9DE84F45BC2E86`.

Pester atual **P8/F0/B0/S0/U0**, oito IDs únicos, exit0. Primeiro RED de arquivo
ausente foi 3P/3F; os três throws genéricos não eram provas válidas dos guards.
A suíte final exige especificamente ownership/hash, parser, seis casos no plano,
alvo recusado e geração/negação estrutural. Rerun após tornar erros específicos
não aumenta numerador. Comando observado:

```powershell
rtk proxy powershell -NoProfile -Command "Invoke-Pester -Script packages/coelo_database/scripts/tests/Test-R02AuthProofConcurrency.Tests.ps1 -EnableExit"
```

**SQL P0/F0/B0/S0/U6; executados0/plano6.** Não houve Docker, recurso SQL,
conexão remota ou uso de credencial. Nenhum teste Node existente foi reexecutado.

## Funcionamento e limites

O harness só aceita `coelo_safe_` + 29 hex, marcador `.coelo-safe-replay` exato,
diretório/marcador sem reparse point, container DB já em execução e hash nominal
do executor. Não cria/inicia containers. Importa `mutationSql` real com Node;
não reescreve SQL, não invoca o CLI remoto nem constrói JWT real.

Casos: provision-membership/session/jwt e cleanup-membership/session/jwt.
Holder segura `FOR UPDATE` no usuário sintético. Caller recebe exatamente o SQL
do executor, com application_name local. O monitor exige blocker correspondente
em `pg_blocking_pids` e `wait_event_type='Lock'`. Revogação confirma commit de
membership enquanto caller espera. Expiração começa válida e vence por relógio
real durante espera, sem mudar sessão após início da transação do caller.

O timeout de lock original de 5s não é ampliado; horizonte de expiração é 3s.
Se o host não observar a espera ou não alcançar o cenário no prazo, falha de
infraestrutura não vira PASS de autorização. Negativa aceita somente
LIVE_OWNER_REQUIRED/SAI_MEMBERSHIP_REVOKED/SAI_SESSION_INVALID, nunca lock timeout,
deadlock ou statement timeout. Após rollback, confere contagens, versões/status,
sessões e ausência de audit success. Receipt final traz hash do SQL gerado por
caso, clock observado, lock confirmado e invariantes. Erro interrompe a rodada
do harness; não contar os casos restantes como executados.

O código continua dependendo de prova PostgreSQL real: Pester não demonstra
visibilidade do helper STABLE após lock. Este é justamente o gate a executar.
As races residuais entre APIs e entre checks não são eliminadas pelo harness.

## Fixtures e cleanup

Todos os usuários locais usam `@invalid.test`; dois Owners sintéticos permitem
revogar o ator sem desativar a proteção de último Owner. O segundo Owner não
é sessão/identidade real. IDs existentes da persona, Owners ou role nominal
causam colisão fatal; INSERTs restantes também falham atomicamente se colidirem.

O executor fixa UUID remoto de operations, enquanto AuthOnly cria UUID aleatório.
Para preservar SQL real, a fixture salva temporariamente o code local operations
como r02-saved-operations e cria papel sintético com UUID nominal e somente
platform.read. O finally renomeia o sintético para r02-proof-operations e restaura
operations original. Executar **após todos os testes/lint do wrapper**, sem outro
writer no replay. Nenhuma role/permissão é criada no remoto. Não reusar o volume
para nova tentativa: fixtures deliberadamente colidem em replay repetido.

Todos os psql próprios são fechados/terminados no finally; roles seeded têm os
codes restaurados. Linhas sintéticas e evidência permanecem apenas no volume
descartável até teardown já obrigatório do wrapper, que limpa exclusivamente
o project_id com marcador verificado. Não há DELETE de auditoria nem remoção de
recursos de outros projetos. Falha de restauração impede alegar cleanup completo.

## Hunk aplicado no wrapper existente

Em `Invoke-SafeLocalMigrationReplay.ps1`, novo switch explícito junto aos switches
RunAuthLifecycle/RunActivityV2Concurrency; não criar perfil paralelo:

```diff
   [switch]$RunAuthLifecycle,
+  [switch]$RunR02AuthProofConcurrency,

   [switch]$RunActivityV2Concurrency
```

Depois do guard RunAuthLifecycle/AuthOnly, antes de qualquer recurso:

```powershell
if ($RunR02AuthProofConcurrency -and (
    -not $AuthOnly -or -not $RunAuthLifecycle -or $FoundationOnly -or
    $NominalProfile -or $AdditionalMigration.Count -gt 0 -or
    $RunActivityV2Concurrency -or $TargetVersion -ne '20260901200206')) {
  throw 'R02 Auth proof concurrency requires exact AuthOnly lifecycle base without additions'
}
```

No final do try, **depois de RunLint**, antes de catch/finally:

```powershell
if ($RunR02AuthProofConcurrency) {
  & (Join-Path $scriptRoot 'Test-R02AuthProofConcurrency.ps1') `
    -ProjectRoot $projectRoot `
    -ProjectId $projectId `
    -ExpectedExecutorSha256 '8A5ABFBAECB1DC4134542F3F016837CC51521C3CCF1C6F61BD9DE84F45BC2E86'
}
```

Integracao validada: dois testes novos RED antes do hunk, GREEN depois; oito casos finais PASS. XML auth-proof-harness-wrapper.xml registra a execucao.
Hash divergente após revisão deliberada requer nova verificação nominal, nunca
aceitação automática do hash encontrado. Comando futuro, somente após integrar
hunk e conceder slot, em packages/coelo_database:

```powershell
./scripts/Invoke-SafeLocalMigrationReplay.ps1 -TargetVersion 20260901200206 -AuthOnly -RunAuthLifecycle -RunR02AuthProofConcurrency
```

O hunk acima foi aplicado por D00 na raiz. Nenhum dos arquivos
do executor ou dos seus documentos anteriores foi alterado por
este lote. D00 mantém stage/commit, slot e qualificação final.


## Correcao do gerador apos prova real - 2026-09-09T15:08:12-03:00

Primeiro replay AuthOnly47 aplicou migrations e passou lifecycle real GoTrue/Mailpit/PostgREST. Concorrencia parou antes do primeiro cenario com ARGUMENTS_NOT_ALLOWED: Node-e posicionava executorPath em argv1, ativando a propria guarda CLI ao importar. Nao foi falha de autorizacao nem6testesexecutados. Session13406 exit1; teardown confirmado sem container/volume/network eTEMPproprioausente. Log auth-proof-first-replay-blocked.log.

Harness corrigido sem alterar executor nominal: sentinelargv1, pathargv2, action/expiry slice3. Dois testes novos executam o generator real offline para provision/cleanup e exigem Nodeexit0, unicaJSON e SQLreal. RED8P2F; GREEN10P0F (8anteriores+2novos). Primeira saida shell1 foi warningRTK redirecionado; confirmacao explicita shell0 ja emcurso terminou sem aumentarcontagem. Logs/XML auth-proof-generator-{red,green,green-confirmed} preservados. SQL6 seguem bloqueados ate novo replay corrigido; dados ficticios permanecem locais e cleanup anterior confirmado.

## Fixture terminal preservada - 2026-09-09T15:23:14-03:00

Segundaexecucao33680: lifecyclePASS, erroSQLgenerico antesdeemitirresumosporcaso. Naoha resultadoindividualpreservado que permita certificar qualquer dos6; permanecemB. Cleanup confirmado para coelo_safe_575e12545cef49c383f0fecf36a43 (container/volume/networkausentes eTEMPfalse). Log auth-proof-second-replay-blocked.log. Inspecao encontrou reset de membershiprevogada, proibido pelo guardterminal canonico.

Correcaosemrelaxarguards: ordenar session/JWT antesmembership; cleanup cria nova membership503 enquanto501permanece revogada e502mantem segundoOwner. Revogacao incrementaversao. Preflight inclui503 e papeisativos. Marcadoresporcaso trazem hashSQL e quantidadeconcluida; falhas trazemfase/caso/SQLSTATE e textoallowlisted, semSQL/DETAIL/tokens. TDDoffline10P3F->13P0F, shell0, logs/XMLauth-proof-terminal-red/green. TrezeIDs totais, nao13novos. SeisSQL aguardamterceiraexecucao aposAMR; executor8A5intacto. Ausenciadediagnosticoanteriornaoeprovafalhadeproduto.
