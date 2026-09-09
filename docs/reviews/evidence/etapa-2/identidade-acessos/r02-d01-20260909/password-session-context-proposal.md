---
title: "D01 — proposta local de confinamento backend de recovery"
source: "local-auth-recovery-boundary-receipt.md; proposed-password-session-context.sql; docs/superpowers/specs/2026-07-16-superadmin-supabase-auth-design.md; docs/superpowers/specs/2026-09-01-superadmin-auth-first-local-green-design.md"
status: "proposed-not-executed"
generated_at: "2026-09-09"
---

Etapa 2 → apps/superadmin → Auth → Redefinir senha → sessão recovery antes
do reset → `auth.reset`, dependência de contexto produtivo/`auth.login`.

O SQL candidato permanece em `proposed-password-session-context.sql`, fora de
`packages/coelo_database/migrations`. Nome solicitado à coordenação:
`20260909173000_superadmin_password_session_context.sql`; a solicitação não é
prova de reserva, aplicação local ou autorização remota.

Correção mínima proposta: depois de validar `auth.sessions.id`/`user_id`/validade,
o helper privado exige que `auth.mfa_amr_claims` contenha uma linha da mesma
sessão com `authentication_method='password'`. Ausência produz o código já
existente `SAI_SESSION_INVALID`, capturado e auditado pelos wrappers atuais.
Não usa AMR do JWT nem metadado editável para conceder autorização.

Base documental: design aprovado de login de 2026-07-16 exige e-mail/senha e
`signInWithPassword`; auth-first de 2026-09-01 exige encerrar recovery após reset
e voltar ao Login. O contrato MVP posterior materializado na migration
`20260901200206` preserva AAL1/AAL2 sem impor MFA. O candidato mantém esse
comportamento e todos os checks de realm, papel, capability e tenant.
Não cria ou redefine uma política de login passwordless.

Dependências verificadas no repositório: as únicas migrations que definem o
helper são `20260827233000`, `20260901190927` e `20260901200206`; a última é a
base vigente tanto no prefixo Auth de 47 arquivos quanto no histórico completo.
`superadmin_auth_bootstrap_context` e `superadmin_auth_resolve_institution_context`
invocam esse helper. A auditoria de negação validada em `20260901124500`
continua aceitando uma sessão recovery identificável para registrar a recusa.
O schema do AMR é confirmado pelo modelo oficial
[GoTrue v2.196.0 amr.go](https://github.com/supabase/auth/blob/v2.196.0/internal/models/amr.go).

O candidato mantém a função `stable security definer`, owner `postgres`,
`search_path=''`, ACL revogada, lock transacional e timeouts. Preflight recusa
schema AMR incompatível, metadata/ACL incompatíveis, base ainda impondo MFA ou
base já contendo esse gate. Não modifica tabelas do provedor.

Riscos e próxima prova:

- Sessões sintéticas/importadas sem AMR password serão negadas. Os fixtures
  pgTAP de `superadmin_internal_auth_context_test.sql:114` e `:217` inserem
  sessões manualmente sem AMR; precisam representar login password antes de
  reutilizar a suíte na base corrigida. Não foram alterados nesta preparação.
- A prova positiva deve manter senha (inclusive refresh) autorizada; negativa
  deve negar recovery original e após refresh. O fluxo Auth de troca de senha
  precisa continuar funcional após a recusa de bootstrap.
- O nome de tabela contém `mfa`, mas exigir o método password não exige fator
  adicional. O adiamento MVP de MFA permanece intacto.
- Não foi feita prova remota de schema/ACL de AMR; todos os recursos remotos
  permanecem fora desta preparação.

`Test-LocalAuthRecoveryBoundary.ps1` agora aceita `-AssertConfined`: exige
`ok=false`, `data=null` e `SAI_SESSION_INVALID` para ambos tokens recovery; lança
erro caso contrário. Modo observador continua reportando RED sem transformar
exit 0 em PASS. Essa extensão não foi executada; somente parser e diff-check
passaram. O recibo baseline preserva o hash do script efetivamente executado
antes dessa extensão.

O wrapper não oferece `AdditionalMigrationPath`. `AdditionalMigration` aceita
somente `nome.sql|sha256`, com arquivo no diretório canônico, ordem e hash
validados. Portanto o próximo gate é confirmar a reserva e autorizar a
materialização nominal e executar uma campanha local da correção, com os
negativos pertinentes. O wrapper já oferece `AssertAuthRecoveryConfined`,
exige `RunAuthRecoveryBoundary` e encaminha `AssertConfined` ao script;
combinação inválida foi recusada antes de inicializar Docker.

SHA-256 candidato:
`C42861F3A3B7BAF56FA66ADC9B3BF2AE093D2BD7C3ED73BC41069F65915A52FA`.
SHA-256 script com AssertConfined:
`C332D98587229ACF76F4F0E37D951711C6F8FB78DB439D13ABEC698FDC834059`.
Nenhuma correção aplicada, nenhum deploy, commit ou nova projeção de memória.

Preparação adicional, ainda sem executar:

- `proposed-superadmin-internal-auth-context-test.sql` contém a suite atual com
  somente dois AMRs password nos fixtures válidos existentes e seis novos
  testes (plano 36): controle password, OTP sem password, AMR ausente, claims
  password/metadata mutável não prevalecem sobre AMR do provedor, auditoria de
  três negativas e impossibilidade de criar AMR pelo papel cliente.
- `proposed-auth-password-session-test-extension.sql` isola os seis novos
  testes para revisão. O JWT artificial do teste SQL é criado pelo harness
  privilegiado; não afirma que o cliente consiga forjar assinatura GoTrue.
- `password-session-suite-impact.md` lista 37 suites com sessão/AMR e dez com
  referência explícita a helper/RPC; zero suites existentes escrevem AMR.
  São candidatos à inspeção, não falhas comprovadas. Regressão ampla requer
  coordenação com os respectivos donos antes de alterar seus fixtures.
- Na prova HTTP real pós-fix: manter controle password e seu refresh; obter
  recovery no Mailpit e provar recusa antes do PUT; tentar `PUT /auth/v1/user`
  somente com `data` que declare autenticação password, fazer refresh e
  comprovar que a metadata mutável não libera contexto; então trocar senha
  pela API de Auth, encerrar recovery e provar novo login password permitido.
  O bootstrap recusado não pode impedir a troca legítima na API de Auth.

Achado separado preservado: `if jwt_aal not in ('aal1','aal2')` recebe NULL
quando a claim está ausente, e em PL/pgSQL `IF NULL` não entra no ramo de recusa.
O helper pode prosseguir até retornar AAL nulo; wrappers/auditoria podem falhar
depois por suas constraints, portanto isso não comprova uma resposta produtiva
com claim ausente. A condição permanece idêntica à base no candidato. Corrigir
com `jwt_aal is null or ...`, além de definir teste de envelope/auditoria, exige
decisão explícita de escopo desta rodada; não foi agregado silenciosamente.
