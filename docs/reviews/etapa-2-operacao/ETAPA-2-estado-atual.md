---
title: "Etapa 2 — estado atual e fila vigente R15"
source: "decisions/0038-owner-decisions-etapa2-backlog-20260914.md; decisions/0040-agora-immediate-removal.md; R15-pendencias.md; decisions/0042-r14-closure-r15-opening-20260916.md; R01–R13 históricos; coelo-flutter-pendencias.md; coelo-supabase-pendencias.md; coelo-flutter-integrado-supabase-pendencias.md; inventario-etapa-2.json"
status: "active; fila vigente R15; R01–R14 históricos"
lifecycle: "current"
generated_at: "2026-09-14"
updated_at: "2026-09-17"
base: "dev"
revision: "8334d3695 (fechamento da R14 / abertura da R15, 16/09)"
environment: "checkout consolidado local; sem deploy ou mutação remota"
---

# Etapa 2 — estado atual

Este é o ponto de entrada da Etapa 2 para a fila de pendências. A fila
operacional vigente é a **R15** (aberta em 16/09/2026, ADR 0042): tudo o que
ficou não terminal de R01 a R14 foi consolidado nela — 32 Owner items
abertos/parciais (21 `done` não retornam), resíduos H02–H28 de R01–R07, itens
da ADR 0038, 27 ações não terminais do inventário e os resíduos operacionais
da varredura. R01–R14 permanecem como fontes históricas; seus itens pendentes
não devem continuar apontando para uma rodada anterior como destino executável.

Isso não desfaz código, evidência ou estado do inventário. O inventário mantém
o último estado canônico por `action_id`; a decisão do Owner de 15/09 acrescenta
o novo `agora.remove` como ação formal pendente. A separação abaixo distingue a fila R15 das fontes
históricas e das 29 ações formalmente adiadas para pós-MVP.

Detalhamento operacional: [`R15-pendencias.md`](next-round/R15-pendencias.md) e
índice das rodadas [`RODADAS.md`](next-round/RODADAS.md). O checkpoint final da
R13 permanece apenas como proveniência do corte que abriu a R14.

O relatório de entrega corrente enumera a distribuição de estados por camada a
partir do inventário; não replique aqui uma união manual de ações não terminais.
As 29 ações `deferred-post-mvp` continuam explicitamente rastreadas, mas ficam
fora do trabalho corrente do MVP.

> Fila viva desde 16/09/2026: `next-round/R15-pendencias.md` (R12/R13/R14 congeladas).

## Snapshot de 17/09 — R15 em execução paralela

Cinco sessões em worktrees `r15-bloco-*` (`next-round/R15-execucao-paralela.md`),
integração em `dev` por cherry-pick. Lote 75 em produção (OQ-047: 40001 → PT409
em 126 RPCs, Bloco B). Integradas local-green: Chat E3 (spec 058), B5 (spec 061)
e B6 (spec 062); B5/B6 aguardam aplicação em produção. Certificados em produção
em 17/09: `chat.attach` (lote 76), `access-profiles.edit/assign`; corte: FE 192/232
(82,76%), BE 173/219 (78,99%), E2E 165/186 (88,71%), Owner 29/53. Os percentuais
das seções antigas abaixo são o corte de abertura da R15 (16/09).

## Snapshot de 16/09 — Mesa do Owner (ADR 0041)

O Owner decidiu as 27 pendências que dependiam dele
(`decisions/0041-owner-decisions-r14-mesa-20260916.md`). Efeitos no corte:
Cardápios, `r12-09` e `r12-11` → `done` (Owner 21/53); OQ-031 e reader self
concluídos na ADR 0038; `institutions.files` → `deferred-post-mvp`; seis
páginas de erro → `flutter-only` (BE `not-applicable`). O denominador E2E
ativo passa de 193 para 186 e o BE aplicável de 225 para 219 **por
reclassificação autorizada**, não por certificação nova; os numeradores
não mudaram. `r12-29/30` não foram aceitos e viram spec na R15.

## Snapshot de 16/09 — fechamento da R14 e abertura da R15

A R14 fechou em `8334d3695` (`next-round/R14-fechamento.md`): +3 E2E no dia
(`access-profiles.create`, `agora.create`, `agora.view`), OQ-046, lotes 72/73,
causa do 504 de Segurança da criança observada (OQ-047), cabeçalho global
estabilizado (C1), B1/B2/B3/B8 implementados localmente. Seis migrations
verdes no espelho aguardam aplicação em produção e o PostgREST segue em
incidente; por isso o Owner abriu a R15 com toda a sobra (ADR 0042). Os
percentuais abaixo são o corte de abertura da R15.

## Snapshot de 16/09 — segunda onda integrada (Sessões 5–8)

Integração por cherry-pick em `dev` (`6ddf6a72e`): `access-profiles.create`,
`agora.create` e `agora.view` → `verified-e2e` (E2E 159 → 162);
`agora.publish`/`agora.expire` → BE `done` (BE 168 → 171); FE de Perfis e do
Agora (rota de remoção) → 189. OQ-046 resolvida (lote 72) e lote 73
(`20260915203000`) aplicado pelo rito. Segurança da criança: causa do 504
observada (SQLSTATE 40001 reexecutado sem limite pelo PostgREST 14.5),
correção D4 e escopo D3 versionados com pgTAP verde, **aguardando aplicação em
produção** (permissão do executor). Incidente de produção a partir de ~12:28
BRT (pool do PostgREST esgotado por laços de retentativa) bloqueou as demais
provas de rota real; registrado na fila e em OQ-047.

## Snapshot de execução da R14 — C residual, D/E integrados, R15/R16 preparados

O corte publicado e os percentuais canônicos acima permanecem inalterados fora
do delta oficial de Avaliações: `assessments.close/reopen` agora está
`verified-e2e`. A Sessão C contínua encerrou com Perfis de acesso não
confirmados, Segurança infantil bloqueada por 504/sessão/CORS/massa e
Expirar/Excluir de Formulários sem prova remota; estes últimos foram liberados
para R15, sem promoção.

A Sessão D foi integrada seletivamente (`0ab6abd8f`, `7797a8cad`, `2cd0da7c2`,
`b135c8f20`); as migrations de coleções de cuidado, catálogos OQ-031 e Account
self têm pgTAP remoto 6/6, 11/11 e 6/6. O dump produtivo foi preservado fora do
Git com manifesto. A prova técnica não altera contadores sem delta oficial.

A Sessão E foi integrada em `b023b4ccb`/`382c3b975`, com Agora/R2/Edge e
`agora.remove` tecnicamente provados; o contrato local da negativa foi
reforçado em `2707086cf` e recebeu pgTAP comportamental local em `5ae79bef1`.
A negativa cross-tenant produtiva foi tentada, mas o
helper/fixture remoto não existe no schema vinculado; a evidência está bloqueada
em `8ac946b3a`. Permanecem para R16 Stream sem contrato, residual produtivo de
`owner.r12-46`, H10/H11 remoto e gates sem `action_id`/contrato/evidência.
O contexto Atividade de `attendance.create` foi isolado em `14f6facab` e
liberado para R15; o contexto Turma já certificado não foi repetido.
Qualquer prova local precisa ser seguida de rota real, commit, sincronização dos
rastreadores, `validate-trackers.cjs` e gate antes de alterar os números.

## Percentuais canônicos

Base: inventário `docs/reviews/inventario-etapa-2.json`, revisado em
2026-09-16 após a Mesa do Owner (deltas `r14-coordenacao/deltas-mesa-owner-20260916.json`),
no checkout `dev`.
Os denominadores são por camada e não devem ser somados entre si.

| Indicador | Resultado | Percentual | Leitura |
|---|---:|---:|---|
| FE verificado | 189 / 232 | 81,47% | terminal FE da base inteira |
| FE local-green | 12 / 232 | 5,17% | avanço local; não é aceite E2E |
| BE concluído/verificado | 172 / 219 | 78,54% | somente ações aplicáveis ao BE (219 após `errors.*` → not-applicable) |
| BE local-green | 8 / 219 | 3,65% | avanço local; não é prova remota |
| E2E verificado | 162 / 186 | 87,10% | base integrada ativa após ADR 0041 (`institutions.files` pós-MVP; `errors.*` flutter-only) |
| E2E + flutter-only | 174 / 232 | 75,00% | 162 E2E + 12 flutter-only com FE verificado; `errors.409` (flutter-only, FE local-green) não conta até a rota real |
| Owner items done | 21 / 53 | 39,62% | IDs de Owner, não action IDs |
| Owner items abertos/parciais | 38 / 53 | 71,70% | complemento dos 15 concluídos |

O denominador de BE é 219 nesta versão do inventário. A métrica combinada é
`174/232`; para aceite integrado, a base correta continua sendo `162/186`.

## Fila vigente R15 — pendências herdadas

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
