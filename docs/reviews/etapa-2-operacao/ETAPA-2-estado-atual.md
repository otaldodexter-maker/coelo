---
title: "Etapa 2 — estado atual e fila vigente R14"
source: "decisions/0038-owner-decisions-etapa2-backlog-20260914.md; decisions/0040-agora-immediate-removal.md; R14-pendencias.md; R01–R13 históricos; coelo-flutter-pendencias.md; coelo-supabase-pendencias.md; coelo-flutter-integrado-supabase-pendencias.md; inventario-etapa-2.json"
status: "active; fila vigente R14; R01–R13 históricos"
lifecycle: "current"
generated_at: "2026-09-14"
updated_at: "2026-09-15"
base: "dev"
revision: "a85ac01c45dac2a615dab3fcffd64eaedcb9ff02"
environment: "checkout consolidado local; sem deploy ou mutação remota"
---

# Etapa 2 — estado atual

Este é o ponto de entrada da Etapa 2 para a fila de pendências. A fila
operacional vigente é a R14: os itens não terminais foram consolidados a partir
da R13 e, após quinze aceites `done` registrados até 15/09, 38 permanecem não
terminais, além dos resíduos H02–H28 herdados de R01–R07. H01 está resolvido e
não volta para a fila. R01–R13 permanecem como fontes
históricas; seus itens pendentes não devem continuar apontando para uma rodada
anterior como destino executável.

Isso não desfaz código, evidência ou estado do inventário. O inventário mantém
o último estado canônico por `action_id`; a decisão do Owner de 15/09 acrescenta
o novo `agora.remove` como ação formal pendente. A separação abaixo distingue a fila R14 das fontes
históricas e das 29 ações formalmente adiadas para pós-MVP.

Detalhamento operacional: [`R14-pendencias.md`](next-round/R14-pendencias.md) e
índice das rodadas [`RODADAS.md`](next-round/RODADAS.md). O checkpoint final da
R13 permanece apenas como proveniência do corte que abriu a R14.

O relatório de entrega corrente enumera a distribuição de estados por camada a
partir do inventário; não replique aqui uma união manual de ações não terminais.
As 29 ações `deferred-post-mvp` continuam explicitamente rastreadas, mas ficam
fora do trabalho corrente do MVP.

> Fila viva desde 14/09/2026: `next-round/R14-pendencias.md` (R12/R13 congeladas).

## Snapshot de execução da R14 — C residual, D/E integrados

O corte publicado e os percentuais canônicos acima permanecem inalterados porque
o inventário não recebeu delta de certificação E2E. A Sessão C encerrou com
Perfis de acesso não confirmados, Segurança infantil bloqueada por 504/drift e
Expirar/Excluir de Formulários pendentes; `assessments.close/reopen` tem prova
publicada, mas continua `pending-verification` no inventário até reconciliação.

A Sessão D foi integrada seletivamente (`0ab6abd8f`, `7797a8cad`, `2cd0da7c2`,
`b135c8f20`); as migrations de coleções de cuidado, catálogos OQ-031 e Account
self têm pgTAP remoto 6/6, 11/11 e 6/6. O dump produtivo foi preservado fora do
Git com manifesto. A prova técnica não altera contadores sem delta oficial.

A Sessão E foi integrada em `b023b4ccb`/`382c3b975`, com Agora/R2/Edge e
`agora.remove` tecnicamente provados. A negativa cross-tenant específica foi
tentada, mas o helper/fixture remoto não existe no schema vinculado; a evidência
está bloqueada em `8ac946b3a`. Permanecem para R16 Stream sem contrato,
residual produtivo de `owner.r12-46`, H10/H11 remoto e gates sem
`action_id`/contrato/evidência.
Qualquer prova local precisa ser seguida de rota real, commit, sincronização dos
rastreadores, `validate-trackers.cjs` e gate antes de alterar os números.

## Percentuais canônicos

Base: inventário `docs/reviews/inventario-etapa-2.json`, revisado em
2026-09-15 após as fatias publicadas das Sessões 1 e 2, no checkout `dev`,
SHA `a85ac01c45dac2a615dab3fcffd64eaedcb9ff02`.
Os denominadores são por camada e não devem ser somados entre si.

| Indicador | Resultado | Percentual | Leitura |
|---|---:|---:|---|
| FE verificado | 184 / 232 | 79,31% | terminal FE da base inteira |
| FE local-green | 13 / 232 | 5,60% | avanço local; não é aceite E2E |
| BE concluído/verificado | 166 / 225 | 73,78% | somente ações aplicáveis ao BE |
| BE local-green | 13 / 225 | 5,78% | avanço local; não é prova remota |
| E2E verificado | 157 / 193 | 81,35% | base integrada ativa após o Bloco B e a formalização de `agora.remove` |
| E2E + flutter-only | 164 / 232 | 70,69% | soma de categorias sem dupla contagem; `flutter-only` segue separado de E2E |
| Owner items done | 15 / 53 | 28,30% | IDs de Owner, não action IDs |
| Owner items abertos/parciais | 38 / 53 | 71,70% | complemento dos 15 concluídos |

O denominador de BE é 224 porque sete ações não são aplicáveis ao backend. Da
mesma forma, `164/231` é somente a métrica combinada E2E + flutter-only; para
aceite integrado, a base correta continua sendo `157/192`.

## Fila vigente R14 — pendências herdadas

O detalhe completo permanece na fila única R14 e nas seções de auditoria dos três
rastreadores. A tabela abaixo é o índice operacional mínimo;
cada item continua `open`, `partial` ou dependente de decisão/prova até que o
primeiro gate seja fechado.

| ID | Origem | Dono / gate | Trabalho que falta |
|---|---|---|---|
| H02 | noturna/R01 | G4 | Decidido (ADR 0038): conectar no MVP. Conectar consumidor produtivo e provar na rota normal. |
| H03 | noturna/R01 | G4 | Reconciliar a composição de quatro abas de Perfil com a referência vigente e decidir o consumidor produtivo. |
| H04 | R02/R07 | G6 | Unificar o compositor de Circular e blocos intercalados no host produtivo, com rota normal. |
| H05 | noturna/R01 | G4 + G5 | Decidido (ADR 0038): participantes ativos atuais; fechado sem mudança. |
| H06 | noturna/R01 | G4 + G5 | Decidido (ADR 0038): proibir revogar em somente leitura no servidor; pgTAP. |
| H07 | noturna/R01 | G5 | Fazer teste de replay/contexto para hash de edição/revogação com `conversation_id` na revisão profunda. |
| H08 | R02 | G6 | Transferido para R15 por decisão do Owner em 15/09: falta contrato produtivo do item a duplicar e `action_id`; não inventar RPC/payload. |
| H09 | R04/R06 | C0 + G4 + G5 | Medir o disparo agendado real de expiração do Agora; filtro de leitura não basta. |
| H10 | noturna/R01 | G3 | Decidido (ADR 0038): preservar todas as regras de audiência; teste. |
| H11 | noturna/R01 | G3 | Decidido (ADR 0038): autosave do autor ligado; host passa `authoringApi`. |
| H12 | noturna/R01 | G3 | Localizar/definir controles de mínimo e máximo de seleção e registrar o aceite. |
| H13 | noturna/R01 | G4 + G6 | Transferido para R15 por decisão do Owner em 15/09: falta referência produtiva do item relacionado e `action_id`. |
| H14 | R06 | C0 + G6 | Mapear `action_id` e subaceite do sino sem criar denominador novo. |
| H15 | R06 | G7 | Decidido (ADR 0038): `plans.assign` fora do MVP; fechado. |
| H16 | R06 | G5 | Provar o escopo institucional de leitura people-based entre unidades. |
| H17 | R06 | G5 | Decidido (ADR 0038): só capacidade; nova `care_policies.manage`, remover papel fixo; pgTAP. |
| H18 | R06 | G5 + G1 | Revisar concorrência e unicidade global de `@` com teste entre tabelas. |
| H19 | R06 | G3 | Reproduzir o responsável vazio em Medicação com contexto e destinatário válidos. |
| H20 | R06 | G3 | Localizar o consumidor/gateway da imagem da dose e obter prova específica de mídia. |
| H21 | R07 | G6 | Decidido (ADR 0038): 4.000 no total; compositor segue a referência inteira; regravar 6 goldens. |
| H22 | noturna/R01 | G6 + G5 | Alinhar descritor privado da Circular à ADR 0032 e provar que não há bucket público. |
| H23 | noturna/R01 | G6 | Transferido para R15 por decisão do Owner em 15/09: implementar junto com o contrato de Avisos/H08/H13. |
| H24 | noturna/R01 | G4 | Comparar rótulos do Sobre com a referência vigente, sem misturar famílias visuais. |
| H25 | noturna/R01 | C0 + G3 | Medir o alvo de redimensionamento de tabela com teclado, semântica e toque. |
| H26 | noturna/R01 | G3 | Reconciliar opcional omitida, escala legada invertida e opções vazias por contrato atual. |
| H27 | noturna/R01 | G4 | Decidido (ADR 0038): saudação por hora do dia; ponto laranja em Momentos. |
| H28 | R01 | G2 + G4 | Reconciliar filtros de Pessoas/atividade/localidade, avatar e buffers de upload apenas nas diferenças funcionais persistentes. |

H01 (credencial QA exposta) foi resolvido por rotação registrada em 12/09 e
não deve ser reaberto por esta organização documental.

## Ordem de execução da Etapa 2

1. As decisões de H02, H05, H06, H08, H10, H11, H13, H15, H17, H21, H23 e
   H27 e dos `owner.r12-*` 02/10/18/23/33/36/37/47/51/53 estão tomadas na
   ADR 0038; o próximo gate de cada um é implementação ou prova. Restam
   conciliações técnicas em H03, H04, H12, H22, H24 e H26.
2. Em paralelo, reproduzir gates independentes: H07, H09, H14, H16, H18,
   H19, H20, H23, H25 e H28.
3. Para cada correção executável: teste pertinente antes do código novo,
   menor implementação, teste direcionado, analyze/lint aplicável, evidência
   por `apps/superadmin → menu → tela → subtela/estado → action_id` e atualização
   da fonte canônica, inventário e três matrizes.
4. Só promover um aceite quando houver a prova adequada à camada. Rota aberta,
   mock, `/dev`, fail-closed, screenshot isolado e teste local não certificam
   E2E.

## Rodadas preservadas

O índice e o estado de cada rodada estão em
[`next-round/RODADAS.md`](next-round/RODADAS.md). R01–R13 são as origens
históricas dos itens incorporados. R14 é a fila vigente; R15 não foi aberta.

## Fechamento documental

Após qualquer mudança, executar `rtk node docs/reviews/validate-trackers.cjs`.
No fechamento autorizado, executar também
`rtk proxy python -X utf8 docs/reviews/delivery_gate.py docs/reviews/entrega-atual.json`.
O estado final deve distinguir `PASS COMPLETE` de
`PASS DOCUMENTED_PARTIAL` e listar cada bloqueio externo verificável.
