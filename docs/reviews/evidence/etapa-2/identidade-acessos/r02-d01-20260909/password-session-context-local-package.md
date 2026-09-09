---
title: "D01 — pacote local reservado de sessão password"
source: "password-session-context-proposal.md; D00 assignment r9, r10 e r11 ACKs de 2026-09-09; packages/coelo_database/migrations/20260909173000_superadmin_password_session_context.sql"
status: "prepared-not-executed"
generated_at: "2026-09-09"
---

Etapa 2 → apps/superadmin → Auth → Redefinir senha → confinamento backend de
recovery → `auth.reset`, dependência de `auth.login`/contexto produtivo.

A reserva local r9 permitiu materializar o SQL proposto no nome canônico
`20260909173000_superadmin_password_session_context.sql`. O ACK r10 autorizou
alinhar os fixtures do TAP Auth compartilhado e acrescentar os seis gates AMR,
preservando os 30 IDs originais. Os arquivos foram preparados, sem executar SQL
ou iniciar Docker. O slot de replay permanece coordenado por D00; a reserva
não autoriza mutação remota.

O único TAP selecionado é `superadmin_internal_auth_context_test.sql`, plano
36: os 30 IDs originais, dois AMRs password nos fixtures válidos existentes e
seis gates adicionais de autorização/auditoria. As outras 36 suites candidatas
não foram alteradas. O TAP exclusivo de seis casos foi movido, com autorização
e paths conferidos, para `retained-superadmin-password-session-context-test.sql`
nesta pasta de evidência; não será executado nem contado novamente.

`Test-LocalAuthRecoveryBoundary.ps1` está preparado em dois modos:

- Observador: mantém os três gates baseline e não faz PUT. Exit 0 significa
  observação/cleanup executados; um gate RED continua RED.
- `AssertConfined`: exige negativa exata, sem contexto e com
  `SAI_SESSION_INVALID`, para recovery original, refresh e após metadata
  mutável efetivamente atualizada na API do provedor. Também prova contexto
  password original/após refresh, PUT de senha legítimo, logout seguido de
  recusa do refresh token e novo login password com contexto produtivo.

O modo de assert tem nove gates emitidos: password-control,
refreshed-password-control, recovery-before-reset,
refreshed-recovery-before-reset, mutable-metadata-recovery-before-reset,
confined-recovery-password-update, recovery-after-reset-before-logout,
post-reset-recovery-logout,
new-password-login. Ainda não foram executados. Não contar o marcador final
agregado como um décimo teste. O log baseline e seus hashes permanecem intactos.

SHA-256 da preparação:

| Artefato | SHA-256 |
| --- | --- |
| migration canônica | `A57E3F85C3906F2E83F28AE90BFBFD58E10BED6A25AFA8352019DF0210342BD8` |
| TAP Auth compartilhado, plano 36 | `DC3EDBD471306174ED866BCA3EA337594D822F052903B4C4F25BE7EC351E4D1D` |
| script focal HTTP | `C51BA5858C1D2C1008F733C78EF949F3B09AF8312D9BF8762C3A92BFEB5A02BE` |
| wrapper WIP entregue ao MAIN, hash anterior à edição central | `13FFE2C4DC08E80751D97BF934B6511BD4F896A471FF1BB3F0ECFCC47C27B00D` |

Parser do PowerShell e `git diff --check` passaram. Não há resultado de SQL,
HTTP pós-fix ou deploy. Quando o slot e o uso do wrapper forem liberados, a
execução planejada usa `AuthOnly`, o adicional nominal por hash, somente o TAP
Auth de 36 casos e `RunAuthRecoveryBoundary -AssertAuthRecoveryConfined`.
O wrapper foi assumido pelo MAIN e requer hash final da composição central.
O lifecycle completo não será repetido. Os 30 casos anteriores voltam nesta
campanha porque o guard de sessão mudou; não são somados como novos IDs.

Plano atual: 36 gates pgTAP + nove gates HTTP + um gate composto Flutter/BE =
46 gates únicos, zero executados
na base corrigida até este recibo. Os quatro testes de classificação do runner
são evidência separada de ferramenta, não incrementam os 46 gates do plano.
Comando previsto, sujeito à liberação do slot D00 e wrapper central:

```powershell
rtk proxy powershell -NoProfile -File packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 -TargetVersion 20260909173000 -AuthOnly -AdditionalMigration '20260909173000_superadmin_password_session_context.sql|a57e3f85c3906f2e83f28ae90bfbfd58e10bed6a25afa8352019df0210342bd8' -TestPath packages/coelo_database/supabase/tests/superadmin_internal_auth_context_test.sql -RunAuthRecoveryBoundary -AssertAuthRecoveryConfined
```

Achado AAL ausente permanece separado e não corrigido neste pacote. Nenhum
novo requisito de MFA ou login passwordless foi introduzido. Memória: no-op.

Revisão das provas antes da execução:

- PASS na observação de recusa exige exatamente `ok=false`, `data=null` e
  `SAI_SESSION_INVALID`. Outros erros são inconclusivos; contexto produtivo é RED.
- A recusa do refresh após logout exige HTTP 400 e `error_code` igual a
  `refresh_token_not_found` ou `session_not_found`. A fonte primária
  [GoTrue v2.196.0 tokens/service.go](https://github.com/supabase/auth/blob/v2.196.0/internal/tokens/service.go#L190)
  associa esses códigos à ausência do token/sessão. A
  [validação da requisição](https://github.com/supabase/auth/blob/v2.196.0/internal/api/token_refresh.go#L18)
  devolve outro código para token malformado; esse caso não passa.
  O lifecycle baseline não registrou `error_code`, apenas recusas HTTP, portanto
  a allowlist acima vem da fonte versionada e ainda aguarda observação local.
- Recovery também deve continuar sem contexto imediatamente após PUT de senha
  e antes do logout; o novo login password é o único gate positivo posterior.
- O preflight da migration agora exige o MD5 do corpo completo `prosrc`
  normalizado de CRLF para LF, além dos checks de metadata/ACL/schema.
  Extração da migration canônica `20260901200206` produziu
  `5cdb28081d40e15232ef50912edd8082`, com 4711 caracteres, igual ao valor
  read-only comunicado pela coordenação. Isso impede substituir silenciosamente
  um helper com guards adicionais não revisados.

Verificação isolada da classificação (sem Docker, SQL ou HTTP): quatro fixtures
executadas contra as funções AST reais produziram RED para contexto produtivo,
PASS para a negativa exata e INCONCLUSIVE para erro diferente ou negativa com
dados. `AssertConfined` aceitou somente a negativa exata. Evidência:
`local-auth-boundary-proof-classification.txt`; 4/4 PASS do classificador,
separados dos nove gates HTTP ainda não executados.

Hook composto preparado no modo AssertConfined: depois dos nove gates HTTP,
solicita um novo recovery, aguarda mensagem Mailpit com ID distinto da primeira,
verifica a nova sessão e confere a identidade sintética pela API Auth. A janela
mínima de reenvio respeita `auth.email.max_frequency="1s"` da configuração local,
com espera restante limitada a 1100 ms. O token dedicado não é reutilizado
depois do teste Flutter; o scope real pode executar seu logout automático.

O subprocesso executa somente o teste
`cold reload storage failure: backend denies retained recovery after restart`
de `coelo_auth_recovery_cold_reload_test.dart`. A chamada usa o Dart e snapshot
do Flutter já instalados, conforme a linha efetiva do `flutter.bat`, sem shell
intermediário. URL, chave pública e ambos tokens sintéticos são passados apenas
por `ProcessStartInfo.EnvironmentVariables`; não aparecem nos argumentos,
arquivos ou logs. Stdout/stderr permanecem em memória e são descartados; o
runner emite somente PASS com exit 0 e sentinela
`D01_COLD_STORAGE_REAL_BE_PASS`, ou um código fixo de falha.

Timeout do Flutter: 120 segundos. Em timeout, o cleanup mira exclusivamente a
árvore do PID criado pelo hook, com `taskkill /PID <owned> /T /F`, espera limitada
e fallback `Kill`/espera do próprio processo. As janelas são ocultas; erro de
cleanup não pode produzir PASS. O wrapper SQL permanece sob controle do MAIN
e não foi alterado pelo hook. A variante Flutter concreta é responsabilidade do
agente de cold review; parser do hook passou, execução integrada ainda pendente.

Guard próprio r11: antes de consultar endpoints ou criar fixtures de Auth, o
script exige raiz nominal sob TEMP sem reparse point, marcador sem reparse point
e conteúdo do marcador exatamente igual ao `ProjectId`. Três fixtures TEMP
comprovaram recusa por marcador trocado, raiz junction e marcador junction;
todos os paths resolvidos ficaram sob a área nominal, e o cleanup removeu
somente os fixtures criados. Evidência `local-auth-boundary-owned-guards.txt`,
3/3 negativas PASS, limpeza comprovada, nenhum Docker iniciado. São testes do
guard da ferramenta e não aumentam os 46 gates integrados.
O mecanismo físico, comandos usados e limites da prova estão detalhados em
`local-auth-boundary-owned-guards-receipt.md`; o complemento não repetiu testes.

O SQL continua `stable` e preserva `not_after > now()` da base; nenhum ganho de
expiração após espera em lock foi implementado ou alegado nesta correção.
