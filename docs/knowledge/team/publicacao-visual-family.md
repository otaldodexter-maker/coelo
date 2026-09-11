---
title: Família visual Publicação (Coelo Principal)
knowledge_id: publicacao-visual-family
source: .agents/skills/coelo-ui/references/principal-visual-surfaces.md
status: validated
generated_at: 2026-09-11
audience: team
surfaces:
  - superadmin
  - principal
visibility: internal
review_owner: Coelo Owner
---

# Família visual Publicação

Decisão do Owner em 11/09/2026 (aprovação das telas às 17:19): publicar no
Coelo é uma família visual própria do Coelo (Principal), distinta do diretório
administrativo e do wizard de formulários. Ela vale para Agora, Acontece,
Momentos, Circulares, Eventos da Agenda e Lançar faltas (lançar chamada também
é uma publicação). Os publicadores renderizados com o wizard administrativo
foram reprovados.

## Onde vive

- Descrição canônica: skill `coelo-ui`,
  `references/principal-visual-surfaces.md`, seção "Família Publicação".
- Referência vigente (12 telas aprovadas):
  `docs/reviews/evidence/etapa-2/referencias/publicacao/aprovadas-20260911/`
  (`agora`, `acontece`, `momentos`, `circular`, `evento`, `lancar-chamada`,
  em `-mobile-375.png` e `-web-1440.png`); fonte regenerável em
  `../canvas-fonte/`.

## O que a tela entrega

- No Superadmin web, a publicação vive dentro do contêiner principal, com o
  shell real (menu com "Coelo (Principal)" ativo, barra "Vendo como"), título
  "Sua publicação / Publicar no …" e rodapé em card com Cancelar, Salvar
  rascunho e a ação primária laranja. No mobile, cabeçalho do Principal,
  uma coluna e rodapé em card com a primária cheia.
- Mídia primeiro (vídeo 9:16 ou carrossel), sempre com recorte `cover`;
  trilho Texto · Música · Cortar · Capa nos vídeos.
- Blocos em cards contornados na ordem Legenda → Público e contexto (com
  chips de audiência) → Agendamento → Opções → nota em laranja claro; prévia
  à direita só no web.
- Sem fundo cinza, sem etapas de wizard e sem balão de chat.
- Aprovar a proposta não muda o estado de nenhuma ação: cada tela só avança
  quando for reconstruída sobre a família e provada na rota real.
