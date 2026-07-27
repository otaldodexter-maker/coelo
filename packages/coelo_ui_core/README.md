---
source: "specs/013-ui-packages-componentization.md"
status: "implemented-package"
generated_at: "2026-07-22"
---

# coelo_ui_core

Componentes Flutter sem dominio, reutilizaveis por qualquer app Coelo:
botoes, campos, cards, chips, feedback, navegacao base, acessibilidade e
helpers pequenos de layout.

## Regra

Um widget so entra aqui se nao depender de Superadmin, Admin, Principal,
tenant, rota, permissao ou entidade de produto.

## Status

Pacote materializado com os primeiros componentes visuais genericos aprovados
na spec 013. Abstracoes experimentais continuam locais ate reutilizacao real.

## API publica inicial

- `CoeloSearchField`
- `CoeloStatusChip`
- `CoeloStatePanel`
