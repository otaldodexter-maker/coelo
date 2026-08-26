---
source: "specs/013-ui-packages-componentization.md"
status: "reserved-package"
generated_at: "2026-07-22"
---

# coelo_ui_principal

Componentes Flutter especificos do app principal: Acontece, Agora, Momentos, rotina,
agenda, chat e troca explicita de experiencias contextuais. A pessoa global
pode combinar papeis familiares, profissionais e internos autorizados conforme
o ADR 0012; o pacote nao presume uma experiencia somente de responsaveis.

## Regra

Este pacote nao importa componentes administrativos. Quando algo for realmente
compartilhado com Admin ou Superadmin, ele deve subir para `coelo_ui_core`.

## Status

Pacote reservado. Implementar apenas a partir de specs do app principal.
