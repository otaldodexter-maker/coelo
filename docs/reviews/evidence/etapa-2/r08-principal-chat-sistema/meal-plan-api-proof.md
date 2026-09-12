---
fonte: meal_plan_api_smoke.py; RPCs produtivos; lote55 aplicado; autorizacao nominal C0
status: medido-api-sem-aceite-ui
data: 2026-09-12
---

# Cardapios — ciclo real com scopeRules objeto

apps/superadmin → Comunicacao → Cardapios → criar/editar/publicar →
meal-plans.list/create/edit/publish. Prova serial API entre15:37:00 e
15:37:07 UTC, processo exit0. **Nao e prova pela UI**.

`meal-plan-api-manifest.json` registra 24 operacoes/verificacoes aprovadas,
nao 24 testes/action_ids distintos. O delta e a compatibilidade do contrato
do lote55 e o ciclo de um cardapio real; nao repete a autoria de modelo R06.

Modelo existente `d132698c-605d-46b4-bb11-124f85563604`, publishedv2,
reconsultado antes/depois e preservado integralmente. Criado somente o plano
sintetico `8f072222-a9c5-4902-a0d8-ded1d789fe4c`, para staff no grupo QA
`368a5cea-2bcf-4fa4-ad1f-18da58694551`, de21 a25/09/2026.

| Operacao | Estado/versao real |
| --- | --- |
| Criar usando modelo existente | draft/1 |
| Editar o mesmo registro | draft/2 |
| Enviar para revisao | inReview/3 |
| Publicar | published/4 |
| Arquivar sem apagar | archived/5 |

Cada etapa relevante foi reconsultada. `scopeRules` permaneceu objeto com
os mesmos campos/valores, inclusive groupIds; nome editado persistiu e a
listagem retornou o mesmo ID. O arquivamento preservou o registro, que
permaneceu consultavel como archived/5. Nao houve DELETE.

Hierarquia atual e modelo do mesmo tenant foram validados antes da escrita;
conflitos do periodo foram consultados e nenhum existia. Menu veio do modelo
QA sem imagem. Nenhum modelo, midia, ator, permissao ou estrutura foi criado.
Sessao propria encerrada204. Segredos/URLs/tokens nao foram registrados.

O plano e o modelo ficam preservados ate o fim formal da Etapa2. Nao ha
negativo cross-tenant real, pois atores QA disponiveis sao Owner/platform.
Proximo gate permanece a UI normal sobre o lote55; G4 nao altera inventario
ou rastreadores nem propoe novo aceite E2E a partir desta prova API.
