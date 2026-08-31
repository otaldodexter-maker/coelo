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

O cabeçalho Principal usa marca Coelo com chevron de menu e avatar. Mensagens
permanece como ação flutuante e Perfil permanece no cabeçalho. O shell, o
contêiner direito, os insets, raios e gaps seguem a geometria canônica aprovada;
no tema claro, a base é `surface`, sem cinza estrutural.

O menu inferior existe em mobile, tablet e web com Home, Para você, ação
central `+` para publicar no Agora, Momentos e Pesquisar. A ação central
atravessa o limite superior da barra, aproximadamente metade dentro e metade
fora. Tablet respeita safe areas e largura útil; no web, o menu é um dock
compacto e contido, sem ocupar toda a tela.

Este contrato está aprovado visualmente, mas ainda depende de implementação,
testes, goldens responsivos e validação real antes de qualquer conclusão.
