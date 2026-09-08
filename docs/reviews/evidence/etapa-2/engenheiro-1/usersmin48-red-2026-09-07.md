---
title: Usersmin — RED local de minimização da listagem interna
source: Reserva do Coordenador; fixture a763c6f9; base Auth45 e Users20260901210000; execução pelo root
status: RED funcional reproduzido; 1 PASS e 2 FAIL
generated: 2026-09-07
executed_utc: 2026-09-08T01:47:06.8708602Z
cleanup_verified_utc: 2026-09-08T01:49:31.1206583Z
---

# Usersmin48

O replay nominal usa a mesma base **Auth45 + Users + dois preflights = 48 arquivos**, com alvo `20260901210000`. A migration `20260901210000_superadmin_internal_users_directory.sql` mantém SHA CRLF `b1f62d73704638c72f8230ae1457da7345842d5997cca075564a7ad67e999db7`.

Este pacote executa somente a fixture separada de três asserções. **Não repete nem substitui os 45 testes de Users já entregues.**

## Inputs e revisão

Fixture: `superadmin_internal_users_read_minimization_test.sql`, snapshot `a763c6f9cd1a6c6845ca2add25f3249817ebfba2`. Os 3.567 bytes LF foram conferidos em disco:

- LF: `3f63667461cb3aa52f6bd363319d9f06810ebf8504776a740570156a690e71f3`.
- CRLF: `36e18990df12d3bef8f3979a94f473ab55d2205530e8d17eea7b94de88325820`.

A revisão central e a independente confirmaram chamadas/captura de papel sob authenticated, três TAP e finish após RESET ROLE, sem grants novos. A identidade parcial da fixture é válida no schema: membership não exige auth-link.

O snapshot do wrapper usado foi o revisado na preparação FRead51: Invoke `506bcefca612fed8019a2e605166a2c20d08b7d2c1e97a2eac869534fa146319`, Prepare `055e561cb15058531611c5f6c515963eeddac2e47dbd34851ee9a50f49477e5e`. Root160/160 Pester, parse4/4 e review de preservação do caminho AuthOnly/AdditionalMigration aprovados antes da execução.

## Resultado observado

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901210000 `
  -AuthOnly `
  -AdditionalMigration '20260901210000_superadmin_internal_users_directory.sql|b1f62d73704638c72f8230ae1457da7345842d5997cca075564a7ad67e999db7' `
  -TestPath packages/coelo_database/supabase/tests/superadmin_internal_users_read_minimization_test.sql
```

Início `2026-09-08T01:47:06.8708602Z` (22:47:06 BRT). Identidade `coelo_safe_5aeaaacdbcb14345b204c66812b84`; staging criado às `01:47:12.2860009Z`, marcador de propriedade conferido durante a execução.

**A base48 aplicou integralmente.** A fixture emitiu todos os três resultados: **1 PASS, 2 FAIL**, exit1, sem aborto de fixture ou ACL.

| Assert | Resultado real |
|---|---|
| 1 — ator interno autorizado sob authenticated, payload com items e sem error | PASS |
| 2 — exclusão de identidade sem auth-link de items/total/paginação | FAIL |
| 3 — email mascarado em todos os ramos, incluindo invitation | FAIL |

```text
Finished supabase db reset on branch main.
Failed tests: 2-3
Files=1, Tests=3
Result: FAIL
safe local pgTAP failed with exit code 1
```

A análise estática localiza as causas: seleção/count não exige auth-link, enquanto a projeção usa inner join obrigatório e pode retornar SQL NULL; o agregado pode incluir esse null. O ramo `invitation.email` devolve email completo, enquanto `identity.professional_email` o mascara. O log pgTAP confirma os invariantes falhos; não imprime o payload completo. O teste não prova paginação entre múltiplas páginas nem minimização de todos os campos pessoais.

## Cleanup e próximo gate

Verificação independente às `2026-09-08T01:49:31.1206583Z`: **zero containers, volumes e redes próprios; staging ausente**. O staging histórico `coelo_safe_af5bdf571cff41309f5b6845b713a` foi preservado.

A próxima fatia é a corretiva nominal da E2E1, com hash/review e novo teste local autorizado. Nenhuma correção SQL, mutação remota, grant, ledger ou deploy foi executado; este RED não altera a entrega Users45 anterior nem conclui E2E de tela. Plano próprio atualizado; rastreadores centrais continuam sob autoria do Coordenador. Nenhuma regra nova de produto foi criada nem projeção de conhecimento de atividade.
