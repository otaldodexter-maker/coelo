---
title: "Etapa 2 — estado atual e fila vigente R13"
source: "decisions/0038-owner-decisions-etapa2-backlog-20260914.md; R13-pendencias.md; R13-owner-items-atual.json; R01–R12 históricos; coelo-flutter-pendencias.md; coelo-supabase-pendencias.md; coelo-flutter-integrado-supabase-pendencias.md; inventario-etapa-2.json"
status: "active; fila vigente R13; R01–R12 históricos"
generated_at: "2026-09-14"
updated_at: "2026-09-14"
base: "dev"
revision: "1f34b9dbfda5f94b98edbb154ce1841059df67bf"
environment: "checkout consolidado local; sem deploy ou mutação remota"
---

# Etapa 2 — estado atual

Este é o ponto de entrada da Etapa 2 para a fila de pendências. A fila
operacional vigente é a R13: 50 `owner.r12-*` foram transferidos da R12 e,
após seis aceites `done` registrados em 14/09, 47 permanecem não terminais,
além dos resíduos H02–H28 herdados de R01–R07. H01 está resolvido e não volta
para a fila. R01–R12 permanecem como fontes
históricas; seus itens pendentes não devem continuar apontando para uma rodada
anterior como destino executável.

Isso não desfaz código, evidência ou estado do inventário. O inventário mantém
o último estado canônico por `action_id`; os 231 action IDs não ganham novos
IDs pela transferência. A separação abaixo distingue a fila R13 das fontes
históricas e das 22 ações formalmente adiadas para pós-MVP.

Detalhamento operacional: [`R13-prompt-execucao-20260914.md`](next-round/R13-prompt-execucao-20260914.md),
[`R13-pendencias.md`](next-round/R13-pendencias.md), catálogo Owner derivado
[`R13-owner-items-atual.json`](next-round/R13-owner-items-atual.json) e índice
das rodadas [`RODADAS.md`](next-round/RODADAS.md). O checkpoint mais recente
define o primeiro gate da retomada.

No snapshot por `action_id`, a R13 concentra 78 ações ativas com algum gate não
terminal (64 FE, 43 BE e 77 integradas; números por camada, não somáveis). As
22 ações `deferred-post-mvp` continuam explicitamente rastreadas, mas ficam
fora do trabalho corrente do MVP.

## Percentuais canônicos

Base: inventário `docs/reviews/inventario-etapa-2.json`, revisado em
2026-09-14 (17:50, após os lotes SQL 63–69 e a rota real de Estrutura, Conta e Saúde/Cuidado), no checkout `dev`, SHA `8cd8da38bd02b4a8a3537084b4c4b6525b26978d`.
Os denominadores são por camada e não devem ser somados entre si.

| Indicador | Resultado | Percentual | Leitura |
|---|---:|---:|---|
| FE verificado | 164 / 231 | 71,00% | terminal FE da base inteira |
| FE local-green | 30 / 231 | 12,99% | avanço local; não é aceite E2E |
| BE concluído/verificado | 164 / 224 | 73,21% | somente ações aplicáveis ao BE |
| BE local-green | 16 / 224 | 7,14% | avanço local; não é prova remota |
| E2E verificado | 137 / 199 | 68,84% | base integrada ativa |
| E2E + flutter-only | 144 / 231 | 62,34% | soma de categorias sem dupla contagem; `flutter-only` segue separado de E2E |
| Owner items done | 9 / 53 | 16,98% | IDs de Owner, não action IDs |
| Owner items abertos/parciais | 44 / 53 | 83,02% | complemento dos 9 concluídos |

O valor `164/231` não é percentual de BE válido: sete ações não são
aplicáveis ao backend. Da mesma forma, `144/231` é somente a métrica combinada
E2E + flutter-only; para aceite integrado a base correta é `125/199`.

## Fila vigente R13 — pendências herdadas

O detalhe completo permanece na seção **Pendências R13 incorporadas de R01–R07**
dos três rastreadores e no MD da R13. A tabela abaixo é o índice operacional mínimo;
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
| H08 | R02 | G6 | Decidido (ADR 0038): Duplicar no MVP como novo rascunho; RPC + botão + prova. |
| H09 | R04/R06 | C0 + G4 + G5 | Medir o disparo agendado real de expiração do Agora; filtro de leitura não basta. |
| H10 | noturna/R01 | G3 | Decidido (ADR 0038): preservar todas as regras de audiência; teste. |
| H11 | noturna/R01 | G3 | Decidido (ADR 0038): autosave do autor ligado; host passa `authoringApi`. |
| H12 | noturna/R01 | G3 | Localizar/definir controles de mínimo e máximo de seleção e registrar o aceite. |
| H13 | noturna/R01 | G4 + G6 | Decidido (ADR 0038): CTA abre o detalhe do item relacionado por tipo. |
| H14 | R06 | C0 + G6 | Mapear `action_id` e subaceite do sino sem criar denominador novo. |
| H15 | R06 | G7 | Decidido (ADR 0038): `plans.assign` fora do MVP; fechado. |
| H16 | R06 | G5 | Provar o escopo institucional de leitura people-based entre unidades. |
| H17 | R06 | G5 | Decidido (ADR 0038): só capacidade; nova `care_policies.manage`, remover papel fixo; pgTAP. |
| H18 | R06 | G5 + G1 | Revisar concorrência e unicidade global de `@` com teste entre tabelas. |
| H19 | R06 | G3 | Reproduzir o responsável vazio em Medicação com contexto e destinatário válidos. |
| H20 | R06 | G3 | Localizar o consumidor/gateway da imagem da dose e obter prova específica de mídia. |
| H21 | R07 | G6 | Decidido (ADR 0038): 4.000 no total; compositor segue a referência inteira; regravar 6 goldens. |
| H22 | noturna/R01 | G6 + G5 | Alinhar descritor privado da Circular à ADR 0032 e provar que não há bucket público. |
| H23 | noturna/R01 | G6 | Decidido (ADR 0038): lista visível + barra fina, padrão para todas as listas. |
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
[`next-round/RODADAS.md`](next-round/RODADAS.md). R01–R12 são as origens
históricas dos itens incorporados. R13 é a fila vigente; R14 está apenas
preparada e não foi iniciada.

## Fechamento documental

Após qualquer mudança, executar `rtk node docs/reviews/validate-trackers.cjs`.
No fechamento autorizado, executar também
`rtk proxy python -X utf8 docs/reviews/delivery_gate.py docs/reviews/entrega-atual.json`.
O estado final deve distinguir `PASS COMPLETE` de
`PASS DOCUMENTED_PARTIAL` e listar cada bloqueio externo verificável.
