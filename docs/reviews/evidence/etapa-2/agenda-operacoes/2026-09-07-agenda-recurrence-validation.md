---
title: "Agenda — validação defensiva da recorrência recebida"
source: "specs/050-superadmin-agenda-backend.md; specs/006-comunicacao-agenda.md; testes locais e review E2E5"
status: "local-green; validação backend e E2E pendentes"
generated_at: "2026-09-07"
---

# Recorte

Agenda / leitura de séries no Calendário e detalhe; Superadmin somente.
Passo 3/6 cliente e 5–6/6 teste/review desta fatia. Nenhum BD executado: respostas
HTTP simuladas de `public.superadmin_agenda_list`. Writer root; review
read-only `activities_contract_read`. Sem alteração de modelo, UX, lifecycle,
fuso institucional, algoritmo de expansão, SQL ou limits máximos de produto.

## Evidência

Oito REDs confirmaram que intervalos/contagens não positivos disparavam asserts,
e que tipos inválidos, término inválido acompanhado de quantidade e exceções
não-array eram aceitos. Em release, intervalo zero poderia não avançar o loop.
Os testes RED não expandiram dados inválidos, evitando bloquear o runner.

O parser agora exige número JSON inteiro positivo, default de intervalo 1
somente quando ausente, exatamente um término válido e coleção de datas de
exceção válida. Erros são `FormatException`, preservando snapshot anterior e
falha controlada. O serializer atual já emite número JSON e array; string
numérica ou `exceptions:null` não são aceitos como equivalentes.

Controles positivos cobrem daily/weekly/monthly, default/quantidade e
intervalo/término explícitos. A conversão histórica de `until` para local e a
representação original das exceções são preservadas; não altera semântica de
dia civil por conveniência. `DateTime.tryParse` continua aceitando algumas
datas normalizadas; este parser não declara validação completa de calendário.

Regressão funcional Agenda final: 96/96 verdes, incluindo 30 testes do repository.
Analyzer dos dois arquivos sem problemas. Review independente sem bloqueio;
observação de conversão de exceções resolvida preservando o comportamento
anterior e acrescentando controle positivo explícito de timezone.

## Gates abertos

A migration existente valida recorrência como objeto JSON, não todos esses
campos. Esta correção no cliente não substitui constraints/RPC, autorização,
segurança ou prova de persistência real. Hierarquia de contextos, estados de
UI e demais gates da Agenda permanecem separados. Nenhum `verified`, `done`
ou `verified-e2e` novo.

Memória no-op: nenhuma nova decisão de produto ou limite aprovado.
