---
title: UI de Conversas do Superadmin
knowledge_id: superadmin-chat-ui
source: docs/superpowers/specs/2026-07-28-superadmin-chat-local-redesign-design.md
status: validated
generated_at: 2026-08-06
audience: team
surfaces: [superadmin, conversations]
visibility: internal
review_owner: Coelo Product
---

# UI de Conversas do Superadmin

Conversas usa uma única instância do launcher no shell autenticado. A cápsula laranja não muda de geometria em repouso, hover, foco ou arraste; não aparece na rota Conversas nem enquanto o drawer mobile estiver aberto. Sua posição é normalizada no armazenamento local durante a sessão autenticada, respeita safe area e reservas inferiores e é removida no logout.

A composição responde às constraints: três painéis no amplo, thread prioritária com contexto sobreposto no intermediário e inbox, thread e contexto separados no compacto. Em mobile e tablet claros, workspace, inbox e thread usam `colorScheme.surface` como base; `surfaceContainer*` fica restrito a campos, bolhas, cards, estados e separações locais com função explícita.

As facetas `Todos`, `Institucional` e `Pessoas` usam tabs lineares. Fixadas, Não lidas e Bandeiras são filtros rápidos combináveis que quebram em linhas por constraints, sem rolagem horizontal espremida. Seleção e hover usam a família primária Coelo, nunca cinza Material.

Bandeiras pessoais mostram o ícone na cor real e um rótulo funcional visível: Urgente, Acompanhar, Resolvido, Aguardando retorno, Sensível e Restrito. O rótulo acessível anuncia também a cor; o nome textual da cor não substitui a representação visual. Mouse, foco, toque e teclado oferecem operação equivalente e a seleção atualiza imediatamente o estado local do controller.

Menus e ações do Chat reutilizam `CoeloAdminFlyout`; dialogs reutilizam `CoeloAdminDialogShell`. Bandeiras permanecem somente no estado em memória do protótipo: não existe repositório ou backend canônico, e esta decisão não autoriza Supabase, persistência produtiva de mensagens ou mudança de regra de negócio.