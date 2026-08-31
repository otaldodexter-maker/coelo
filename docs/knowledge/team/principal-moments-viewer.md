---
title: "Visualizador de Momentos do Principal"
knowledge_id: "principal-moments-viewer"
source: "docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md"
status: "validated"
generated_at: "2026-08-31"
audience: "team"
surfaces: [principal, momentos, media, navigation]
visibility: "internal"
review_owner: "Coelo Product e Design"
---

# Visualizador de Momentos do Principal

O Visualizador de Momentos usa mídia dominante, autoria, contexto, legenda,
prova social e ações de curtir, comentar, compartilhar e salvar. Mobile e tablet
priorizam a mídia vertical sem distorção; o desktop pode manter contexto auxiliar
compacto, sem competir com a mídia.

Ao abrir, o viewer ocupa a tela toda e suspende cabeçalho, shell e dock em
mobile, tablet e web. O retorno contextual `‹ Momentos` devolve foco e posição à
origem. Os controles laterais usam uma única família e peso óptico, glyphs
proporcionais, alvos mínimos de toque e estado ativo laranja; caracteres
textuais ou emojis não substituem ícones vetoriais.

A implementação Flutter visual local, os testes e os goldens responsivos estão
registrados no rastreador. Imagem e vídeo são distinguidos; quando o preview não
possui player autorizado, a indisponibilidade é explícita. Mídia remota,
autorização, app executável e E2E permanecem pendentes.
