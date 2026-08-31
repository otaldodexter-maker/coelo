---
title: "Visualizador do Agora no Principal"
knowledge_id: principal-now-viewer
source: docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md
status: validated
generated_at: 2026-08-31
updated_at: 2026-08-31
audience: team
surfaces: [principal, agora, media-viewer]
visibility: internal
review_owner: Coelo Product
---

# Visualizador do Agora no Principal

O Agora abre em viewer imersivo fullscreen e suspende temporariamente o shell,
o rail e o dock global. Fechar devolve o usuário ao ponto de origem no
Acontece.

Mobile usa mídia vertical de ponta a ponta. Tablet mantém um quadro vertical
seguro e centralizado. No web, o story permanece central e recebe prévias
laterais discretas com navegação por setas; o restante do viewport usa fundo
escuro com transparência leve, sem virar dashboard.

Barras de progresso, marca Coelo branca, autoria, tempo e contexto, controle de
som, mais opções, fechamento, audiência, resposta, curtir e compartilhar ficam
acessíveis, mas subordinados à mídia. Alvos de toque, safe areas, teclado,
semântica, contraste e retorno de foco integram o contrato de implementação.

O contrato está aprovado visualmente, mas ainda depende de implementação,
testes e goldens responsivos antes de qualquer conclusão.
