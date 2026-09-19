---
title: "Prompt da Sessão TOUR-TELAS — Tour de cada tela e tour completo no Superadmin"
source: "R16-handoff-tour.md (mecanismo e tour do menu entregues em 18/09); decisions/0035 (tour funcional, Etapa 3); packages/coelo_ui_core/lib/src/tour/coelo_tour.dart; apps/superadmin/lib/app/tour/; apps/superadmin/lib/app/shell/superadmin_shell.dart; apps/superadmin/lib/app/navigation/superadmin_navigation.dart; MVP-definicao-etapa3-etapa4-20260918.md (F8)"
status: "active"
lifecycle: "current"
generated_at: "2026-09-18"
updated_at: "2026-09-18"
audience: "team"
---

# Prompt — Sessão TOUR-TELAS (colar numa conversa nova do Claude Code)

> Para abrir: numa conversa nova em `C:\Users\adrie\Documents\Coelo`, cole:
> **"Você é a SESSÃO TOUR-TELAS do Coelo. Leia e execute
> `docs/reviews/etapa-2-operacao/next-round/R16-prompt-tour-telas-20260918.md`
> do início ao fim."**

---

Você é a SESSÃO TOUR-TELAS do Coelo. Em 18/09/2026 a Sessão TOUR entregou o **mecanismo de tour**
(`coelo_ui_core`: `CoeloTourStep`, `CoeloTourAnchor`, `CoeloTourScope`, `showCoeloTour`, balão/folha, teclado,
passo oculto pulado) e o **tour do menu** (48 passos em `superadmin_menu_tour_steps.dart`, âncoras no menu, busca,
bug, sino, conta e itens do menu da conta, persistência local por usuário, botão "Fazer tour" na sidebar e no
drawer). O Owner aprovou ("nota 10") e definiu o próximo passo:

- **Tour desta tela**: um tour por tela do Superadmin, no mesmo conceito — um balão por elemento, apontando para o
  que a tela tem (toolbar, busca, filtros, abas, botão de criar, cards/tabela, paginação, ações da linha, rodapé de
  formulário), com uma frase do que cada coisa faz.
- **Tour completo** = **o tour do menu + o tour de todas as telas**, em sequência, navegando de tela em tela.

Hoje o flyout do botão mostra "O tour desta tela chega em breve." e o "Tour completo" avisa e abre o tour do menu.
Leia `R16-handoff-tour.md` inteiro antes de começar: ele tem o desenho, as âncoras, as lições de ambiente e os
textos provisórios que o Owner ainda vai revisar.

## Ambiente

- Antes de criar a worktree: `ListAgents` e pedir identificação às sessões pares (a coordenadora está na pasta
  principal, `dev`). Confirmar que os commits da branch `r16/tour-menu-20260918` já estão em `dev` (cherry-pick); se
  não estiverem, parar e avisar o Owner — este recorte depende deles.
- Worktree `C:\Users\adrie\Documents\Coelo.worktrees\r16-tour-telas`, branch `r16/tour-telas-20260918` criada de
  `dev`. Todo comando roda na worktree. Porta 3016, CDP 9416, perfil `%TEMP%\coelo-r16-tour-telas-chrome`.
  **Sem espelho de banco e sem SQL**: recorte só Flutter.
- Handoff: `docs/reviews/etapa-2-operacao/next-round/R16-handoff-tour-telas.md`. Evidências em
  `docs/reviews/evidence/etapa-2/r16-tour-telas/`.
- Entrada obrigatória: AGENTS.md; `docs/agent/current-state.md`; `source-of-truth.md`; ADR 0035;
  `R16-handoff-tour.md`; `coelo_tour.dart`; `apps/superadmin/lib/app/tour/*`; `superadmin_shell.dart` (flyout,
  `_SuperadminTourScope`, `_prepareTourStep`); `superadmin_navigation.dart` (ids dos destinos); o router
  (`superadmin_router.dart`: destinos, títulos e páginas); skill `coelo-ui` (famílias administrativa e Principal,
  contratos de toolbar/tabela/cards/paginação/formulário).

## Skills

- `/rtk` no início; `flutter test` e `flutter analyze` pelos wrappers.
- `/brainstorming` uma vez, curto, para fechar: (a) o formato do roteiro por tela, (b) como o tour completo navega
  entre telas e retoma, (c) onde ficam as âncoras dos componentes compartilhados. Registrar no handoff.
- `/coelo-flutter-review` para o recorte e a revisão final; `/coelo-ui` para âncoras nos componentes compartilhados
  (`coelo_ui_admin`, `coelo_ui_core`) e a entrada no catálogo; `/test-driven-development`;
  `/systematic-debugging`; `/verification-before-completion`; `/finishing-a-development-branch`.

## Escopo

**Fase 0 — Roteiros para o Owner (antes de codar telas)**

1. Levantar todas as telas roteadas do Superadmin (destinos de `coeloSuperadminNavigation` com `routeName`, mais
   subtelas de criar/editar/publicar) e, para cada uma, os elementos que merecem passo (toolbar, busca, filtros,
   abas, criar, lista/cards/tabela/kanban, paginação, ações de linha, cabeçalho de detalhe, rodapé de formulário).
2. Escrever `tour-telas-rascunho-20260918.md` no mesmo formato do `tour-menu-rascunho-20260918.md`: uma tabela por
   tela (`#`, âncora, título, texto ≤ 220 caracteres), na ordem do menu. Textos são **propostas** para o Owner
   editar; não inventar comportamento que a tela não tem (ler a spec/ação de cada tela).
3. Parar e pedir ao Owner: aprovação dos roteiros (pode ser por lotes: Estrutura → Acompanhamento → Acessos → Saúde
   → Operação → Comunicação → Governança → Coelo (Principal)) e a ordem de prioridade. Só então implementar.

**Fase 1 — Mecanismo do tour por tela**

4. `SuperadminScreenTour {destinationId, steps}` e um registro `superadminScreenTours` (mapa destino → tour), com um
   arquivo Dart por tela em `apps/superadmin/lib/app/tour/screens/` (uma `const` por passo, como no menu). Nenhum
   texto no shell nem nas páginas.
5. Âncoras nos componentes compartilhados, uma vez só (decisão do Owner de 10/09: conceito de família vive no
   componente): `CoeloAdminListingToolbar`, `CoeloSearchField`, filtros, `CoeloAdminDirectory`
   (cards/tabela/kanban), `CoeloAdminPaginationFooter`, `CoeloAdminUnderlineTabs`, `CoeloCreateAction`,
   `SuperadminFormFrame` (rodapé). Padrão de id: `<destino>.<elemento>` ou id genérico do componente
   (`toolbar.search`, `directory.body`, `pagination`), decidido no brainstorm e documentado. A tela só envolve o que
   é específico dela.
6. Flyout `screen`: abre `superadminScreenTours[currentDestination]`; sem tour para a tela, mensagem "Esta tela ainda
   não tem tour." Passos cujo elemento não está na tela (estado vazio, sem permissão, largura estreita) são pulados
   sem aviso. Rolagem até a âncora dentro da página (`Scrollable.ensureVisible`), folha inferior abaixo de 840 px.
7. Persistência local por tela não é necessária: o tour da tela só abre pelo botão (ou pelo completo).

**Fase 2 — Tour completo**

8. `complete` = tour do menu e, em seguida, para cada tela com tour, navegar até ela (`onDestinationSelected`),
   esperar a página montar (âncora do primeiro passo presente, com o mesmo retry do mecanismo) e rodar o tour da
   tela; ao terminar a última, voltar à tela de origem. Contador global "n de N" (N = soma dos passos disponíveis).
   "Pular tour" encerra tudo; "Voltar" no primeiro passo de uma tela volta ao último da tela anterior.
9. Progresso local (`coelo.superadmin.tour.complete.<userId>` = índice da tela) para retomar se a página recarregar
   no meio; "Concluir" grava `done`. Sem coluna nem RPC.
10. Ordem das telas = ordem do menu; telas de criar/editar/publicar entram só se o roteiro do Owner incluir (elas
    exigem dados; não criar registros de verdade durante o tour).

**Fase 3 — Testes e prova**

11. Widget tests: registro cobre todo destino roteado ou o destino está numa lista explícita de exclusão com motivo;
    tour de uma tela abre pelo flyout e pula passo sem elemento; tour completo navega para a próxima tela, retoma
    após "reload" simulado e volta à origem; nenhum texto ultrapassa 220 caracteres. Sem goldens novos; não regravar
    goldens.
12. Prova na rota real (3016, `qa-r06-*`): tour de três telas de famílias diferentes (uma listagem com tabela, uma
    com cards/kanban, uma do Principal) e o tour completo do início ao fim em 1440 e 600 de largura, com capturas
    do primeiro passo de cada tela, da transição entre telas, do último passo e do retorno à origem.

**Fora de escopo**: home com IA; SQL/migration/Edge/produção; alterar textos do tour do menu (só o Owner);
`apps/admin`/`apps/principal`; tours de telas que o Owner não aprovou no roteiro.

## Regras

- Nenhum `action_id` do inventário muda; `apply-tracker-delta.cjs` não roda; `node docs/reviews/validate-trackers.cjs`
  PASS antes de commitar mesmo assim.
- Nunca `git add -A`, `stash`, rebase, push em `dev`, `--force`. Commits pequenos na branch; publicar como backup ao
  fim; a coordenadora integra por cherry-pick e apaga a branch.
- Credenciais QA em `C:\Users\adrie\Documents\Coelo-backups\`; nunca em log ou commit.
- `flutter analyze` limpo; `flutter test` do `apps/superadmin` com 0 falhas funcionais (só as goldens pré-existentes
  vermelhas, 142 + `agenda_remote_states`).
- Catálogo: se tocar componente compartilhado, atualizar o `example` no índice junto com a fonte (o
  `validate_catalog_sync` compara a impressão digital dos dois contra o report commitado; restaure o report do commit
  antes de rodar, senão ele registra a mudança pela metade).

## Lições da Sessão TOUR (poupam horas)

- **Aba em segundo plano congela frames**: o Chrome só roda `requestAnimationFrame` com a aba visível; `endOfFrame`
  nunca completa e o tour parece "pular passos" ou "não abrir". No driver CDP, chamar `Page.bringToFront` e
  `Emulation.setFocusEmulationEnabled` antes de qualquer comando; nunca concluir defeito sem a aba em frente.
- `tap` do Flutter Driver trava em itens de `CoeloAdminFlyout` dentro do drawer: usar clique por coordenada
  (`Input.dispatchMouseEvent`). `Input.dispatchKeyEvent` não chega ao Flutter web: teclado fica nos widget tests.
- Primeiro acesso logo após o login: `client.auth.currentUser` pode ainda não existir; o store devolve `null` e o
  shell repergunta no próximo build. Não tratar `null` como "já visto".
- O menu da conta (`MenuAnchor`, `useRootOverlay`) fica **acima** do overlay do tour: manter o balão fora dele e
  fechá-lo em todo passo que não aponte um item seu (senão um clique em "Próximo" cai em "Sair").
- Âncora deve envolver o retângulo visual do item, não o `Padding` (senão o contorno fica descentrado).
- Build QA: `node C:\Users\adrie\Documents\Coelo-backups\build-r14-e-qa.cjs` em `apps/superadmin`; servir `build/web`
  com fallback SPA (o servidor de `R16-handoff-tour.md`), Chrome com `--remote-debugging-port` e perfil próprio.

## Parada e entrega

- Parar e registrar bloqueio se: um componente compartilhado exigir refatoração ampla para receber âncora; o tour
  completo precisar de estado no servidor; o Owner precisar aprovar roteiro (Fase 0) ou decidir texto.
- Ao fim: handoff com os roteiros aprovados, o desenho do tour completo, lista de telas sem tour (com motivo),
  evidências, contagem de testes antes/depois, branch publicada e lista de commits para a coordenadora. Não alterar
  `current-state.md`, `backlog.md` nem `R16-pendencias.md`.
