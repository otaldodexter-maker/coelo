---
source: "apps/principal/README.md; docs/security/environment-and-secrets.md"
status: "planning-context"
generated_at: "2026-07-02"
---

# Config

Configuracoes locais do Principal, como ambiente, flags nao sensiveis e
parametros de inicializacao.

Segredos e chaves privadas nunca devem entrar no cliente.

Em Flutter, configuracoes publicas entram por `--dart-define` e sao lidas com
`String.fromEnvironment` ou `bool.fromEnvironment`. Isso nao protege segredo:
qualquer valor embutido no app deve ser considerado publico.
