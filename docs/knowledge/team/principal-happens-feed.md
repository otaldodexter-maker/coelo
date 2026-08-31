---
title: "Estrutura do Acontece no Principal"
knowledge_id: principal-happens-feed
source: docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md
status: validated
generated_at: 2026-08-31
updated_at: 2026-08-31
audience: team
surfaces: [principal, acontece, agora, navigation]
visibility: internal
review_owner: Coelo Product
---

# Estrutura do Acontece no Principal

O Acontece abre pelo carrossel horizontal Agora, sem `Ver tudo`. O primeiro
card retangular publica no Agora. Depois do carrossel, o título discreto
`Acontece` introduz o feed unificado de publicações Acontece e Circulares.

A publicação preserva a ordem autor, mídia dominante, ações, prova social e
legenda. Não existe texto editorial antes da mídia nem navegação interna
redundante entre Acontece, Para você, Momentos e Perfil.

O cabeçalho Principal usa marca Coelo com chevron de menu, ação de reportar
problema, notificações e avatar sobre superfície própria. Mensagens permanece
como ação flutuante e Perfil permanece no cabeçalho. O shell, o
contêiner direito, os insets, raios e gaps seguem a geometria canônica aprovada;
no tema claro, a base é `surface`, sem cinza estrutural.

O dock flutuante global existe em mobile, tablet e web com Home, Para você,
ação central `+` para publicar no Agora, Momentos e Pesquisar. A ação central é
entre 10% e 25% maior que a proposta visual aprovada e atravessa exatamente em
50/50 o limite superior do dock. Mobile e tablet respeitam safe areas e largura
útil; no web, o dock é compacto e contido, sem ocupar toda a tela.

A mídia do feed abre uma galeria adaptativa: compacto usa viewer fullscreen com
retorno contextual; tablet amplo e desktop usam popup modal com mídia
protagonista, navegação, contagem e ações. Fechar ou usar Escape restaura foco e
posição de origem.

A implementação visual local, seus testes e goldens responsivos estão registrados
no host de preview autorizado. O app Principal executável, dados produtivos,
autorização, mídia remota e E2E ainda dependem de materialização e validação próprias
antes de qualquer conclusão de produto.
