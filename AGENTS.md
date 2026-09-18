# Coelo — contexto mínimo para Codex e Claude

Este arquivo é um mapa curto, não um histórico. Para qualquer tarefa, comece
pelo estado atual e siga os links; não procure requisitos em arquivos de
`archive/`, evidências, handoffs antigos ou backups.

## Entrada obrigatória

1. `docs/agent/current-state.md` — o que está sendo trabalhado e o que está em
   reserva.
2. `docs/agent/source-of-truth.md` — qual fonte tem autoridade e em que ordem.
3. `docs/agent/backlog.md` — só quando a tarefa envolver Etapa 3, V1, V2 ou
   pendências gerais.
4. A spec (`specs/README.md`), a ADR (`decisions/README.md`), o contrato ou a
   skill apontada pelo índice.

## Estado em 18/09/2026

- **ADR 0045 (18/09)**: Etapa 2 fechada; MVP = Etapa 3 (correções da revisão
  de telas com a reserva R16, tour, acesso contextual, specs 065–069) + Etapa 4
  (publicação, `apps/admin`, `apps/principal`/spec 064, push preparado,
  analytics, IA). Importação, MFA e lojas: V1. Regra de trabalho leve da Etapa 3
  em ADR 0045 §7. Lotes 82–83 em produção; Owner 45/53.

### Leitura de 17/09/2026 (histórico)

- **Etapa 2 do MVP: FE 199/199, BE 186/186, E2E 186/186 (100%)**, provados na
  rota real em produção (`docs/reviews/etapa-2-operacao/next-round/R16-checkpoint-20260917.md`).
- A **R16** continua a rodada vigente (ADR 0043) apenas como **reserva**: 14
  Owner items, resíduos H, ajustes de UI/UX e dívida técnica da Mesa R16
  (ADR 0044), guardados em `R16-pendencias.md` para a **revisão de telas antes
  da Etapa 3**. Não execute a reserva sem pedido do Owner; não abra R17.
- A **Etapa 3** (ADR 0035) só abre por decisão explícita do Owner, com proposta
  consolidada; nada dela foi implementado.
- Produção: projeto Supabase `evvbomzejfijozbtgvpt` é o único remoto; último
  lote aplicado: **81**. O GitHub tem só a branch `dev`; trabalho paralelo usa
  worktrees locais criadas de `dev` e integradas por cherry-pick.

## Produto e arquitetura

Coelo é um superapp privado de rotina, comunicação e cuidado entre instituições,
famílias, responsáveis e alunos. O site público usa Astro em `apps/site`. Os
apps privados usam Flutter em `apps/superadmin`, `apps/admin` e `apps/principal`;
`principal` é o nome canônico do app familiar e, na Etapa 2, é hospedado dentro
de `apps/superadmin`. Baselines em `docs/product/`, `docs/architecture/`,
`docs/data/`, `docs/security/` e `docs/design/`, pelo índice de
`docs/agent/source-of-truth.md`.

## Invariantes de segurança

- Autorização, ownership, tenant, hierarquia e regras de negócio são validados
  no backend/RLS; o cliente apenas solicita e renderiza.
- Toda leitura e escrita impede IDOR/BOLA e acesso cruzado entre tenants.
- Tabelas expostas usam RLS deny-by-default; RPCs privilegiadas validam ator,
  capacidade, escopo e MFA quando exigido.
- Nenhum segredo, token, CPF, dado de criança, mídia privada ou log sensível
  entra em Git, bundle, asset, URL ou frontend. Credenciais QA vivem em
  `C:\Users\adrie\Documents\Coelo-backups\` e nunca são impressas.
- Mídia privada usa R2 privado (ADR 0032); Postgres mantém catálogo,
  permissões, vínculos, ownership e auditoria.
- Versão defasada sinaliza `PT409`, nunca `40001` (OQ-047).

## Documentação

- Regra durável nasce na fonte canônica (ADR/spec) e, se necessário, é
  projetada em `docs/knowledge/`. `status` informa qualidade; `lifecycle`
  informa se o artigo é `current`, `future`, `historical` ou `superseded`.
- `docs/archive/`, `docs/reviews/archive/` e `docs/reviews/evidence/` são
  proveniência, não instrução atual (manifesto:
  `docs/agent/archive-manifest-20260917.md`).
- Conflitos entre fontes vão para `docs/open-questions.md`; não resolva em
  silêncio.
- Não excluir, mover ou sobrescrever artefatos sem aprovação explícita do
  Owner e sem manifesto recuperável.

## Revisão e implementação

Para revisão Flutter/Supabase use `docs/agent/review-workflow.md` e a skill
correta: `coelo-flutter-review` (frontend), `coelo-supabase` (backend) ou
`coelo-flutter-supabase-review` (ponta a ponta). O recorte declara objetivo,
incluído, fora de escopo, ordem, parada e evidências. Estados por `action_id`
mudam só por `docs/reviews/apply-tracker-delta.cjs` com certificação;
`validate-trackers.cjs` PASS antes de commitar. Escrita em produção segue o
rito por lote (`docs/knowledge/team/stale-version-pt409-and-production-rite.md`)
com autorização nominal do Owner.

Antes de concluir, rode os testes pertinentes, confira o diff e separe avanço
local de aceite FE/BE/E2E. Quando o escopo incluir integração, publicação ou
entrega formal, execute `python docs/reviews/delivery_gate.py
docs/reviews/entrega-atual.json` após commit/push.

Conhecimento do produto: `.agents/skills/coelo-knowledge/SKILL.md`. UI:
`coelo-ui`. Aprendizado: `coelo-tutor`. Skills compartilhadas vivem em
`.agents/skills`; `.claude/skills` e `.codex/skills` são camadas de acesso.
Saída de terminal muito grande: `RTK.md`.
