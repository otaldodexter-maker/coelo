---
title: Navegacao persistente das pre-visualizacoes do Superadmin
knowledge_id: superadmin-preview-navigation
source: docs/superpowers/specs/2026-08-04-superadmin-preview-navigation-correction-design.md
status: validated
generated_at: 2026-08-05
audience: team
surfaces: [superadmin, navigation, previews]
visibility: internal
review_owner: Coelo Product
---

# Navegacao persistente das pre-visualizacoes do Superadmin

As rotas de produto `/dev` compartilham uma unica instancia do shell do
Superadmin. O menu lateral, seu estado expandido ou recolhido e a geometria do
shell permanecem montados enquanto somente o conteudo principal e substituido,
sem transicao entre telas. Autenticacao e paginas de erro continuam fora do
shell.

O menu privado de pre-visualizacoes apresenta todas as rotas-mae e exclui
criar, editar, detalhes, chamadas especificas, previews docentes e paginas de
erro. A lista possui altura limitada pela janela e rolagem propria.
