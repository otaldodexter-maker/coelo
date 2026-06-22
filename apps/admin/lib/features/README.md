---
source: "apps/admin/README.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Features

Modulos de produto do Admin. Cada feature deve seguir o padrao quando houver
codigo:

- `presentation/screens`: telas completas.
- `presentation/widgets`: widgets locais.
- `presentation/view_models`: estado e acoes da tela.
- `domain`: regras especificas.
- `data`: repositories, mocks, DTOs e adapters.

Componentes compartilhados entre Admin e Superadmin pertencem a
`packages/coelo_ui_admin`.
