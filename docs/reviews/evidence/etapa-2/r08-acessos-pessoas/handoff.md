---
source: "R08 G2"
status: "checkpoint local; E2E pendente"
generated_at: "2026-09-12T10:58:00-03:00"
---

# R08 G2 — Acessos e Pessoas

## P51=B — link seguro para definição de senha

`internal-user-create` agora gera um link de recuperação pelo Auth Admin após
autorizar o operador e criar a conta. A geração recebe o `redirectTo` canônico
HTTPS `https://superadmin.coelo.me/reset-password`, rota que o Superadmin usa
para trocar a senha; ele não é derivado da origem CORS do operador. O link só é aceito se HTTPS, sem
credenciais na URL e com origem/path do projeto Supabase; é devolvido apenas na
resposta `no-store` ao operador autorizado. A UI mostra o diálogo de cópia para
entrega por canal seguro; não há SMTP, senha, token ou URL registrada neste
arquivo, no JSON de comunicação ou em logs.

Teste local: `deno test --config packages/coelo_database/supabase/functions/internal-user-create/deno.json --allow-env packages/coelo_database/supabase/functions/internal-user-create/cors_test.ts` — 8 passed, 0 failed. Além de CORS/URL, a suíte simula autorização, Auth Admin e RPC: confirma que a origem runtime HTTP autorizada recebe o destino HTTPS canônico e sucesso somente após a persistência; em retorno de erro ou exceção de `generateLink`, responde 409 e tenta apagar o usuário Auth.

Se a exclusão compensatória falhar, a função não retorna sucesso nem expõe o
link; pode restar uma conta Auth sem identidade interna. A reconciliação/auditoria
desse caso pertence à revisão de segurança e não é alegada como resolvida aqui.

## Gates abertos

- `internal-users.create`: rota normal, criação, reload e negativa aguardam
  runtime/Chrome de G0; deploy é de C0.
- `people.create`/`people.edit`: rota normal, @, disponibilidade/cooldown e
  reload aguardam Chrome.
- `invites.resend`: fixture expirada segura solicitada à G5.
- P15: `person_form_page_test.dart` agora espera 40 (em vez de 24), valor já
  produzido pelo `SuperadminFormFrame`; `flutter test --concurrency=1
  test/features/people/presentation/person_form_page_test.dart` terminou com
  23 passed, 0 failed.
- Foco de usuários internos: `flutter test --concurrency=1
  test/features/platform_users/data/supabase_platform_user_repository_test.dart
  test/features/platform_users/presentation/platform_user_pages_test.dart`
  terminou com 39 passed, 0 failed.
- Os 15 goldens A ainda exigem comparação visual antes de regravação.
