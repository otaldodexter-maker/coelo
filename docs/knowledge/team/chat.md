---
title: Padrão institucional de chat administrativo
knowledge_id: institutional-admin-chat
source: docs/superpowers/specs/2026-07-27-superadmin-chat-adjustments-design.md
status: validated
generated_at: 2026-07-28
audience: team
surfaces: [admin, superadmin, chat]
visibility: internal
review_owner: Coelo Product e Design System
---

# Padrão institucional de chat administrativo

`pattern.chat-admin` é o padrão-base de chat institucional para Admin e
Superadmin. Ele combina launcher global, toolbar e filtros, inbox ou rail, fio,
resumo contextual e compositor. O catálogo é a referência executável; apps
consumidores não importam o catálogo.

A composição responde às constraints disponíveis:

- compact: navegação empilhada entre inbox, fio e contexto;
- medium: rail e fio, com contexto sob demanda;
- expanded: laterais recolhíveis;
- large: inbox, fio e resumo contextual simultâneos quando houver espaço.

As larguras de referência são 336 px para inbox, 80 px para rail, 288 px para
resumo expandido e 64 px para resumo recolhido. O launcher mede no máximo
460 × 600 px. Avatares de inbox e cabeçalho usam até 48 px; fotos contextuais
usam proporção 1:1 e até 64 × 64 px.

Abaixo de `large`, o launcher abre como modal com barreira e margem mínima de
16 px. Em `large`, ocupa uma faixa irmã reservada de 460 px sem sobrepor o fio;
enquanto aberto, inbox e resumo usam respectivamente o rail de 80 px e a
variante recolhida de 64 px. Em repouso, o launcher é neutro; hover e foco usam
`primary` com `onPrimary`.

`CoeloAdminChatContextSummary` recebe identidade e de duas a seis métricas
textuais. O componente não decide valores, destinatários, vínculos, permissões
ou capacidade de envio. Esses dados e regras pertencem à feature e ao caminho
server-side autorizado quando houver implementação real.

Quando uma foto contextual é fornecida, ela é anunciada como
`Imagem de contexto de {título}` e permanece limitada a 64 × 64 px. Filtros
usam `primaryContainer` com conteúdo e contorno `primary` em seleção, hover e
foco; a ação de fechar usa `error` e `errorContainer`, sempre com alvo mínimo
de 48 px.

Filtros, recipient picker, fixtures e envio em massa não fazem parte da API
pública do Design System. Simulações devem declarar que são locais e não podem
sugerir persistência, entrega, auditoria ou autorização real.
