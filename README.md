# Coelo

Fundacao documental e arquitetural do monorepo Coelo.

O repositorio esta preparado para Spec-Driven Development antes de qualquer codigo de produto. Os DOCX oficiais copiados para `docs/source/originals/` continuam sendo fonte primaria; os Markdown em `docs/` sao derivados estruturados para consulta, revisao e trabalho incremental.

## Superficies planejadas

- `apps/site`: Astro para o site publico em `coelo.me`.
- `apps/superadmin`: Flutter para operacao interna Coelo em `superadmin.coelo.me`.
- `apps/admin`: Flutter para gestao da instituicao em `admin.coelo.me`.
- `apps/principal`: Flutter para responsaveis, familias e alunos em `app.coelo.me`.

## Pacotes compartilhados

- `packages/coelo_tokens`
- `packages/coelo_ui_core`
- `packages/coelo_ui_admin`
- `packages/coelo_ui_principal`
- `packages/coelo_domain`
- `packages/coelo_api`
- `packages/coelo_auth`
- `packages/coelo_database`

## Fluxo de trabalho

1. Consulte `AGENTS.md` antes de qualquer mudanca.
2. Leia os DOCX oficiais e os Markdown derivados relevantes.
3. Registre conflitos em `docs/open-questions.md`.
4. Crie ou atualize uma spec pequena em `specs/`.
5. Registre decisoes persistentes em `decisions/`.
6. So implemente produto depois de aprovacao explicita da spec.

## Branches

- `main`: base valida/aprovada do projeto.
- `dev`: trabalho em teste, specs, spikes e preparacao antes de virar base valida.

O repositorio deve manter apenas essas duas branches principais. Trabalhos temporarios devem ser consolidados em `dev` antes de qualquer promocao para `main`.
