---
title: Central de ajuda do Superadmin
knowledge_id: superadmin-help-center
source: docs/superpowers/specs/2026-07-27-superadmin-help-center-home-design.md
status: validated
generated_at: 2026-07-27
audience: team
surfaces: [superadmin, home]
visibility: internal
review_owner: Coelo Product
---

# Central de ajuda do Superadmin

A rota autenticada `/` é a Home do Superadmin e apresenta uma Central de ajuda
conversacional. “Home” aparece no topo do menu, e a marca formada pela logo e
pelo texto “Superadmin” também abre essa rota. No drawer mobile, a mesma ação
fecha o drawer antes da navegação.

Nesta fase, conversas e mensagens existem somente durante a sessão. A primeira
pergunta define o título da conversa e recebe uma resposta que identifica a
experiência como demonstração. Não há IA real, API, Supabase ou persistência.

No desktop, o histórico pode ser recolhido para um rail compacto de 88 px e
expandido novamente. O envio fica fora do campo de escrita e segue o padrão
visual de Conversas: estado neutro quando desabilitado e fundo primário Coelo
quando há conteúdo válido.

`Comunicação > Conversas` continua sendo a superfície separada para comunicação
humana.
