---
title: "R16 — handoff da Sessão TOUR (F8 da Etapa 3: tour do menu no Superadmin, 18/09)"
source: "R16-prompt-tour-20260918.md; tour-menu-rascunho-20260918.md; decisions/0035 (F8); MVP-definicao-etapa3-etapa4-20260918.md; apps/superadmin/lib/app/shell/superadmin_shell.dart; apps/superadmin/lib/app/navigation/superadmin_navigation.dart; .agents/skills/coelo-ui"
status: "active"
lifecycle: "current"
generated_at: "2026-09-18"
updated_at: "2026-09-18"
audience: "team"
---

# R16 — handoff da Sessão TOUR

Sessão Claude `coelo-0c` (Opus 5), worktree `C:\Users\adrie\Documents\Coelo.worktrees\r16-tour`, branch
`r16/tour-menu-20260918` (base `dev` `6ec7bdfe0`). Servidor QA `127.0.0.1:3015`, Chrome CDP `9415`, perfil
`%TEMP%\coelo-r16-tour-chrome`. **Sem espelho de banco e sem SQL**: recorte só Flutter. Sessões pares identificadas
por `ListAgents` antes da worktree: `coelo-85` (coordenadora, `dev`, liberou a worktree), `coelo-2b` (coordenadora
da execução de 17/09, encerrada) e `coelo-8d` (RESERVA; fixture de equipe QA e goldens da Conta — não toca em
tour/menu). Só esta sessão escreve aqui; a coordenadora integra por cherry-pick.

## Recorte (`coelo-frontend`)

- **Objetivo:** F8 da ADR 0035 isolado — "Fazer tour" funcional no Superadmin web, um balão por elemento do menu e
  do cabeçalho, com o texto aprovado do rascunho, editável num único arquivo.
- **Incluído:** mecanismo reutilizável em `coelo_ui_core`; tour do menu (42 passos do rascunho + 6 do feedback = 48); texto em arquivo único;
  persistência local "visto" por usuário; flyout do botão; testes; prova na rota real em 1440 e 600.
- **Fora:** tour por tela; home com IA; SQL/migration/Edge/produção; alterar texto do rascunho; Principal hospedado;
  `apps/admin`/`apps/principal`.
- **Ordem:** brainstorm curto → mecanismo (TDD) → passos → shell/menu → persistência → catálogo → prova → revisão.
- **Parada:** âncora que exigisse refatorar o shell inteiro; persistência no servidor; decisão de texto do Owner.
- **Evidências:** `docs/reviews/evidence/etapa-2/r16-tour/` (capturas do tour a 1440 e 600; logs de teste).
- **Denominador:** nenhum `action_id` muda; `apply-tracker-delta.cjs` não roda.

## Desenho do mecanismo (brainstorm de 18/09, aprovado pelo Owner na sessão)

Alternativas consideradas: pacote de terceiros (`tutorial_coach_mark` — dependência nova, sem tokens/a11y do
Coelo) e mecanismo em `coelo_ui_admin` (o overlay é neutro; pode servir ao Principal). Escolhido: **`coelo_ui_core`**.

1. **`packages/coelo_ui_core/lib/src/tour/coelo_tour.dart`**
   - `CoeloTourStep {anchorId, title, text}`.
   - `CoeloTourAnchorRegistry` + `CoeloTourScope` (herdado) + `CoeloTourAnchor(id, child)`: a âncora registra um
     `GlobalKey` no registro do escopo mais próximo e o remove no `dispose`. Sem escopo acima, é um filho
     transparente. Uma mesma id pode estar registrada mais de uma vez (sidebar e drawer): vale a primeira montada
     com tamanho. **Nenhum refactor do shell**: só se envolvem os alvos.
   - `showCoeloTour(context, steps, registry, onPrepareStep, isStepAvailable)` → `Future<CoeloTourOutcome>`
     (`completed | skipped | unavailable`). Insere um `OverlayEntry` no `Overlay` raiz. Filtra os passos por
     `isStepAvailable` (padrão: âncora montada no início) e, para cada passo, chama `onPrepareStep`, espera o fim
     do frame e mede a âncora; se ela não existe, pula sem aviso (defensivo, além do filtro).
   - `CoeloTourOverlay`: scrim `color.scrim` 55 % com recorte `even-odd` arredondado (`radius.md`) e anel
     `color.primary` ao redor da âncora; balão `Material` (`surface`, `outlineVariant`, `elevation.3`,
     `radius.lg`) com título, texto, contador "n de N", **Pular tour**, **Voltar** (desabilitado no 1.º),
     **Próximo**/**Concluir**. Largura ≥ `breakpoint.expanded` (840): balão de 320 px à direita da âncora, senão à
     esquerda, senão abaixo/acima, sempre dentro da margem. Abaixo de 840: **folha** de largura total, inferior por
     padrão e no topo quando a âncora está na metade de baixo da tela (`radius.xl` no lado livre, `SafeArea`). A
     medição da âncora tenta até 3 frames extras antes de pular o passo. Teclado por `CallbackShortcuts` num `Focus` que recebe foco a cada passo:
     Esc pula, Enter e → avançam, ← volta. Balão é `Semantics(liveRegion)` com "título. n de N".
2. **Preparação do passo (shell):** `CoeloNavigationRevealController.reveal(id)` faz o `CoeloNavigationContent`
   expandir os ancestrais do nó (limpando a busca); depois `Scrollable.ensureVisible` na âncora. Em tela estreita o
   shell abre o drawer (`GlobalKey<ScaffoldState>`) para passos do menu/busca/botão e o fecha para sino/conta,
   esperando a animação (respeita `disableAnimations`). Sidebar recolhida é expandida ao iniciar.
3. **Texto:** `apps/superadmin/lib/app/tour/superadmin_menu_tour_steps.dart` — uma `const` por passo, na ordem e com
   os títulos do rascunho; `superadminMenuTourSteps` reúne todos. Nenhum texto no shell. Anchor = `id` do nó ou
   `tour-button` / `navigation-search` / `report-bug` / `notifications` / `account` / `account-profile` /
   `account-settings` / `account-logout` (`superadminTourShellAnchors`).
4. **Disponibilidade:** `coeloNavigationNodeVisible(id, environment, canAccess)` (nó e ancestrais) com o ambiente
   da rota (`/dev/` = development) e a mesma checagem de capacidade do menu. Só Planos (dev-only) fica sem passo.
5. **Persistência:** `SuperadminTourStore` (`apps/superadmin/lib/app/tour/superadmin_tour_store.dart`);
   `SharedPreferencesSuperadminTourStore` grava `coelo.superadmin.tour.menu.<userId>` = `done|skipped` (userId =
   `client.auth.currentUser?.id` só com sessão autenticada; sem usuário, `hasSeenMenuTour()` devolve `null` e nada é
   gravado). Fio: `SuperadminAuthScope.tourStore` → `SuperadminApp` → `createSuperadminRouter` →
   `SuperadminShell.host`. O preview `/dev` recebe `null` (não abre sozinho nem grava). Primeiro acesso: pós-frame do
   shell que desenha o menu; com `null` o shell repergunta no próximo build (o hospedeiro rebuilda quando sessão e
   perfil chegam) e, antes de abrir, espera até 30 frames pela âncora do primeiro passo.
6. **Flyout "Fazer tour":** `menu` abre o tour do menu; `complete` avisa ("O tour completo (menu e todas as telas)
   chega em breve. Abrindo o tour do menu.") e abre o mesmo tour — o Owner definiu em 18/09 que o completo é a
   soma do menu com todas as telas, que dependem dos tours por tela (próximo prompt); `screen` mostra "O tour desta
   tela chega em breve.". O botão passou a existir também no **drawer** da tela estreita (mesmo rodapé da sidebar),
   senão "refazer pelo botão" seria impossível abaixo de 840 px.
7. **Catálogo:** `core.tour-overlay` (variantes `wide`, `narrow-sheet`) e `core.tour-anchor` no índice, manifesto e
   registry (`_TourOverlayExample` interativo). O `catalog-sync-report.json` regenerado lista **12 diagnósticos
   pré-existentes** (forms-editor, forms-response, directory, directory-status-tabs, create-action,
   multi-select-filter, resizable-table, single-select-field, CoeloCreateAction/CoeloAdminCardGrid/
   CoeloAdminFilterTrigger sem índice) — nenhum deste recorte; o report commitado antes estava desatualizado.

## Feedback do Owner (18/09, teste na rota real) e o que mudou

| Pedido | Resposta |
|---|---|
| Importações e Catálogo foram pulados | Ganharam passo (23 e 32). O rascunho os excluía; textos **provisórios desta sessão**, marcados no arquivo de passos para o Owner ajustar. |
| Faltou o botão Bug | Passo 42 (`report-bug`), âncora no ícone do cabeçalho; texto provisório. |
| Faltou abrir o avatar e falar de cada item | Passos 45–47 (`account-profile`, `account-settings`, `account-logout`): o shell abre o menu da conta antes do passo (controller registrado pelo `_ProfileSummary` no `_SuperadminTourScope`), `CoeloAdminFlyoutItem.tourAnchorId` vira `CoeloTourAnchor` dentro do menu, o balão fica à esquerda do menu (nunca sobreposto) e o menu fecha ao sair desses passos e ao terminar o tour. Textos provisórios. |
| "Concluir" pareceu deslogar | Causa provável: o menu da conta (aberto pelo Owner) fica **acima** do overlay do tour e o clique caiu em "Sair". Agora o tour fecha o menu em todo passo que não é de item do menu e ao terminar; provado na rota real: após Concluir a sessão continua e o store grava `done`. |
| Contorno da Home torto | A âncora incluía o padding do item (recuo à esquerda + 4 px abaixo). Passou a envolver só o retângulo do item. |
| Tour completo = menu + telas | Registrado; aviso no flyout; escopo do próximo prompt (`R16-prompt-tour-telas-20260918.md`). |

Total: **48 passos** (42 do rascunho + 6 pedidos).

## Passos pulados por ambiente

| Ambiente | Passos pulados | Motivo |
|---|---|---|
| Produção (`qa-r06-*`, shell hospedeiro) | nenhum dos 42 | todos os nós dos passos são `_alwaysAvailable` e sem `capability`; Planos/Catálogo/Importações não têm passo |
| Preview `/dev/…` | nenhum (Planos aparece no menu, mas não tem passo) | `tourStore` = null: não abre sozinho |
| Shell isolado (testes, previews) | nenhum | menu completo; sem store |
| Tela < 840 px | nenhum | botão no drawer; sino/conta na app bar compacta |

## Fatias entregues (commits da branch, na ordem — todos para cherry-pick)

| # | Commit | Conteúdo |
|---|---|---|
| 1 | `c9fc65141` | Mecanismo em `coelo_ui_core` (`src/tour/coelo_tour.dart`, export) + 6 widget tests (navegação, pular, teclado, sem âncora, folha inferior, lado da âncora). |
| 2 | `d8b59642e` | Tour do menu no Superadmin: 42 passos, store, âncoras (menu, busca, sino, conta, botão), reveal + rolagem, drawer com botão, fio do store, flyout; teste do flyout existente ajustado; 11 testes novos (4 de cobertura/ordem/limite dos passos, 7 do shell: flyout menu/completo, oculto pulado + grupo abre, primeiro acesso uma vez + grava, já visto não abre, concluir grava done, tela estreita drawer/folha). |
| 3 | `fab56ea6e` | Catálogo: `core.tour-overlay`, `core.tour-anchor`, exemplo, sync report. |
| 4 | `8190dd961` | Feedback do Owner: passos Importações/Catálogo/Bug/conta, menu da conta no tour, contorno centrado, retry de âncora, aviso no "Tour completo", `tourAnchorId` no flyout, catálogo sincronizado; 12 testes. |
| 5 | `86cf1aefd` | Primeiro acesso tolerante (store devolve `null` sem usuário; o shell repergunta a cada build), folha inferior vai ao topo quando a âncora está na metade de baixo; 18 capturas da prova. |
| 6 | (este) | Handoff, prompt dos tours por tela, renomeação de captura. |

## Prova na rota real (18/09, `qa-r06-estrutura`, build QA `qa_main.dart` servido em 3015)

Evidências em `docs/reviews/evidence/etapa-2/r16-tour/`:

- `01-primeiro-acesso-apos-login-1920.png` — login pelo driver → Home: o tour abre sozinho em "1 de 48", âncora no
  botão "Fazer tour". `02-passo-2-home-1920.png` — contorno centrado na Home. `03…-importacoes`, `04…-catalogo`,
  `05…-busca`, `06…-bug`, `07…-sino`, `08…-conta`, `09…-conta-perfil` (menu aberto, balão à esquerda),
  `10…-conta-sair`, `11…-ultimo` ("48 de 48", Concluir), `12-apos-concluir` (tour fechado, menu fechado, sessão
  mantida; `localStorage` `coelo.superadmin.tour.menu.<userId>=done`).
- `20…-home`, `21…-drawer` (botão "Fazer tour" no drawer), `22…-passo-1` (folha no **topo**, botão destacado no
  rodapé do drawer), `23…-passo-3` (folha inferior, Estrutura destacada no drawer), `24…-passo-42-bug` (drawer
  fechado, ícone destacado), `25…-passo-45-conta-perfil` (menu da conta aberto, Perfil apontado) — tudo a 600 px.
- Refazer pelo botão: "Tour do menu" e "Tour completo" reabrem em "1 de 48" (provado em 1440 antes do feedback e em
  600 depois). Primeiro acesso após "visto": não abre sozinho (reload autenticado sem balão).

Observações do ambiente (não são defeitos do tour):

- Com a aba do Chrome em segundo plano o navegador congela os frames; `endOfFrame` só completa quando algo força um
  frame (a captura do CDP). Isso produziu falsos "passo pulado"/"tour não abriu" durante a prova até o driver
  passar a chamar `Page.bringToFront`. Usuário real sempre está com a aba em frente.
- O `tap` do Flutter Driver trava em itens de `CoeloAdminFlyout` dentro do drawer (overlay raiz); usou-se clique
  por coordenada via CDP. `Input.dispatchKeyEvent` do CDP não chega ao Flutter web; os atalhos de teclado (Esc, Enter,
  →, ←) ficam provados pelos widget tests do `coelo_ui_core`.

## Testes

- `packages/coelo_ui_core`: `flutter test test/tour` 7/7; `flutter analyze` limpo.
- `packages/coelo_ui_admin`: `flutter test test/overlay` 19/19; `flutter analyze` limpo.
- `apps/superadmin`: `test/app/tour` + `superadmin_shell_tour_test.dart` 12/12; `superadmin_shell_test.dart` +
  `test/app/navigation` 103/103 (com os anteriores); `flutter analyze` limpo.
- `apps/catalog`: `flutter test test/catalog` 28/28; `flutter analyze` limpo; `validate_catalog_index` mantém os
  3 diagnósticos pré-existentes de `missing-public-file` (specs arquivadas), nenhum novo.
- Suíte completa do `apps/superadmin`: ver seção "Censo" ao fim.

## Resíduos / decisões pendentes do Owner

- Textos provisórios (Importações, Catálogo, Reportar bug, Perfil, Configurações, Sair): revisar em
  `superadmin_menu_tour_steps.dart`.
- Rascunho `tour-menu-rascunho-20260918.md` continua com a lista original de 42; a fonte executável é o arquivo Dart.
- Tour por tela e tour completo: `R16-prompt-tour-telas-20260918.md`.
- Catálogo: os 12 diagnósticos pré-existentes do sync report (fora deste recorte) seguem para a coordenação.

## Censo da suíte do `apps/superadmin`

| Momento | Resultado |
|---|---|
| Antes do recorte (`dev` `6ec7bdfe0`, censo da RESERVA) | +6965 / −143 |
| Depois (branch `r16/tour-menu-20260918`) | **+6977 ~8 −143** |

As 143 vermelhas são as goldens pré-existentes (142) + `agenda_remote_states`, todas fora deste recorte; 0 falhas
funcionais. +12 são os testes novos do tour (4 de passos + 8 do shell), mais 7 no `coelo_ui_core`.

## Fechamento (18/09, noite)

- Owner aprovou na rota real após a rodada de feedback. Por pedido do Owner, os commits ficam na branch publicada e
  **não** são repassados a nenhuma sessão par; a integração em `dev` é decisão dele.
- Ambiente limpo: servidor 3015 e Chrome 9415 encerrados, perfil `%TEMP%\coelo-r16-tour-chrome` removido, build QA
  descartado.
- Próximo: `R16-prompt-tour-telas-20260918.md`.
