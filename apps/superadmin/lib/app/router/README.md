---
source: "apps/superadmin/README.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Router

Rotas internas do Superadmin. Usa `go_router` e `MaterialApp.router` para
URLs/deep links previsiveis em Flutter Web e futuras superficies mobile.

Este diretorio deve conectar URLs/telas a features sem concentrar regra de
negocio.

Rotas sensiveis devem ser protegidas por guards e por autorizacao real no
backend ou banco quando houver dados reais.

Regras:

- Declare paths e names em `superadmin_routes.dart`.
- Configure a arvore em `superadmin_router.dart`.
- Use `redirect`/guards apenas para sessao, contexto ativo e disponibilidade
  local; permissao final continua server-side/RLS.
- Quando houver navegacao persistente por modulos, preferir
  `StatefulShellRoute` para preservar estado por branch.
