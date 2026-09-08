---
title: "Famílias visuais do Coelo e app hospedeiro"
knowledge_id: "coelo-visual-families"
source: "docs/design/design-system.md"
status: "validated"
generated_at: "2026-09-08"
audience: "team"
surfaces: [superadmin, admin, principal, site, design]
visibility: "internal"
review_owner: "Coelo Owner"
---

# Família visual e app hospedeiro

O Superadmin administrativo é a referência visual para o Admin. As telas do
menu `Coelo (Principal)`, como Acontece, Agora, Momentos e Publicar, preservam
sua composição própria mesmo quando vivem em `apps/superadmin`.

Não aplicar cards de Instituições ao feed por compartilhar app ou menu.
Publicar mantém compositor, preview e etapas próprios, incluindo a geometria
externa, insets e rodapé administrativos que sua spec aprovou em 2026-08-31.
Essa referência parcial não converte o conteúdo em cadastro administrativo.

O Site Astro terá composição própria conforme spec e aprovação. Compartilhar
marca, tokens e controles neutros compatíveis não significa copiar páginas.
Principal não importa `coelo_ui_admin`; apps não importam telas entre si.
Menu, código existente e golden local não comprovam backend conectado.
