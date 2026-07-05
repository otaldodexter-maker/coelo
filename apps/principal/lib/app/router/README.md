---
source: "apps/principal/README.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Router

Rotas internas do Principal. Quando houver codigo executavel, deve usar
`go_router` com `MaterialApp.router`, conectar telas a features e trocar
navegacao conforme contexto ativo, papel e permissoes.

Rotas nao substituem autorizacao server-side.

Deep links devem recalcular sessao, contexto ativo e permissao no servidor ou
banco antes de exibir dados privados.
