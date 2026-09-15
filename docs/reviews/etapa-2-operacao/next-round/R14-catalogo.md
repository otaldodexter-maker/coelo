---
source: R13-pendencias.md; R13-prompt-execucao-20260914.md; R13 fechamento formal
status: histórico de preparação; superado pela fila R14; não executar
lifecycle: "historical"
generated_at: 2026-09-14
updated_at: 2026-09-14
---

# Catálogo de preparação R14

> **Superado em 14/09/2026:** a fila consolidada e viva é `R14-pendencias.md`. Este
> catálogo fica como proveniência da preparação.

R14 já foi aberta. Este arquivo continua somente um mapa de preparação; não é
fila executável, não cria `owner.r14-*`, não renumera `action_id` e não concede
autorização nova.

Na abertura formal, o catálogo deve ser regenerado a partir do fechamento
confirmado da R13 e conter apenas itens não terminais: `open`, `partial`,
`blocked` ou sem prova exigida. Itens `done` ou aceitos não retornam. Os IDs
`owner.r12-*`, `H*` e `action_id` são preservados, com a nova rodada registrada
como destino e com evidência do primeiro gate.

## Transferência preparada fora da cota atual da R13

Esta seção é uma preparação solicitada pelo Owner em 14/09/2026. Não abre a
R14, não altera a fila R13 e não cria IDs. Só deve ser incorporada ao catálogo
formal depois do fechamento da R13, se os itens continuarem não terminais.

### Itens preparados para R14

- Circular: `H04`.
- Formulários: `H10`, `H11`, readers de Planos/reader self da Conta e Local
  interno em Formulários, estes três últimos condicionais à verificação de
  contrato e disponibilidade de cota.
- Principal: `H27`, `P54` e `H02`.
- Perfis de acesso: `owner.r12-19` a `owner.r12-27`.
- Segurança infantil: o bloco ainda não resolvido da área, incluindo
  `owner.r12-09` a `owner.r12-18`; `owner.r12-18` também é o item SQL c de
  pessoa sem conta.
- Avaliações: `assessments.close` e `assessments.reopen`.
- Conta: foto privada R2 de `owner.r12-46`.
- SQL c: `owner.r12-18`, `owner.r12-33`, `asset_id` no chat-media e a Edge
  Function correspondente.
- Demais gates preservados: `H03`, `H07`, `H09`, `H12`, `H14`, `H16`,
  `H18`–`H20`, `H22`, `H24`–`H26` e `H28`.

### O que permanece na cota R13

Saúde/Cuidado foi concluído na rota real em 14/09 (SHA 8ca0f9fcd): `health-care.create/
detail/edit` e `medication.list/create/detail/edit` `verified-e2e`; `owner.r12-28/31/32`
done; `owner.r12-29/30` parciais (múltiplos registros/orientações independentes
não exercitados). A cota do Owner de 14/09 encerrou aqui.

### Itens que ficaram sem cota em 14/09 e também seguem para a R14

- Cardápios na rota real (`meal-plans.create/edit/model-create/model-edit/publish`)
  e `owner.r12-36`/`owner.r12-37` (migration sem Prioridade/Datas excluídas +
  bloqueio de sobreposição); `owner.r12-19` a `owner.r12-27` já listados acima.
- OQ-031 catálogos globais de tipo (instituição/unidade/turma/atividade,
  idempotentes por `code`, com Outros; listas na ADR 0038).
- `H08` Duplicar Aviso (RPC + cliente) e Avisos na rota real (`H23`/`H13`).
- `owner.r12-47` localhost na allowlist de redirect do Auth.
- `owner.r12-29`/`owner.r12-30` (resíduo: CRUD individual de vários registros).
- Cosmético sem `action_id`: placeholder de carregamento da edição de
  medicação usa o subtítulo padrão do shell.

## Fontes na abertura

1. `docs/agent/current-state.md`;
2. `docs/reviews/etapa-2-operacao/ETAPA-2-estado-atual.md`;
3. fechamento/checkpoint final da R13;
4. `R13-pendencias.md` e o inventário por `action_id`;
5. evidências e três rastreadores reconciliados.

Não usar snapshots de R12 ou arquivos de preparação antigos como fila. Eles
podem ser consultados apenas para proveniência quando uma fonte corrente os
apontar explicitamente.
