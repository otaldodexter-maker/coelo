---
title: "Prompt da Sessão TOUR — Fazer tour do menu e do cabeçalho no Superadmin"
source: "decisions/0035 (tour funcional, Etapa 3); tour-menu-rascunho-20260918.md (texto aprovado pelo Owner em 18/09 para melhorar depois); apps/superadmin/lib/app/shell/superadmin_shell.dart (_OnboardingTourButton, placeholders); apps/superadmin/lib/app/navigation/superadmin_navigation.dart; MVP-definicao-etapa3-etapa4-20260918.md (F8)"
status: "active"
lifecycle: "current"
generated_at: "2026-09-18"
updated_at: "2026-09-18"
audience: "team"
---

# Prompt — Sessão TOUR (colar numa conversa nova do Claude Code)

> Para abrir: numa conversa nova em `C:\Users\adrie\Documents\Coelo`, cole:
> **"Você é a SESSÃO TOUR do Coelo. Leia e execute
> `docs/reviews/etapa-2-operacao/next-round/R16-prompt-tour-20260918.md`
> do início ao fim."**

---

Você é a SESSÃO TOUR do Coelo. O Owner decidiu em 18/09/2026 executar agora o
item F8 da Etapa 3 (ADR 0035, "Fazer tour funcional"), isolado, só no Superadmin
web, no conceito **orientar o usuário sobre o que cada coisa faz**: um balão por
elemento, apontando para o item do menu ou do cabeçalho, com uma frase. O texto
já está escrito e aprovado para uma primeira versão em
`tour-menu-rascunho-20260918.md`; o Owner vai melhorar depois, então o texto
precisa viver num único lugar fácil de editar.

## Ambiente

- Antes de criar a worktree: `ListAgents` e pedir identificação às sessões pares
  (a coordenadora está na pasta principal, `dev`).
- Worktree `C:\Users\adrie\Documents\Coelo.worktrees\r16-tour`, branch
  `r16/tour-menu-20260918` criada de `dev` (HEAD ≥ `6ec7bdfe0`). Todo comando
  roda na worktree. Porta 3015, CDP 9415, perfil `%TEMP%\coelo-r16-tour-chrome`.
  **Sem espelho de banco e sem SQL**: este recorte é só Flutter.
- Handoff: `docs/reviews/etapa-2-operacao/next-round/R16-handoff-tour.md`.
  Evidências em `docs/reviews/evidence/etapa-2/r16-tour/`.
- Entrada obrigatória: AGENTS.md; `docs/agent/current-state.md`;
  `source-of-truth.md`; ADR 0035; `tour-menu-rascunho-20260918.md`;
  `superadmin_shell.dart` (botão "Fazer tour", flyout com `screen`/`menu`/
  `complete` e as mensagens "será implementado na etapa final");
  `superadmin_navigation.dart` (árvore do menu, ids dos nós, `availability`
  e capacidades); `docs/design/` pelo índice de `source-of-truth.md`;
  skill `coelo-ui` (tokens, estados, responsividade, acessibilidade, catálogo).

## Skills

- `/rtk` no início; `flutter test` e `flutter analyze` pelos wrappers.
- `/brainstorming` uma vez, curto, para fechar o desenho do mecanismo antes de
  codar (overlay, âncoras, navegação, persistência) — registrar no handoff.
- `/coelo-flutter-review` para o recorte (objetivo, incluído, fora, ordem,
  parada, evidências) e para a revisão final.
- `/coelo-ui` para o componente do balão e sua entrada no catálogo.
- `/test-driven-development` nos testes de widget; `/systematic-debugging` em
  qualquer falha; `/verification-before-completion` antes de dizer "pronto";
  `/finishing-a-development-branch` ao encerrar.

## Escopo

**Incluído**

1. **Mecanismo de tour** reutilizável em `packages/` de UI (ou onde o
   `coelo-ui` mandar): lista de passos `{anchorKey, title, text}`; overlay com
   foco no elemento ancorado (recorte escurecido ao redor), balão com título,
   texto, contador "n de N", botões **Voltar**, **Próximo**, **Pular tour**
   e **Concluir** no último; teclado (Esc = pular, Enter/→ = próximo,
   ← = voltar); rolagem automática do menu até a âncora; em tela estreita o
   balão vira folha inferior e o menu lateral abre no passo.
2. **Tour do menu**: os passos de `tour-menu-rascunho-20260918.md`, ancorados
   nos itens de `coeloSuperadminNavigation` pelo `id` do nó, mais busca do menu,
   sino, avatar/Conta e o botão "Fazer tour". Passos cujo nó está oculto por
   `availability`, capacidade ou ambiente são pulados sem aviso. Grupos
   colapsados abrem quando o passo chega neles.
3. **Texto em um único arquivo Dart** (ex.: `superadmin_menu_tour_steps.dart`)
   com uma constante por passo, na mesma ordem e com os mesmos títulos do
   rascunho, para o Owner editar sem tocar no mecanismo. Nenhum texto no shell.
4. **Persistência local** de "tour concluído/pulado" (`shared_preferences` ou o
   que o app já usa) por usuário; primeiro acesso mostra o tour do menu uma vez.
   Sem coluna nova, sem RPC.
5. **Flyout do botão "Fazer tour"**: `menu` abre o tour do menu; `complete`,
   nesta versão, abre o mesmo tour do menu (registrar que o tour completo por
   tela vem depois); `screen` mantém a mensagem de placeholder, reescrita para
   "O tour desta tela chega em breve."
6. **Testes**: widget tests do mecanismo (navegação, pular, concluir, passo
   oculto pulado, teclado), teste do shell abrindo o tour pelo flyout, teste de
   que a lista de passos cobre todo nó de primeiro e segundo nível do menu (para
   não esquecer um item novo). Sem goldens novos; não regravar goldens.
7. **Prova na rota real** (3015, identidade `qa-r06-*` conforme
   `review-scope.md`): tour completo do início ao fim em 1440 e em 600 de
   largura, capturas do primeiro, de um passo do meio, do último e do modo
   estreito; primeiro acesso mostra uma vez; refazer pelo botão funciona.

**Fora de escopo** (não fazer): tour desta tela por página; home com IA;
qualquer SQL, migration, Edge ou escrita em produção; alterar textos além do
rascunho (só o Owner); Principal hospedado; `apps/admin`/`apps/principal`.

## Regras

- Nenhum `action_id` do inventário muda: o tour não tem denominador. Não rodar
  `apply-tracker-delta.cjs`. `node docs/reviews/validate-trackers.cjs` PASS
  antes de commitar mesmo assim.
- Nunca `git add -A`, `stash`, rebase, push em `dev`, `--force`. Commits
  pequenos na branch; publicar como backup ao fim; a coordenadora integra por
  cherry-pick e apaga a branch.
- Credenciais QA em `C:\Users\adrie\Documents\Coelo-backups\`; nunca em log ou
  commit.
- `flutter analyze` limpo e `flutter test` do `apps/superadmin` com 0 falhas
  funcionais (só goldens pré-existentes vermelhos, 142 + `agenda_remote_states`,
  que não são deste recorte).

## Parada e entrega

- Parar e registrar bloqueio se: uma âncora do menu não puder ser localizada
  sem refatorar o shell inteiro; a persistência exigir servidor; o Owner
  precisar decidir algo de texto (não inventar).
- Ao fim: handoff com o desenho do mecanismo, lista de passos pulados por
  ambiente, evidências, contagem de testes antes/depois, branch publicada e a
  lista de commits para a coordenadora. Não alterar `current-state.md`,
  `backlog.md` nem `R16-pendencias.md`.
