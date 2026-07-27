---
title: Paginação numerada administrativa
knowledge_id: coelo-admin-numbered-pagination
source: docs/superpowers/specs/2026-07-27-coelo-admin-numbered-pagination-design.md
status: validated
generated_at: 2026-07-27
audience: team
surfaces: [admin, superadmin, catalog]
visibility: internal
review_owner: Coelo Product
---

# Paginação numerada administrativa

Listagens administrativas usam a paginação compartilhada `CoeloAdminPagination`
quando a fonte fornece página atual, total de páginas e tamanhos permitidos. A
paginação é numerada, permite seleção direta da página e mostra reticências para
faixas omitidas; os controles anterior e próximo respeitam os limites.

O contrato aprovado de tamanho por página oferece exatamente 10, 50, 100 e 500
itens. A seleção inicial é 10 itens e uma alteração de tamanho sempre retorna à
primeira página antes do novo carregamento. A paginação permanece server-side;
o widget compartilhado não recebe regra de domínio, tenant ou autorização.

Em resultados administrativos não vazios, o rodapé permanece disponível mesmo
quando há uma única página, para manter o seletor de tamanho acessível. Estados
vazio, sem resultado, falha e não autorizado não exibem o rodapé.
