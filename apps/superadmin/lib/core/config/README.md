---
source: "apps/superadmin/README.md; docs/security/environment-and-secrets.md"
status: "planning-context"
generated_at: "2026-07-02"
---

# Config

Configuracoes locais do app, como ambiente, flags nao sensiveis e parametros
de inicializacao.

Segredos, `service_role` e chaves privadas nunca devem ser colocados aqui.

Em Flutter, configuracoes publicas entram por `--dart-define` e sao lidas com
`String.fromEnvironment` ou `bool.fromEnvironment`. Isso nao protege segredo:
qualquer valor embutido no app deve ser considerado publico.

Variaveis client-safe atuais:

- `COELO_APP_ENV`
- `COELO_SUPABASE_URL`
- `COELO_SUPABASE_PUBLISHABLE_KEY`
- `COELO_DEV_MFA`
