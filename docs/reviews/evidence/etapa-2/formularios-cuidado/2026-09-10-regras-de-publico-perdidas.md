---
fonte: rodada noturna Etapa 2, grupo formularios-cuidado
status: pergunta aberta ao Owner, deliberadamente nao corrigida
data: 2026-09-10
---

# Salvar o agendamento apaga todas as regras de publico menos a primeira

## O que acontece

O dialogo de agendamento de Formularios monta a aplicacao com **exatamente uma**
regra de publico, reaproveitando apenas o id da primeira que ja existia:

```dart
audienceRules: [
  FormAudienceRule(
    id: previous?.audienceRules.firstOrNull?.id ?? _newScheduleRequestId(),
    kind: _audienceKind,
    mode: FormAudienceRuleMode.include,
    targetId: audienceId,
  ),
],
```

Do outro lado, salvar aplicacao **substitui o conjunto inteiro**: a funcao apaga
todas as regras da aplicacao e reinsere a partir do payload recebido.

```sql
delete from public.form_audience_rules where application_id = application_row.id;
...
insert into public.form_audience_rules(...)
```

Confirmado nas tres migrations que reescrevem essa funcao ao longo do tempo:
`20260813155121`, `20260820154638` e `20260825193120`. O comportamento e o mesmo
nas tres.

Somando as duas pontas: abrir o dialogo numa aplicacao que tenha mais de uma
regra de publico e salvar **apaga todas menos a primeira**, sem aviso, sem erro
e sem nada na tela indicando que existiam outras.

Os agendamentos, ao contrario, sao preservados (`schedules: previous?.schedules`).
A perda e especifica das regras de publico.

## Alcance, dito com precisao

O unico escritor de regras de publico no Superadmin e esse dialogo, e ele
escreve uma. Entao, por esta superficie, uma aplicacao nunca chega a ter duas. O
estado perigoso so existe se as regras vierem de carga inicial, de migration ou
de outro caminho de escrita.

Essa e a mesma distincao que esta rodada aprendeu a nao borrar: *o caminho
funciona quando o dado existe* nao e a mesma coisa que *o dado pode ser criado*.
Registrar isto como defeito ativo seria exagerar; registrar como "sem problema"
esconderia que a perda e silenciosa e irreversivel quando o dado existir.

## Por que nao foi corrigido

A correcao aparentemente obvia seria preservar as demais regras:

```dart
audienceRules: [regraEditada, ...?previous?.audienceRules.skip(1)],
```

Ela parece nao exigir decisao nenhuma, e exige.

Se o dialogo mostra "publico: X" e a aplicacao tem tres regras, preservar as
outras duas faz o formulario chegar a **mais gente do que a tela mostra**.
Trocar apagar em silencio por ampliar em silencio e escolher qual dos dois males
se prefere — e, tratando-se de quem recebe um formulario, isso e decisao de
produto e nao correcao de defeito.

Um formulario que alcanca familias ou responsaveis que o autor nao viu na tela e
consequencia de privacidade, nao detalhe de implementacao. Se tivesse sido
"corrigido" aqui, ninguem saberia que houve escolha.

## Pergunta ao Owner

Quando uma aplicacao tem varias regras de publico, o dialogo de agendamento
edita qual delas, e o que deve acontecer com as demais?

Tres respostas possiveis, todas defensaveis, nenhuma delas do executor: o
dialogo passa a listar e editar todas; edita a primeira e preserva as outras,
dizendo na tela que existem; ou continua substituindo tudo, mas avisa antes o
que sera removido.

## Limites do servidor nao espelhados no cliente

Na mesma varredura, tres limites que o servidor aplica nao existem em Dart em
lugar nenhum: **50 regras de publico**, **3 lembretes de agendamento** e **20
agendamentos ativos por aplicacao**, todos de
`20260820154638_forms_distribution_cardinality_limits.sql`.

Nenhum e violavel hoje pela interface. O dialogo cria uma regra e um agendamento
por aplicacao, e **lembrete nao tem nenhuma tela em Formularios que o
referencie**, embora exista no dominio e na API. Ficam como lacuna latente, e
nao foi escrito teste para eles porque, sem caminho que os alcance, a prova
seria teatro — o mesmo criterio da escolha unica inconstruivel.

O que esta espelhado concorda: `FormDefinitionLimits` com 20 secoes, 200 itens,
50 opcoes por item e 5 imagens bate com `20260813155005` e `20260813155121`.
