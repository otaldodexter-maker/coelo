---
title: Diretório de atividades do Superadmin
knowledge_id: superadmin-activity-directory
source: docs/superpowers/specs/2026-07-29-superadmin-activity-inspection-design.md
status: validated
generated_at: 2026-07-29
audience: team
surfaces: [superadmin, activities]
visibility: internal
review_owner: Coelo Product
---

# Diretório de atividades do Superadmin

O Superadmin consulta atividades em `/activities` e seus detalhes em
`/activities/:activityId`. Essa superfície é somente leitura: criação e edição
continuam pertencendo ao Admin, porque `platform.read` permite inspeção, mas
não substitui as capacidades institucionais `activities.create` e
`activities.manage`.

A entidade canônica é `activity_definitions`, vinculada obrigatoriamente a uma
instituição e, quando a origem é `unit`, a uma unidade de origem. O diretório
oferece cards e tabela, busca por nome ou descrição e filtros multi-select de
instituição, status e origem. Cards iniciam com 11 itens e tabela com 8; ambos
oferecem também 20, 50 e 100 itens por página.

Os status confirmados são `draft`, `active`, `inactive`, `suspended` e
`archived`. A origem é `institution` ou `unit`; a distribuição é
`institution_standard` ou `unit_local`; a governança é `optional`,
`mandatory` ou `fixed`. Não há contrato para tipo, agenda, recorrência,
duração, anexos, publicação, cancelamento ou conclusão nessa superfície.

O detalhe mostra identidade, governança, unidades e grupos vinculados. Para
minimização de dados, profissionais atribuídos e participantes aparecem
somente como contagens; nomes de profissionais e crianças não são exibidos.
Consultas usam a sessão autenticada e as policies RLS existentes, sem segredo
privilegiado no cliente e sem autorização inferida de metadata.
