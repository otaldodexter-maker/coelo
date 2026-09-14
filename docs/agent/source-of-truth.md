---
title: "Autoridade e ciclo de vida dos documentos Coelo"
source: "AGENTS.md; decisions/0034-mvp-remote-application-and-acceptance-bar.md; decisions/0038-owner-decisions-etapa2-backlog-20260914.md"
status: "active"
generated_at: "2026-09-14"
updated_at: "2026-09-14"
audience: "team"
---

# Autoridade documental

## Ordem de decisão

1. Instrução direta do Owner na tarefa atual.
2. [Estado atual](current-state.md) e o índice operacional que ele aponta.
3. ADR aprovada mais recente, especialmente quando marca uma decisão anterior
   como `superseded`.
4. Fonte canônica de produto, arquitetura, dados, segurança ou design.
5. Spec ativa aprovada para a superfície da tarefa.
6. Rastreador corrente, apenas para estado, ação, evidência e primeiro gate.
7. Histórico, handoff, checkpoint, prompt e artefato, somente como
   proveniência quando apontados por uma fonte atual.

Uma fonte posterior não deve ser “combinada” silenciosamente com uma anterior.
Se houver conflito, registrar os caminhos em `docs/open-questions.md` e seguir
o documento explicitamente marcado como corrente para a fila de trabalho.

## Ciclo de vida

- `current`: pode orientar o trabalho atual.
- `future`: aprovado ou planejado, mas ainda não disponível nem executável.
- `historical`: preservado para proveniência; não orienta nova implementação.
- `superseded`: substituído por outra fonte indicada.

Qualidade e atualidade são dimensões diferentes. Em `docs/knowledge`,
`status: validated` significa que o artigo passou pela validação estrutural e
de conteúdo permitida; não significa que ele seja a regra atual. O campo
`lifecycle` controla a busca operacional.

## Rodadas

Uma rodada nova recebe a fila não terminal da rodada anterior. O registro atual
é a única fila executável. A rodada anterior permanece como histórico de origem.
Itens resolvidos não voltam, IDs não são duplicados e a abertura da próxima
rodada exige decisão explícita do Owner.
