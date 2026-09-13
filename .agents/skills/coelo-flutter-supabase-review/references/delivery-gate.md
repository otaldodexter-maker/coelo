---
source: decisions/0036-delivery-reconciliation-and-owner-commitments.md
status: active
generated_at: 2026-09-13
---

# Gate obrigatório de entrega e de fechamento

Aplicar às cinco skills Coelo UI, Conhecimento, FE, BE e FE+BE. Este contrato
prevalece sobre notas históricas de rodadas anteriores. Não amplia autorização
de produto, SQL ou deploy. O pedido atual do Owner define o recorte.

## Abertura e atualizações

- Ler todos os pedidos ativos do Owner e os anexos; registrar cada compromisso
  em JSON de entrega, com `id`, `status`, `actionIds`, `fe`, `be`, `e2e`,
  `evidence`, `owner` e `nextGate` quando aberto. Incluir tarefas de processo,
  como consolidar worktrees ou atualizar skills, mesmo sem action_id de produto.
- Nomear checkout de destino e base. Worktree isolada é autoria temporária;
  não é destino presumido. Se houver checkout protegido por instrução explícita,
  registrar caminho, motivo e consequência na entrega.
- A cada apontamento, correção, teste, bloqueio ou corte: atualizar o registro,
  deltas do inventário e os três MDs. Não depender de memória da conversa.
- Não reescrever um pedido incompleto como fora de escopo. Adiamento exige fonte
  aprovada ou corte explícito, com responsável e primeiro gate preservados.

## Antes de afirmar entrega

1. Confrontar manualmente todos os pedidos do Owner com `ownerItems`. A automação
   não consegue descobrir uma mensagem omitida do registro.
2. Aplicar deltas com `apply-tracker-delta.cjs`; validar as três matrizes. Para
   cada tela/subtela, distinguir FE, BE, E2E e o que falta implementar, provar ou
   decidir. Não apresentar um mapa parcial como todas as pendências.
3. Fazer fetch e reconciliar HEAD/remoto, todos os worktrees e stash. Enumerar
   cada SHA exclusivo de branch residual. Relatório antigo não substitui o Git atual.
4. Revisar o conteúdo residual. Equivalente/superado exige prova e sucessor;
   o que não foi revisado fica `retained-review`, nunca “integrado”. Não executar
   `merge -s ours`, reset, squash ou descarte para zerar ahead/behind.
5. Integrar/publicar o autorizado. Arquivar worktrees somente com backup
   verificável de refs/commits/ignorados e instrução de restauração. Preservar
   recursos sintéticos e segredos fora do Git. Não remover diretório em uso.
6. Conferir as cinco skills e referências no checkout final, não só na worktree
   autora. Confirmar que o runtime/deploy, se exigido, corresponde ao código
   entregue. Push não é deploy.
7. Concluir o gate de memória: fonte canônica primeiro, projeção durável por
   audiência depois, validação ou no-op fundamentado.
8. Commit/push, checkout limpo e executar no destino:

```text
rtk proxy python -X utf8 docs/reviews/delivery_gate.py docs/reviews/entrega-atual.json
```

O JSON declara `baseReference`, `target`, `protectedWorktrees`, `completion`,
`ownerItems`, `residualBranches`, `evidenceFiles`, `memory` e `deployment`.
Cada branch residual registra HEAD, lista exata `exclusive`, disposição,
motivo/evidência e responsável/próximo gate quando retida. `preservedStash`
registra os stashes existentes com motivo/evidência. Arquivos de evidência
precisam existir e estar versionados.

## Resultado permitido

- `PASS COMPLETE`: as verificações estruturais passaram e não há compromisso
  aberto no recorte. Ainda não substitui a prova de produto exigida pela ação.
- `PASS DOCUMENTED_PARTIAL`: a parte entregue está reconciliada, mas há itens
  abertos ou história não revisada. A resposta deve dizer “parcial” e listar
  primeiro gate/responsável. Não usar “tudo limpo”, “tudo integrado” ou “concluído”.
- `FAIL`: corrigir ou registrar impedimento concreto e informar que o gate
  falhou. Não emitir declaração de conclusão.

Antes da resposta final, conferir novamente o HEAD remoto e alterações locais.
Apresentar destino, commit, worktrees restantes, pendências por camada, deploy
real e resultado do gate. Qualquer restrição do Owner continua explícita.
