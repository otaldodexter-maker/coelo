---
title: "Perfil completo do Principal"
knowledge_id: "principal-profile"
source: "docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md"
status: "validated"
generated_at: "2026-08-31"
updated_at: "2026-09-03"
audience: "team"
surfaces: [principal, profile, acontece, momentos, circulares]
visibility: "internal"
review_owner: "Coelo Product e Design"
---

# Perfil completo do Principal

O Perfil do Principal usa capa panorâmica de largura integral, avatar grande e
totalmente visível, identidade, contexto e estatísticas. As áreas Acontece,
Momentos, Circulares e Sobre usam tabs lineares, com label e underline laranja
na seleção.

A capa segue proporção 3:1 e pertence ao contexto de perfil autorizado; o
avatar pode ser global da pessoa ou contextual quando o produto o permitir.
Ambos ficam em `coelo-media-prod` sob finalidades `cover` e `avatar`, ligados
pelo catálogo Postgres e acessados via Media Gateway. A conta do usuário
Superadmin possui avatar, mas não possui capa própria aprovada.

O conteúdo ativo preserva densidade editorial de perfil social sem virar
dashboard. No desktop, shell, contêiner direito, largura útil, insets, raios e
gaps seguem literalmente a geometria canônica, com contexto auxiliar compacto.

A implementação Flutter visual local, os testes e os goldens responsivos estão
registrados no rastreador. A 200%, as métricas refluem sem ellipsis. Dados
produtivos, autorização, app executável e E2E continuam fora dessa evidência.
