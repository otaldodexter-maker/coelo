---
title: "Métricas de progresso para revisões Flutter, Supabase e integradas"
source: "Solicitação do Owner; .agents/skills/coelo-flutter-review/SKILL.md; .agents/skills/coelo-supabase/SKILL.md; .agents/skills/coelo-flutter-supabase-review/SKILL.md; docs/reviews/coelo-flutter-pendencias.md; docs/reviews/coelo-supabase-pendencias.md; docs/reviews/coelo-flutter-integrado-supabase-pendencias.md"
status: "approved-design"
generated_at: "2026-09-01"
---

# Métricas de progresso para revisões Coelo

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
