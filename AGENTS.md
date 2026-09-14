# Coelo — contexto mínimo para Codex e Claude

Este arquivo é um mapa curto. Ele não é um histórico de rodadas nem uma
enciclopédia do produto. Para cada tarefa, comece pelo estado atual e siga os
links abaixo; não procure requisitos em backups, artefatos ou documentos
históricos.

## Entrada obrigatória

1. Leia `docs/agent/current-state.md` para saber o que está sendo trabalhado.
2. Leia `docs/agent/source-of-truth.md` para saber qual fonte tem autoridade.
3. Leia `docs/agent/backlog.md` somente quando a tarefa envolver MVP, V1, V2,
   pós-MVP ou pendências gerais.
4. Leia a spec, ADR, contrato ou skill específica apontada pelo índice.

Em 2026-09-14, o Owner confirmou que a Etapa 2 está na R13, em trabalho no
Claude. R14 está preparada, mas não começou. Ao fechar a R13, transfira apenas
itens não terminais para a R14, preserve os IDs e atualize o estado atual antes
de abrir a nova rodada. Itens concluídos não voltam para a fila.

## Produto e arquitetura

Coelo é um superapp privado de rotina, comunicação e cuidado entre instituições,
famílias, responsáveis e alunos. O site público usa Astro em `apps/site`. Os
apps privados usam Flutter em `apps/superadmin`, `apps/admin` e `apps/principal`.
`principal` é o nome canônico do app familiar. Consulte `docs/product/`,
`docs/architecture/`, `docs/data/`, `docs/security/` e `docs/design/` pelos
índices de `docs/agent/source-of-truth.md`.

## Invariantes de segurança

- Autorização, ownership, tenant, hierarquia e regras de negócio são validados
  no backend/RLS; o cliente apenas solicita e renderiza.
- Toda leitura e escrita deve impedir IDOR/BOLA e acesso cruzado entre tenants.
- Tabelas expostas usam RLS deny-by-default; RPCs privilegiadas validam ator,
  capacidade, escopo e MFA quando exigido.
- Nenhum segredo, token, CPF, dado de criança, mídia privada ou log sensível
  entra em Git, bundle, asset, URL ou frontend.
- Mídia privada nova do MVP usa R2 privado; Postgres/Supabase mantém catálogo,
  permissões, vínculos, ownership e auditoria. Consulte a ADR 0032 vigente.

## Documentação

- Uma regra durável deve nascer na fonte canônica e, se necessário, ser
  projetada em `docs/knowledge/`.
- `status` informa qualidade/aprovação; `lifecycle` informa se o artigo é
  `current`, `future`, `historical` ou `superseded`.
- Histórico, handoff, checkpoint, prompt, patch, screenshot e backup não são
  instruções atuais. Não os use como requisito sem apontamento explícito do
  índice atual.
- Conflitos entre fontes vão para `docs/open-questions.md`; não resolva em
  silêncio.
- Não excluir, mover ou sobrescrever artefatos sem aprovação explícita do
  Owner e sem preservar um manifesto recuperável.

## Revisão e implementação

Para revisão Flutter/Supabase, use `docs/agent/review-workflow.md` e a skill
correta: `coelo-frontend`, `coelo-backend` ou `coelo-frontend-backend`. O recorte
precisa declarar objetivo, incluído, fora de escopo, ordem, parada e evidências.
Use os rastreadores atuais apenas pelo índice; os arquivos em `archive/` são
proveniência.

Antes de concluir uma alteração, rode os testes pertinentes, confira o diff e
separe avanço local de aceite FE/BE/E2E. Quando o escopo incluir integração ou
publicação, execute `docs/reviews/delivery_gate.py` após commit/push.

Para conhecimento do produto, use `.agents/skills/coelo-knowledge/SKILL.md`.
Para saída de terminal muito grande, use `RTK.md` explicitamente quando isso
reduzir ruído. Skills compartilhadas vivem em `.agents/skills`; `.claude/skills`
e `.codex/skills` são camadas de acesso, não fontes duplicadas.
