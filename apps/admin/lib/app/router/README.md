---
source: "apps/admin/README.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Router

Rotas internas do Admin. Quando houver codigo executavel, deve usar
`go_router` com `MaterialApp.router`, apontar para telas de features e aplicar
guards quando houver sessao, contexto ativo ou permissao exigida.

Autorizacao real precisa continuar no backend ou banco.

Quando houver navegacao persistente por modulos, preferir `StatefulShellRoute`
para preservar estado por branch.
