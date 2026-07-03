---
source: "AGENTS.md; docs/architecture/macro-architecture.md; docs/security/lgpd-security-media.md; Supabase API Keys; Dart String.fromEnvironment"
status: "planning-context"
generated_at: "2026-07-02"
---

# Environment And Secrets

Este documento define como o Coelo deve usar arquivos `.env`, variaveis de
ambiente e configuracao de build em Flutter/Dart.

## Regra principal

`.env` e um arquivo local de pares `CHAVE=VALOR`. Ele serve para guardar valores
que variam por ambiente sem colocar esses valores no Git.

No Coelo, `.env` pode existir localmente, mas nunca deve ser commitado. O
repositorio versiona apenas `.env.example`, que e um template sem valores reais.

Em Flutter, valores passados por build, asset, Dart define ou arquivo embutido
devem ser tratados como publicos. Isso vale para Flutter Web, Android, iOS,
desktop e builds de debug. Ofuscacao ou compilacao nao transformam segredo em
segredo.

## Classificacao

| Classe | Pode ir para Flutter? | Exemplos | Regra |
| --- | --- | --- | --- |
| Configuracao publica do cliente | Sim | `COELO_APP_ENV`, URL publica da API, Supabase publishable key, feature flags nao sensiveis | Pode entrar via `--dart-define` e `String.fromEnvironment`. |
| Identidade do usuario | Sim, com cuidado | JWT/session do usuario autenticado | Guardar conforme estrategia de auth/secure storage e limpar no logout. |
| Segredo de servidor | Nao | `SUPABASE_SECRET_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, R2 secret, tokens de pagamento, e-mail, IA, webhook ou admin | Fica em Edge Functions, servidor, CI/CD secrets ou secret manager. |
| Dados pessoais/sensiveis | Nao como config | CPF, dados infantis, mensagens, midia, logs sensiveis | Vem de APIs autorizadas, com RLS/permissao/auditoria. |

## Flutter/Dart

Flutter nao carrega `.env` automaticamente como frameworks web com Node/Nuxt.
Para valores publicos de cliente, o padrao do Coelo e passar definicoes em tempo
de build:

```powershell
flutter run `
  --dart-define=COELO_APP_ENV=local `
  --dart-define=COELO_SUPABASE_URL=http://127.0.0.1:54321 `
  --dart-define=COELO_SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

No Dart, a leitura deve ficar em `lib/core/config` do app:

```dart
abstract final class AppConfig {
  static const environment = String.fromEnvironment(
    'COELO_APP_ENV',
    defaultValue: 'local',
  );

  static const supabaseUrl = String.fromEnvironment('COELO_SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'COELO_SUPABASE_PUBLISHABLE_KEY',
  );
}
```

`String.fromEnvironment`, `bool.fromEnvironment` e `int.fromEnvironment` leem o
ambiente de compilacao do Dart. Eles nao leem automaticamente variaveis do
sistema operacional nem um arquivo `.env`.

## Supabase

Para clientes Flutter, usar apenas chave publishable (`sb_publishable_...`) ou
legado `anon` quando uma spec aprovada exigir compatibilidade temporaria. Essas
chaves identificam o cliente, mas nao autorizam dados por si so. A seguranca
depende de Auth, grants, RLS, policies e testes cross-tenant.

Chaves secretas (`sb_secret_...`) e legado `service_role` pertencem somente a
componentes server-side. Elas podem bypassar RLS e nunca devem ir para Flutter,
site publico, bundle web, app mobile, logs, query params ou documentos publicos.

## Cloudflare R2 e midia

Credenciais R2 ficam fora dos apps. O cliente deve pedir autorizacao ao caminho
server-side aprovado, receber URL temporaria quando permitido e nunca conhecer
`R2_SECRET_ACCESS_KEY`.

O spike atual de R2 possui seu proprio template em
`spikes/media-r2/.env.example`. Esse template e descartavel e nao cria regra de
produto para colocar secrets em apps Flutter.

## Convencao do repositorio

- `.env` e `.env.*` sao ignorados pelo Git.
- `.env.example` pode ser commitado quando nao tiver valores reais.
- Cada nova variavel deve ser classificada como `public_client` ou
  `server_secret` antes de ser usada.
- Apps Flutter leem apenas `public_client` em `lib/core/config`.
- Segredos de servidor entram por Edge Functions, CI/CD secrets, dashboard do
  provedor ou secret manager.
- Se uma variavel de ambiente for necessaria para produto, a spec tecnica deve
  registrar nome, classe, ambiente, dono e forma de rotacao.

## Checklist antes de adicionar variavel

1. O valor pode aparecer no bundle Flutter sem causar dano?
2. A variavel e configuracao, nao dado pessoal?
3. Existe RLS/permissao server-side protegendo os dados acessados?
4. `.env.example` foi atualizado sem valor real?
5. A doc ou spec da feature registrou quem fornece e quem rotaciona o valor?
6. Logs e mensagens de erro evitam imprimir o valor completo?

## Fontes oficiais

- Dart `String.fromEnvironment`: https://api.dart.dev/dart-core/String/String.fromEnvironment.html
- Flutter flavors e configuracoes por ambiente: https://docs.flutter.dev/deployment/flavors
- Flutter CLI: https://docs.flutter.dev/reference/flutter-cli
- Supabase API Keys: https://supabase.com/docs/guides/getting-started/api-keys
- Supabase Edge Functions environment variables: https://supabase.com/docs/guides/functions/secrets
