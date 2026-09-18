# Coelo — contexto mínimo para Codex e Claude

Este arquivo é um mapa curto, não um histórico. Para qualquer tarefa, comece
pelo estado atual e siga os links; não procure requisitos em arquivos de
`archive/`, evidências, handoffs antigos ou backups.

## Modo de construção (Owner, 18/09/2026 — vale sobre todo o resto deste arquivo)

- O foco é entregar para o cliente ver. Faça a mudança, rode os testes, mostre
  a tela. Não escreva spec, ADR, evidência, handoff, checkpoint, rodada, Owner
  item nem delta de inventário para trabalho de MVP/V1.
- UI/UX: decida e mostre; o Owner aprova ou corrige olhando a tela.
- Golden vermelha nunca bloqueia: a tela atual é a referência; regrave e siga.
- Produção: migration com pgTAP verde aplica direto (`supabase db query --linked`
  + `migration repair`). Rito completo só em code review, quando o Owner pedir.
- Branch é `dev`. Sem worktree, branch de sessão ou cherry-pick, salvo pedido
  explícito do Owner. Commit pequeno, push em `dev`.
- Invariantes de segurança abaixo continuam valendo.
- Só o que ficar pendente vai para `docs/agent/pendentes.md`, uma linha por item.

## Entrada

1. `docs/agent/pendentes.md` — a lista única do que falta.
2. `decisions/0045-mvp-definition-etapa3-etapa4-20260918.md` — o que é o MVP e o
   corte Etapa 3 × Etapa 4.
3. A skill do que você vai tocar: `coelo-frontend` (Flutter), `coelo-backend`
   (Supabase), `coelo-fullstack` (os dois), `coelo-ui` (componente).

`current-state.md`, `backlog.md`, `R16-pendencias.md`, specs e ADRs antigas são
histórico: consulte só se precisar de um detalhe.

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

## Documentação e revisão

- Não crie spec, ADR, evidência ou rodada para trabalho de MVP/V1. Regra
  durável nova: uma linha na skill certa. Pendência: uma linha em
  `docs/agent/pendentes.md`.
- `docs/archive/`, `docs/reviews/` e specs/ADRs antigas são histórico.
- Não apague nem mova artefato sem pedido do Owner.
- Skills: `coelo-frontend`, `coelo-backend`, `coelo-fullstack`, `coelo-ui`,
  `coelo-knowledge` (produto), `coelo-tutor` (aprendizado). Vivem em
  `.agents/skills`; `.claude/skills` e `.codex/skills` são junctions.
- Saída de terminal grande: `RTK.md`.
