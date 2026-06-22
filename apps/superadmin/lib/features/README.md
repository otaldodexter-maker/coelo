---
source: "apps/superadmin/README.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Features

Modulos de produto do Superadmin. Cada feature deve ser pequena, testavel e
com fronteira clara.

Padrao interno quando houver codigo:

- `presentation/screens`: telas completas.
- `presentation/widgets`: widgets locais da feature.
- `presentation/view_models`: estado e acoes da tela.
- `domain`: entidades e regras especificas.
- `data`: repositories, mocks, DTOs e adapters.

Componentes realmente compartilhados devem ir para `packages/coelo_ui_core`
ou `packages/coelo_ui_admin`.
