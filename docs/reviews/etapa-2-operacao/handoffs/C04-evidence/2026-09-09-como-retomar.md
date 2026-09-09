---
title: "C04 — como retomar Estruturas"
source: "estado real da worktree em 2026-09-09 03:50 -03:00"
status: "sem WIP; tudo commitado e no remoto"
generated_at: "2026-09-09T03:50:00-03:00"
timezone: "America/Sao_Paulo"
---

# O essencial em cinco linhas

- Worktree: `C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c04`
- Branch: `claude/e2-r01-c04-estruturas`, no `origin`
- Baseline da rodada: `479d1bd1`
- **Não há WIP.** Tudo commitado e empurrado, com `git ls-remote` conferido a
  cada mudança material.
- A rodada tem **136 commits**, 74 arquivos de código e evidência, **58 arquivos
  de teste novos**.

```bash
cd C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c04
git status --short          # só os dois pubspec.lock não rastreados
git log --oneline -15
git ls-remote origin claude/e2-r01-c04-estruturas
```

# Como rodar o que importa

```bash
cd apps/superadmin

# as sete famílias do C04, com lista de falhas completa
flutter test test/features/institutions/ test/features/units/ test/features/groups/ \
  test/features/people/ test/features/children/ test/features/student_tracking/ \
  test/features/locations/ test/features/rpc_definition_reach_test.dart \
  test/features/structures_production_composition_test.dart 2>&1 \
  | grep -E "\[E\]" | sed 's|.*test/|test/|;s|:.*||' | sort | uniq -c
```

Esperado: **21 falhas golden congeladas** (8 Turmas, 7 diretório de Instituições,
2 formulário de Instituições, 2 Unidades, 2 Pessoas) mais **1** golden de Locais
que eu movi de propósito e declarei. **Zero falhas não-golden.**

Contratos que vivem fora do app:

```bash
cd packages/coelo_api && dart test      # 263 verdes
cd packages/coelo_domain && dart test
```

**Depois de qualquer rodada com goldens, a árvore fica suja.** ~62 PNGs em
`test/**/failures/` são reescritos. Restaurar um a um, nunca com `checkout`
amplo:

```bash
cd C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c04
git status --short | grep "/failures/" | awk '{print $2}' > /tmp/f.txt
test -s /tmp/f.txt && xargs -a /tmp/f.txt git checkout --
```

# O que está reservado e não é meu

- **Router e composition root** (`superadmin_router.dart`, `superadmin_routes.dart`,
  `superadmin_app.dart`, `superadmin_auth_scope.dart`) — reserva nominal
  necessária. Deixei dois patches escritos e não aplicados: a linha que compõe
  `onOpenLocationCatalog` no detalhe de Unidade (revisão 38) e o `key:` nos
  quatro builders de formulário (revisão 53).
- **Widgets compartilhados** (`apps/superadmin/lib/shared/`,
  `packages/coelo_ui_admin/`) — foi por isso que o retry no estado negado ficou
  **desabilitado** em vez de oculto: ocultar exigiria mexer no rodapé que todo
  formulário usa.
- **Migrations e replays remotos** pertencem à C00. Três pacotes de Locais estão
  escritos, verificados em container descartável e **nunca aplicados**; o runbook
  é `2026-09-08-replay-locais.md`.
- **Goldens estão congeladas.** Nunca regenerar; medir o movimento e declarar.

# Onde procurar cada coisa

| Quero saber | Documento |
|---|---|
| estado de cada uma das 47 ações | `2026-09-09-estado-das-47-acoes.md` |
| o que espera decisão, nominalmente | handoff `C04.md`, revisão 47 |
| como aplicar os três pacotes SQL | `2026-09-08-replay-locais.md` |
| quais arquivos falham no app inteiro | `2026-09-09-falhas-do-app-inteiro.md` |
| armadilhas de medição, para não repetir | `2026-09-09-metodo-e-armadilhas.md` |
| verificação local dos pacotes SQL | `C04-evidence/scratch-20260908-1638/` |

# Se você vai integrar

A cadeia que liga Locais ao app são **cinco commits de código**, e nenhum sozinho
basta:

```
023f19ea  contrato mínimo de seleção de local
1b3418a8  recuperação do snapshot 9e689374
8d987663  locations_page.dart, a página do catálogo por escopo
e4489224  tela do pipeline CHILD
567b3993  as rotas, o portão de unidade e a migration fundação
```

`git merge-base --is-ancestor 567b3993 HEAD` dá **verdadeiro** nesta branch.

Espere encontrar **19 arquivos de teste falhando em `app/router`** ao integrar.
Eles não vêm das minhas famílias, têm mais de uma forma de falha, e eu **não
afirmo** que são pré-existentes — não fiz atribuição por baseline, por decisão
registrada. Não os confunda com efeito da cadeia.

# Se você vai continuar o trabalho

O veio que mais rendeu está descrito em `2026-09-09-metodo-e-armadilhas.md`:
comparar os dois lados de um contrato lendo o texto da migration. Cinco medidos,
quatro tinham problema.

O que sobrou está quase todo esperando decisão — a tabela das treze está na
revisão 47. As duas de maior consequência: **a lease de banco** para aplicar
Locais, e **integrar a cadeia** acima mais a linha do detalhe de Unidade. A
primeira destrava quatro ações; a segunda transforma um catálogo que só abre por
URL num catálogo que se alcança navegando.
