---
title: "D01 — recibo de Auth real local e limite da prova recovery"
source: "local-auth-lifecycle.log; packages/coelo_database/scripts/Test-LocalAuthLifecycle.ps1; packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1"
status: "local-green-bounded"
generated_at: "2026-09-09"
---

Etapa 2 → apps/superadmin → Auth → Entrar / Recuperar senha / Redefinir senha /
Sair → `auth.login`, `auth.recover`, `auth.reset`, `auth.logout`.

Recibo retrospectivo do log existente, sem repetir a execução. O log não traz
início/fim absoluto; duração total e SHA exato do checkout durante a execução
não foram registrados. HEAD observado ao preparar este recibo:
`61a58ebb9c117e519faefa7dbfe142be4a8f3313` (não equivale ao SHA executado).

- Log atual: `local-auth-lifecycle.log`, SHA-256
  `76AD0A20ACA5D88713261CD460AD064EE59B482C8A5F031E608FA956C94AE5B2`.
  Normalizado em 2026-09-09 para UTF-8 sem BOM, LF e sem espaços finais,
  sem repetir o runner ou alterar resultados. Hash histórico do arquivo da
  execução, conferido antes da normalização:
  `7ACE6EBD9B8A081A64244AC17924F2DC2D2650924B57F9CAF4225C9CC1413EDE`.
- Runner identificado: `Invoke-SafeLocalMigrationReplay.ps1`, perfil `auth`,
  `AuthOnly` + `RunAuthLifecycle`, Supabase CLI `2.116.0`; GoTrue, Mailpit e
  PostgREST reais locais, volume descartável. A linha de comando integral não
  está preservada no log.
- Fronteira: `20260901200206`; 45 migrations canônicas + 2 preflights,
  adicionais 0; manifesto SHA-256
  `4279E67C9651F4049329591B6E8AAD82E3A9052506C1A4E16BA8BBB693249D59`.
- Preflight `20260811151253_assert_function_execute_preflight`:
  `718C2DE052E9DF29ABC42642806D9A5E4D98C8964665453DE6F14F0F8B61AB75`.
- Preflight `20260811215452_access_profile_labels_replay_bridge`:
  `D97E02796FCD5897707B5657B7A1C1DF690F831E09ED98DF6ED21886F75F9EF3`.
- pgTAP: arquivo `superadmin_internal_auth_context_test.sql`, 30/30 PASS,
  0 falhos. Lifecycle: uma execução agregada PASS, sem contagem individual de
  asserts; não somar seus estágios aos 30 testes pgTAP.

O lifecycle registra login/recovery sem enumeração, rotação/recusa de refresh
antigo após logout, revogação de sessão, callback/reset/uso único/expiração,
separação de realm, Owner AAL1 sintético durante adiamento MVP, memberships
ativa/suspensa/revogada, capability, isolamento de tenant, ID alterado e auditoria
minimizada. Isso é avanço backend local; não certifica produção ou browser E2E.

Projeto descartável: `coelo_safe_dfd0dcbeab6045b78996165891fab`. O log termina
com zero recursos residuais. Reconferência somente leitura em 2026-09-09:
`docker ps -a`, `docker volume ls` e `docker network ls`, cada qual filtrado
pelo nome exato desse projeto, retornaram zero entradas e exit 0. Nenhum
recurso de outro projeto foi alterado.

Limite identificado: `Test-LocalAuthLifecycle.ps1:525` obtém recoverySession e
a linha 527 inicia imediatamente PUT de senha. Não há bootstrap antes do PUT
nem assert/leitura de AMR. Portanto este PASS não prova que token recovery
seja negado no backend antes do reset. O guard canônico
`20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql:89`
confere sessão, identidade e AAL, mas não AMR. O discriminante focal desse
gate deve ser uma evidência separada, sem invalidar os asserts verdes existentes.

Memória: no-op; nenhuma regra de produto aprovada mudou. O wrapper de consulta
`scripts/Search-CoeloKnowledge.ps1` não existe neste checkout; não foi criada
projeção para registrar atividade. Arquivo `.log` é ignorado e exige inclusão
explícita posterior pelo integrador caso componha a entrega.

Revisão do log normalizado: 78 linhas, sem JWT/Bearer, credenciais atribuídas,
e-mails, CPF formatado ou links de recuperação. A leitura também não encontrou
dados de usuários, crianças ou tenants. Duas linhas contêm caminhos locais com
o nome do perfil do host; são metadados técnicos identificáveis, preservados
nesta normalização. Não declarar ausência absoluta de PII no artefato.
