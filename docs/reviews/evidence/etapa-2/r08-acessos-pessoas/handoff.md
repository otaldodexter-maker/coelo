---
source: "R08 G2"
status: "checkpoint local; E2E pendente"
generated_at: "2026-09-12T10:58:00-03:00"
---

# R08 G2 — Acessos e Pessoas

## P51=B — link seguro para definição de senha

`internal-user-create` agora gera um link de recuperação pelo Auth Admin após
autorizar o operador e criar a conta. O link só é aceito se HTTPS e sem
credenciais na URL, é devolvido apenas na resposta `no-store` ao operador
autorizado e o cliente exige sua presença antes de confirmar o cadastro. A UI
mostra o diálogo de cópia para entrega por canal seguro; não há SMTP, senha,
token ou URL registrada neste arquivo, no JSON de comunicação ou em logs.

Teste local: `deno test --config packages/coelo_database/supabase/functions/internal-user-create/deno.json --allow-env packages/coelo_database/supabase/functions/internal-user-create/cors_test.ts` — 4 passed, 0 failed.

## Gates abertos

- `internal-users.create`: rota normal, criação, reload e negativa aguardam
  runtime/Chrome de G0; deploy é de C0.
- `people.create`/`people.edit`: rota normal, @, disponibilidade/cooldown e
  reload aguardam Chrome.
- `invites.resend`: fixture expirada segura solicitada à G5.
- Os 15 goldens A e a correção P15 ainda exigem comparação visual antes de
  regravação ou alteração de expectativa.
