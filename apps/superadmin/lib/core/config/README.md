---
source: "apps/superadmin/README.md; docs/security/environment-and-secrets.md"
status: "implemented"
generated_at: "2026-07-16"
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

## Supabase Auth do Superadmin

O bootstrap de autenticacao usa somente:

- `COELO_SUPABASE_URL`;
- `COELO_SUPABASE_PUBLISHABLE_KEY`.

Exemplo local:

```powershell
flutter run -d web-server `
  --web-hostname 127.0.0.1 `
  --web-port 8765 `
  --dart-define=COELO_SUPABASE_URL=https://project.supabase.co `
  --dart-define=COELO_SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

Sem os dois defines, o app inicia normalmente com um gateway indisponivel e
mantem a pessoa na tela de login. A URL e a publishable key sao configuracoes
publicas do cliente; elas nao substituem RLS, memberships ou autorizacao
server-side.

O `.gitignore` da raiz ja ignora `.env` e `.env.*`. Valores locais podem ficar
nesses arquivos para uso por scripts do desenvolvedor, mas o Flutter nao os
carrega automaticamente: os dois valores precisam chegar ao build pelos
argumentos `--dart-define` mostrados acima.

Nunca use `SUPABASE_SECRET_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `service_role` ou
qualquer segredo de servidor no comando, no app ou em arquivos versionados.
