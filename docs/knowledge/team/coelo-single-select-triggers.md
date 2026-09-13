---
title: "Gatilhos de seleção única no Superadmin"
knowledge_id: coelo-single-select-triggers
source: .agents/skills/coelo-ui/references/admin-directory-flyout-contracts.md
status: validated
generated_at: 2026-09-13
audience: team
surfaces: [superadmin, catalog]
visibility: internal
review_owner: Coelo Owner
---

Filtros de seleção única em diretórios usam a cápsula compartilhada do
`CoeloAdminSingleSelectField(isFilter: true)`, sem label flutuante ou ícone
de campo. O valor neutro mantém o nome do filtro. Seleção única aplica a
escolha diretamente; seleção múltipla mantém o rascunho até Aplicar.

Na configuração avaliativa, a decisão focal do Owner usa cápsula para
Periodicidade, com label persistente acima, e `CoeloSpacing.space4` entre
Adicionar período e o estado vazio. A fonte desse caso é
[o contrato de formulários](../../../.agents/skills/coelo-ui/references/form-layout-contracts.md).
Isso não converte automaticamente todos os seletores de formulário em filtros.

Estas regras orientam a implementação; não certificam outras telas nem
alteram permissões ou a régua de aceite funcional.
