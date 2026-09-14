---
source: R13-pendencias.md; R13-prompt-execucao-20260914.md; R13 fechamento formal
status: preparado; não transfere nem encerra R13
generated_at: 2026-09-14
updated_at: 2026-09-14
---

# Catálogo de preparação R14

R14 ainda não foi aberta. Este arquivo é somente um mapa de preparação; não é
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

Saúde/Cuidado e Cardápios na rota real; `owner.r12-36`/`owner.r12-37`; OQ-031
de catálogos de tipo; `H08` Duplicar Aviso; `owner.r12-47` para localhost na
allowlist de Auth; e Avisos (`H08`/`H23`/`H13`) se houver cota. A execução segue
pela R13, sem disparar a R14.

## Fontes na abertura

1. `docs/agent/current-state.md`;
2. `docs/reviews/etapa-2-operacao/ETAPA-2-estado-atual.md`;
3. fechamento/checkpoint final da R13;
4. `R13-pendencias.md` e o inventário por `action_id`;
5. evidências e três rastreadores reconciliados.

Não usar snapshots de R12 ou arquivos de preparação antigos como fila. Eles
podem ser consultados apenas para proveniência quando uma fonte corrente os
apontar explicitamente.
