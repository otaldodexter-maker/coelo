---
title: "Métricas de progresso para revisões Flutter, Supabase e integradas"
source: "Solicitação do Owner; .agents/skills/coelo-flutter-review/SKILL.md; .agents/skills/coelo-supabase/SKILL.md; .agents/skills/coelo-flutter-supabase-review/SKILL.md; docs/reviews/coelo-flutter-pendencias.md; docs/reviews/coelo-supabase-pendencias.md; docs/reviews/coelo-flutter-integrado-supabase-pendencias.md"
status: "approved-design"
generated_at: "2026-09-01"
updated_at: "2026-09-09"
---

# Métricas de progresso para revisões Coelo

## Contrato vigente — Etapa 2, 09/09/2026

Fonte adicional: pedido do Owner em 09/09 para ajustar as três skills, explicitar
Etapa 2 por tela/subtela, medir avanço ponta a ponta e testes aprovados/falhos.
O reforço do mesmo pedido define a invocação para trabalhar no projeto como
resolução efetiva de pendências: corrigir/testar/fechar aceites, seguindo o
[ciclo de resolução](../../../.agents/skills/coelo-flutter-supabase-review/references/review-scope.md#ciclo-de-resolução-de-pendências).
Planejamento, métricas e documentação apoiam a execução; não a substituem.
Este aditivo substitui os formatos e denominadores históricos abaixo. Preserva
avanço local, conclusão estrita e gates separados, sem pesos de maturidade.

### Unidade e escopo

- Identidade obrigatória: `Etapa 2 / apps/superadmin / menu / tela / subtela ou
  estado / action_id`. Coelo (Principal) é menu desse app. Outros apps ficam
  fora. Backend informa também pacote e provedores das ações consumidoras.
- Fonte operacional: `docs/reviews/inventario-etapa-2.json` cruzado com as três
  matrizes. Campos `historicalFrontend`/`historicalBackend` não são provas atuais.
  Registrar revisão do inventário, revisão do código/contrato, ambiente e data.
- Medir ações únicas aplicáveis à camada no escopo declarado. Não somar ações,
  famílias, gates ou testes. Tela agrega os IDs de suas subtelas; geral agrega
  a união dos IDs, nunca a média simples dos percentuais de telas.
- Separar `mvp`, `gate-formal-mvp`, `deferred-post-mvp` e `flutter-only`.
  `account.settings`/`account.theme` também são apenas cliente no contrato atual.
  O E2E ativo exclui ações sem backend, gates formais e operações adiadas.
  `forms.responses.export` permanece no MVP. UI honesta das ações adiadas
  continua um aceite Front-end, sem certificar a operação real.
- Inventário conhecido não prova cobertura integral do app. Tela/subtela sem
  mapeamento (como a lacuna de Circulares registrada em 08/09) fica explícita
  como `não mapeada`, com próximo passo e fonte; não desaparece do relatório
  nem recebe IDs, denominador ou conclusão inventados. Expansão/reclassificação
  aprovada registra IDs antes/depois e recalcula a base, sem apagar o histórico.

### Avanço por camada e ponta a ponta

Para cada tela/subtela e para o recorte, `C` é o número de `action_id` com todos
os aceites da camada comprovados e `N` é o número de IDs aplicáveis:

- conclusão = `100 × C/N`; restante = `100 × (N-C)/N`;
- Front-end conta `verified`; Backend conta `done`; E2E conta `verified-e2e`;
- `ready-for-e2e` exige FE e BE concluídos **no mesmo ID**, não apenas totais iguais;
- `N=0` conhecido: `não aplicável`, sem 0%/100%; base desconhecida: `não calculável`;
- apresentar duas casas decimais e sempre `C/N`. E2E certificado é percentual
  de aceites fechados, não percentual de código escrito nem esforço restante.

Mostrar junto o avanço local comprovado: FE `local-green`/`verified`; BE
`local-green`/`remote-green`/`done`, com evidência válida e denominador da camada.
Quando só há classificação histórica, informar o histórico datado e o trabalho
preservado, sem reaproveitar o número como medição atual. Avanço dentro de uma
ação aparece como aceites fechados e delta qualitativo, sem percentuais arbitrários.
Uma espera de backend não apaga um certificado FE ainda válido.

### Testes: resultado e cobertura do plano

Cada campanha declara `campaign_id`, camada (FE, BE ou E2E), revisão alvo,
ambiente, versões/invocação do runner, início/fim e referência de evidência.
Cada caso tem `test_id` estável, `action_ids`, variante/ambiente quando pertinente,
resultado e evidência. Critérios manuais e automatizados são identificados;
um comando verde/analyzer/build não vira uma quantidade de casos de teste.

Usar estados exclusivos para o resultado mais recente válido de cada caso:

| Símbolo | Estado | Regra |
|---|---|---|
| P | aprovado | Caso concluiu com o resultado esperado, inclusive uma negativa de segurança. |
| F | falho | Caso executado encontrou falha, inclusive erro atribuível ao produto. |
| B | bloqueado | Não pôde concluir por ambiente, dependência ou decisão; indicar causa. |
| S | ignorado | Skip explícito; continua dívida do plano obrigatório. |
| U | não executado | Caso planejado sem resultado válido para a revisão alvo. |

`N = P+F+B+S+U` é o plano obrigatório conhecido. `E = P+F` são os casos
executados com resultado conclusivo. Publicar juntos:

- **aprovados dos executados:** `100 × P/E`;
- **falhos dos executados:** `100 × F/E`;
- **execução do plano:** `100 × E/N`;
- **plano aprovado:** `100 × P/N`, mais contagens B, S e U.

Se `E=0`, taxas de aprovação/falha são `não calculáveis (nenhum caso conclusivo)`.
Se N não é conhecido, relatar os resultados da execução identificada e marcar
cobertura do plano desconhecida. Não afirmar 100% dos testes do app com uma suíte
parcial. Zero casos descobertos exige investigar a invocação; não é PASS.
Erro do runner fica registrado à parte, sem inventar falhas do produto.

Exemplo sintético: P=8, F=2, B=1, S=3, U=6 → N=20, E=10.
Aprovados: 80,00% (8/10); falhos: 20,00% (2/10); execução: 50,00% (10/20);
plano aprovado: 40,00% (8/20). Uma negativa esperada que passou pertence a P.

Não somar execuções repetidas, asserts pgTAP a casos Flutter, ou suítes
sobrepostas. Agregar apenas casos únicos da mesma campanha/camada e base
comparável; mostrar suítes heterogêneas separadamente. Caso ligado a várias
ações aparece nelas, mas conta uma vez no geral. Rerun substitui o resultado
do mesmo caso na mesma base, preservando tentativas/falhas anteriores e flakiness;
PASS eventual não encerra um problema intermitente conhecido.

Mudança de código, schema, configuração ou runner exige análise de impacto.
Reutilizar evidência só com compatibilidade justificada e registrada; reexecutar
os casos afetados. Sem justificativa, resultados antigos ficam históricos e os
casos da revisão alvo ficam U. Não somar 8 PASS antigos a 1 PASS de outra revisão.
Isso não obriga reexecutar toda a suíte para uma alteração documental sem impacto.
O plano de casos também deve ser conferido: conservar N entre revisões somente
quando os mesmos casos continuam obrigatórios; alteração de escopo registra a
nova base antes da comparação. Base do plano desconhecida não recebe percentual.

### Painel e execução orientados à entrega

No início, checkpoint e encerramento de trabalho de entrega, informar etapa,
app, menu e recorte. Na tabela, uma linha por tela/subtela trabalhada com IDs,
FE `C/N`, BE `C/N`, E2E `C/N`, testes P/E e F/E, E/N e P/N, primeiro gate aberto,
próxima ação, responsável e evidência. B/S/U aparecem por campanha. Mostrar o
geral conhecido em separado, com data; não ampliar uma correção localizada para
auditoria global apenas para preencher campos. Se o painel completo já existe,
publicar o delta e seu link mantendo visível a subtela atual e o limite da prova.

Classificar a causa do atraso: implementação faltante, verificação faltante,
integração de código, pacote/ambiente ou decisão. Apontar evidência, o que falta
exatamente e qual ação remove o impedimento. Priorizar o primeiro gate da
subtela selecionada e as dependências que ela usa; reaproveitar código e provas
válidas. Bloqueio externo retém só o dependente. Não iniciar auditoria novamente
em cada retomada. Tempo usado é medido; ETA separa trabalho ativo e espera,
sem regra de três pelo percentual nem promessa baseada em contagem de ações.

Ao certificar uma camada, atualizar no mesmo turno o inventário e as matrizes
afetadas, preservando feitos e histórico. Registrar `certifications.frontend`,
`.backend` ou `.integrated` no ID: `evidence` (arquivo relativo à raiz do repo),
`revision`, `environment` e `recordedAt` (ISO 8601). O manifesto deve comprovar
os gates da camada; metadados completos sozinhos não certificam comportamento.
Executar `rtk proxy node docs/reviews/validate-trackers.cjs`. O validador confere
consistência, não autoriza produção. `reconcile-trackers.cjs` permanece migração
histórica de uso único; não reexecutar para zerar evidências posteriores.

## Histórico do desenho de 01/09 — formatos substituídos pelo aditivo acima

## Problema

As três skills de revisão permitem apresentar como “progresso geral” apenas a
taxa binária do estado terminal (`verified`, `done` ou E2E). Isso produz uma
manchete de 0% mesmo quando existem ações, famílias e gates comprovadamente
verdes em estágios anteriores. Somar ações, famílias e gates no mesmo
denominador também mistura unidades incompatíveis e pode apagar progresso real.

## Objetivo

Fazer as três skills comunicarem progresso acumulado sem promover trabalho
parcial a conclusão integral. O usuário deve enxergar primeiro o avanço do
estágio de trabalho relevante e, separadamente, a taxa estrita de fechamento.

## Regra comum

1. Nunca chamar `verified`, `done` ou E2E de “progresso geral” sem qualificar o
   estágio quando houver evidência válida em estados anteriores.
2. Não somar `action_id`, famílias e gates de conceito no mesmo denominador.
   Cada percentual usa unidades homogêneas e informa sua base.
3. O restante é sempre o complemento da mesma métrica e do mesmo denominador.
4. Não atribuir pesos arbitrários a estados. Quando um trabalho aprofunda a
   evidência sem mudar de estado, registrá-lo como progresso qualitativo
   comprovado, com as provas executadas.
5. Se documentos divergirem, usar a matriz reconciliada mais recente e
   autoritativa, declarar a divergência e não inventar denominador.
6. Gates transversais são apresentados como cobertura separada; não aumentam o
   denominador de ações ou famílias.

## Métricas por skill

### Flutter

A manchete obrigatória é `Progresso geral Flutter local`, calculada sobre os
`action_id` da matriz Flutter. Contam como verdes localmente `local-green` e
`verified`. Em seguida, informar separadamente:

- distribuição dos demais estados;
- `Flutter verified`;
- cobertura dos gates FLU-GEN;
- integração/E2E somente como limite fora do recorte Flutter.

Exemplo atual: `102/207 = 49,28% Flutter local`; `0/207 verified = 0,00%`.

### Supabase

A manchete obrigatória é `Progresso geral Supabase local`, calculada sobre as
famílias da matriz consolidada quando esse for o denominador autoritativo.
Contam como verdes localmente `local-green`, `remote-green` e `done`. Em seguida,
informar separadamente:

- inventário/classificação;
- distribuição das famílias por estado;
- validação `remote-green`;
- fechamento `done`;
- gates SUP-GEN como cobertura separada;
- contagem por ação apenas quando a matriz de ações estiver reconciliada.

Trabalho adicional dentro de uma família já `local-green` deve aparecer como
progresso qualitativo comprovado, mesmo que o percentual de famílias não mude.

### Flutter + Supabase

Não existe um percentual composto único. A abertura apresenta um painel em
camadas, sem fundir denominadores:

1. Flutter local por `action_id`;
2. Supabase local por família ou unidade autoritativa do rastreador;
3. integração E2E por operação integrada;
4. conclusão estrita do projeto;
5. gates transversais por rastreador, separadamente.

A manchete deve ser `Progresso geral conhecido — visão em camadas`, nunca um
0% único que silencie trabalho Flutter ou Supabase já comprovado.

## Formato obrigatório

Cada skill deve oferecer um exemplo próprio com duas casas decimais:

```text
Progresso geral <estágio> — Concluído: 49,28% (102/207 unidades homogêneas)
Progresso geral <estágio> — Restante: 50,72% (105/207 unidades homogêneas)
Conclusão estrita <estado terminal>: 0,00% (0/207)
Gates transversais: 0/12 concluídos; distribuição por estado ...
Progresso qualitativo comprovado desde o checkpoint anterior: ...
Base do cálculo: matriz autoritativa, estados incluídos, HEAD e horário.
```

Tempo usado continua sendo apenas duração medida. ETA não pode ser deduzido do
percentual nem receber falsa precisão.

## Testes de regressão

Criar um teste determinístico das três skills que falhe quando:

- `Progresso geral` voltar a usar somente `verified`, `done` ou E2E;
- ações, famílias e gates forem autorizados no mesmo denominador;
- o restante não for o complemento da mesma métrica;
- a visão integrada voltar a exigir um percentual composto único;
- os exemplos omitirem a métrica local e a conclusão estrita separadas.

O incidente real nas conversas Flutter e Supabase é a evidência RED anterior à
mudança. Depois do GREEN estático, a conversa
`01a05d08-e2cb-7103-bbc1-89860afe5d28` deve receber a regra corrigida e um
exemplo Supabase, preservando seu histórico sem reescrevê-lo.

## Fora de escopo

- alterar estados ou percentuais dos rastreadores;
- inventar pesos de maturidade;
- promover ações, famílias, backend remoto ou E2E;
- alterar código Flutter, banco, migrations ou ambiente remoto;
- reinterpretar evidências históricas como novas execuções.

## Critérios de aceite

- as três skills adotam a regra comum e sua métrica específica;
- os testes de regressão falham antes e passam depois da edição;
- percentuais usam duas casas e denominadores homogêneos;
- `0%` estrito permanece visível, mas nunca apaga o progresso local;
- a conversa de destino recebe a orientação após a validação;
- os gates de conhecimento e `git diff --check` passam.

## Complemento de 11/09/2026 — como apresentar `local-green` (decisão do Owner)

`local-green` é estado intermediário: a ação sai dele ao virar `verified`
(Front-end) ou `done` (Back-end), então o numerador cai quando o trabalho
fecha. Para não parecer regressão, a linha de `local-green` no fechamento é
apresentada sobre o que ainda falta, e não sobre o total: Front-end
`local-green / ações ainda não verified` e Back-end
`local-green / ações ainda não done`, com o denominador escrito na própria
linha. As linhas de acumulado (`verified`, SQL em produção, `done`, E2E,
aprovação visual) continuam sobre os denominadores homogêneos (231/224/199).
