---
title: Paginação numerada administrativa
knowledge_id: coelo-admin-numbered-pagination
source: docs/design/design-system.md
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

Na ausência de contrato específico da superfície, o padrão genérico oferece
10, 50, 100 e 500 itens e inicia em 10. Uma alteração de tamanho sempre retorna
à primeira página antes do novo carregamento. O consumidor pode fornecer
tamanhos aprovados pela própria superfície: Instituições usa
`11, 20, 50, 100` em cards e `8, 20, 50, 100` em tabela, conforme a decisão
especializada posterior. A paginação permanece server-side; o widget
compartilhado não recebe regra de domínio, tenant ou autorização.

Em resultados administrativos não vazios, o rodapé permanece disponível mesmo
quando há uma única página, para manter o seletor de tamanho acessível. Estados
vazio, sem resultado, falha e não autorizado não exibem o rodapé.
