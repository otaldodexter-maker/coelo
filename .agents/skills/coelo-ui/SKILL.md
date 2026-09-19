---
name: coelo-ui
description: Use when creating, changing, or reviewing Coelo UI in Flutter or future Astro surfaces, including screens, widgets, components, tokens, themes, states, responsiveness, accessibility, catalog examples, and visual regressions.
metadata:
  source: "specs/013-ui-packages-componentization.md; docs/design/design-system.md; specs/050-principal-ui-ux-closure.md; docs/archive/superpowers/specs/2026-07-28-superadmin-error-pages-design.md; .agents/skills/coelo-ui/references/approved-superadmin-visual-baselines.md; .agents/skills/coelo-ui/references/interactive-state-evidence-matrix.md; .agents/skills/coelo-ui/references/rejected-visual-patterns-inbox.md; .agents/skills/coelo-ui/references/admin-directory-flyout-contracts.md; .agents/skills/coelo-ui/references/weekly-superadmin-ui-review.md"
  status: "active"
  generated_at: "2026-07-29"
  updated_at: "2026-09-17"
---

# Coelo UI

Capturas, goldens, patches e logs são evidência somente quando o recorte pedir;
não os trate como contexto atual. Limpeza segue
`docs/agent/artifact-cleanup-backlog-20260914.md`.

Aplicar o Design System oficial sem transformar propostas em padrões
silenciosamente.

Estado (17/09/2026): a execução FE/BE/E2E do MVP terminou (FE 199/199, BE 186/186,
E2E 186/186; `docs/reviews/etapa-2-operacao/next-round/R16-checkpoint-20260917.md`).
Os ajustes de UI/UX remanescentes da R16 (14 Owner items, resíduos H — ver
`R16-pendencias.md`) ficam em reserva para a **revisão de telas antes da Etapa 3**:
a coordenação apresenta todas as telas ao Owner, que aprova ou manda a correção para a
Etapa 3. Esta skill é a referência dessa revisão (famílias, baselines, contratos).

## Fechamento proporcional

Use o [delivery gate](../coelo-flutter-supabase-review/references/delivery-gate.md)
(ADR 0036) somente quando o escopo incluir integração, publicação ou entrega
formal. Uma tarefa de UI somente leitura, explicação ou manutenção documental
não exige reconciliar worktrees, Git e entrega. Quando aplicável, o relatório
deve ser executado com `docs/reviews/entrega-atual.json`; não declarar aceite
por golden, mock, rota aberta ou referência visual preservada.

## Escolher a família visual antes do componente

Registrar separadamente o **app que hospeda a rota** e a **família visual**.
O nome da pasta ou o menu do Superadmin não determina a identidade da tela.

- **Administrativa:** Superadmin é a referência a ser replicada no Admin.
  Aplicar o fluxo administrativo abaixo, preservando as baselines aprovadas.
  Isso não autoriza implementar `apps/admin` fora do recorte.
- **Principal:** Acontece, Agora, Momentos, Para Você, Perfil e Publicar em
  `Coelo (Principal)` já têm composição própria dentro de `apps/superadmin`.
  Ler [superfícies do Principal](references/principal-visual-surfaces.md), a
  spec 050 e a spec da ação. Preservar feed, compositores, navegação e viewers
  aprovados. Não impor a página administrativa a esses cards ou formulários; preservar
  referências parciais que a spec da ação já aprovou. Não
  importar `coelo_ui_admin` em `coelo_ui_principal` nem criar `apps/principal`
  apenas para reproduzir essas telas.
- **Site:** `apps/site` usa Astro e terá composição própria. Conferir o status
  da spec do Site e o recorte autorizado; compartilhar marca e tokens não
  aprova uma identidade administrativa ou do Principal para ele. Preparar uma
  proposta quando a identidade pedida ainda não estiver aprovada.

Em tela mista, identificar a família de cada região: menu administrativo de
descoberta não transforma conteúdo Principal em diretório administrativo.
Compartilhar controles neutros somente se o contrato atender a superfície.
Se a rota for ambígua, localizar sua implementação e spec antes de decidir.

Para qualquer família: consultar o índice com `scripts/query-index.ps1`, abrir
fontes, componentes e evidências relevantes, respeitar as
[fronteiras de pacote](references/package-boundaries.md) e executar a
[verificação proporcional](references/verification.md). Falta de resultado no
índice não significa ausência de implementação: buscar a rota/spec no repo.
Mídia segue a finalidade e os limites de origem/master da ADR 0032, distintos
da apresentação visual. Uma tarefa documental não exige executar toda a UI.

## Família administrativa

Ler obrigatoriamente o [fluxo administrativo](references/administrative-ui-workflow.md)
para criar ou alterar essa família. Ele preserva os contratos de cards, tabela
(table), formulários, popup, filtro, hover, dismiss, menu, estados e baselines.
Consultar os [contratos de interação](references/surface-interaction-contracts.md)
quando o controle administrativo for afetado.

Conceito de família (cabeçalho, menu, chat, toolbar, abas, cards, tabela,
paginação, rodapé, larguras) é implementado uma única vez no componente
compartilhado e consumido pelas telas; feature não reimplementa Table,
Toolbar, Pagination, Header ou Directory. Correção repetida em várias telas
pertence ao componente (decisão do Owner de 10/09/2026, detalhada no fluxo
administrativo).

Aprovação já concedida continua válida. Ausência de teste exige verificação;
ausência de definição visual exige proposta antes de oficializar padrão novo.

## ⋯ de entidade (cards e linhas)

Um só padrão em todas as telas: `CoeloAdminEntityActionsTrigger` (botão ⋯,
`more_horiz`, alvo de 48 px, spinner quando ocupado) abrindo `CoeloAdminFlyout`
com itens de `CoeloAdminEntityActions` (`view`, `edit`, `duplicate`, `publish`,
`activate`, `inactivate`, `restore`, `archive`, `cancel`, `delete`), ícones em
`CoeloAdminActionIcons`. Ordem: ver → editar → duplicar → transições → grupo
negativo (arquivar, cancelar/revogar, excluir) em tom `negative` com separador
no primeiro. Rótulo pode variar (`label:`), ícone e tom não. Item que não é
ciclo de vida (ex.: "Ver respostas", "Agendamentos") continua
`CoeloAdminFlyoutItem` cru.

