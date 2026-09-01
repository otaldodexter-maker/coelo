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

## Pre-visualizacao local

Quando `COELO_APP_ENV=local` e informado explicitamente, as rotas `/dev/...` ficam
disponiveis para navegar pelas telas fake de UI/UX sem autenticar no Supabase.
Em qualquer outro ambiente, essas rotas permanecem protegidas e redirecionam
para o login.

## Supabase Auth do Superadmin

O bootstrap de autenticacao usa somente:

- `COELO_SUPABASE_URL`;
- `COELO_SUPABASE_PUBLISHABLE_KEY`.

O valor padrao de `COELO_APP_ENV` e `staging`, portanto `/dev/...` permanece
desabilitado mesmo em debug. Exemplo para executar o app local contra o
Supabase hospedado sem imprimir a chave publica:

```powershell
flutter run -d web-server `
  --web-hostname 127.0.0.1 `
  --web-port 8765 `
  --dart-define=COELO_APP_ENV=staging `
  "--dart-define=COELO_SUPABASE_URL=$env:COELO_SUPABASE_URL" `
  "--dart-define=COELO_SUPABASE_PUBLISHABLE_KEY=$env:COELO_SUPABASE_PUBLISHABLE_KEY"
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
