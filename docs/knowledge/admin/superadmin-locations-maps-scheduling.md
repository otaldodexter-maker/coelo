---
title: Gestão de locais, mapas e reservas
knowledge_id: superadmin-locations-maps-scheduling
source: docs/superpowers/specs/2026-09-02-superadmin-locais-mapas-agendamentos-design.md
status: validated
generated_at: 2026-09-02
updated_at: 2026-09-03
audience: admin
surfaces: [superadmin, locations, maps, scheduling]
visibility: internal
review_owner: Coelo Product
---

# Gestão de locais, mapas e reservas

Cada instituição e unidade terá seu próprio catálogo de locais. Um local da
instituição poderá ser copiado para uma unidade, mas a cópia será independente.

No cadastro, escolha se o local é interno ou externo. O endereço é obrigatório
para locais externos. Imagem geral do mapa, marcador e foto do local são
opcionais. Também é possível definir se o local será visível para equipe,
responsáveis, alunos ou todos esses públicos.

As imagens serão privadas e disponibilizadas somente após autorização. Nenhuma
chave de armazenamento ficará no aplicativo.

Turmas, Atividades e Eventos poderão usar um local do catálogo ou um texto
pontual. Quando um local novo for digitado, o sistema perguntará se ele deve ser
adicionado ao catálogo. Apenas locais catalogados terão agenda, mapa e lista de
vínculos.

A gestão escolherá se conflitos de horário bloqueiam a reserva ou apenas geram
um alerta. No modo de alerta, somente uma pessoa autorizada poderá confirmar o
conflito, informando uma justificativa. Turmas e Atividades poderão reservar o
local de forma recorrente quando essa opção for ativada.

Formulários poderão apresentar locais internos como pergunta de escolha única
ou múltipla, respeitando a visibilidade definida. Esta funcionalidade está
aprovada, mas ainda não foi implementada.
