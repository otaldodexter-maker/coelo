---
title: "Navegação global responsiva do Principal"
knowledge_id: "principal-global-navigation"
source: "specs/050-principal-ui-ux-closure.md"
status: "validated"
generated_at: "2026-08-31"
updated_at: "2026-09-01"
audience: "team"
surfaces: [principal, navigation, mobile, tablet, web]
visibility: "internal"
review_owner: "Coelo Product e Design"
---

# Navegação global responsiva do Principal

Mobile, tablet e web usam o mesmo dock flutuante do Principal, adaptado às
constraints de cada largura. Ele contém Home, Para você, a ação central de
publicar no Agora, Momentos e Pesquisar. Mensagens permanece como launcher
contextual separado e Perfil permanece no cabeçalho.

Cada destino exibe rótulo e glyph proporcional. Ícone e texto ativos usam o
laranja de marca; a sombra do dock é curta e sutil. O cabeçalho usa uma
superfície própria em light/dark, preserva a ação de reportar problema e mantém
todos os ícones no mesmo peso óptico. Nunito Sans deve ser carregada de verdade,
sem fallback visual ou falso negrito.

A ação laranja central deve ficar entre 10% e 25% maior que a proposta visual
aprovada e cruzar exatamente em 50/50 o limite superior do dock. O dock é
flutuante em todas as larguras e preserva respiro tokenizado da borda inferior;
nunca fica colado à viewport. Mobile e tablet respeitam safe areas e largura
útil; no web, o dock é compacto e centralizado, sem ocupar toda a tela.

Viewers imersivos suspendem temporariamente cabeçalho e dock. Agora e Momentos
usam retorno contextual visível e devolvem foco e posição ao ponto de origem.

Cada rota exibe um único shell do Principal. No host `/dev`, a navegação lateral
administrativa pode permanecer para descoberta, mas o cabeçalho de página e o
launcher de mensagens do Superadmin são suprimidos nas superfícies Principal.
O runtime do Principal nunca exibe chrome administrativo nem dois launchers de
mensagens concorrentes.

A implementação Flutter visual local e seus goldens responsivos estão
registrados no rastreador. Em texto a 200%, os rótulos refluem sem clamp e sem
colisão; isso não promove o dock a integração produtiva nem conclui o app
executável em `apps/principal`.
