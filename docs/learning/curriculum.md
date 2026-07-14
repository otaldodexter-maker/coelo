---
title: "Curriculo do Tutor Coelo"
source: "docs/superpowers/specs/2026-07-14-coelo-tutor-design.md; AGENTS.md; arquitetura e codigo do Coelo"
status: "active-learning-path"
generated_at: "2026-07-14"
updated_at: "2026-07-14"
---

# Curriculo do Tutor Coelo

## Como usar esta trilha

A ordem reduz saltos para uma pessoa iniciante absoluta. Um desvio curto pode
explicar codigo atual, mas o tutor deve registrar como voltar. Conclusao exige
evidencia do usuario; exposicao ao tema nao basta.

## Fase 1 — Mapa do projeto

**Objetivo:** reconhecer onde o Superadmin vive e como o aplicativo comeca.

**Assuntos:** repositorio, pasta, arquivo, app, `apps/superadmin`, `lib`,
`test`, `pubspec.yaml`, `main.dart`, imports e caminhos.

**Evidencia:** localizar `main.dart`, explicar `lib` com palavras proprias e
descrever o caminho inicial do aplicativo.

**Por que primeiro:** sem o mapa, os exemplos posteriores parecem isolados.

## Fase 2 — Fundamentos de Dart

**Objetivo:** ler as construcoes basicas usadas pelo aplicativo.

**Assuntos:** valores, variaveis, tipos, funcoes, parametros, retorno, classes,
objetos, metodos, imports, `final`, `const`, colecoes, condicionais,
assincronicidade e null safety.

**Evidencia:** interpretar um trecho pequeno, identificar dados e funcoes e
fazer uma alteracao guiada.

**Por que agora:** Flutter e escrito em Dart.

## Fase 3 — Fundamentos de Flutter

**Objetivo:** entender como Flutter monta e atualiza uma interface.

**Assuntos:** widget, arvore de widgets, `runApp`, composicao, `BuildContext`,
`build`, `StatelessWidget`, `StatefulWidget`, estado e atualizacao.

**Evidencia:** seguir a arvore desde `SuperadminApp` e explicar por que uma
tela e composta por widgets menores.

**Por que agora:** usa Dart e prepara a leitura das features reais.

## Fase 4 — Estrutura do Superadmin

**Objetivo:** entender as fronteiras escolhidas pelo projeto.

**Assuntos:** `app`, `core`, `features`, `domain`, `data`, `presentation`,
`screens`, `widgets`, `view_models`, dependencias e componentizacao.

**Evidencia:** indicar onde uma regra, tela, widget local e integracao
pertencem, justificando cada escolha.

**Por que agora:** depois de ler widgets, faz sentido estudar sua organizacao.

## Fase 5 — Interface e comportamento

**Objetivo:** relacionar codigo visual, interacao e qualidade.

**Assuntos:** layout, constraints, tema, tokens, responsividade, formularios,
validacao, navegacao, estado, assincronicidade, erros, acessibilidade e testes.

**Evidencia:** acompanhar o login e explicar como estado, widgets e testes se
conectam.

**Por que agora:** aplica os fundamentos em uma feature completa.

## Fase 6 — Dados e backend

**Objetivo:** diferenciar aplicativo cliente e servicos do servidor.

**Assuntos:** cliente, servidor, API, HTTP, JSON, request, response,
autenticacao, autorizacao, sessao, logs e falhas.

**Evidencia:** descrever uma acao ate o servidor e por que o cliente nao
decide sozinho permissoes.

**Por que agora:** cria o modelo mental necessario antes do banco.

## Fase 7 — SQL e PostgreSQL

**Objetivo:** compreender dados relacionais e consultas.

**Assuntos:** banco, schema, tabela, linha, coluna, tipos, chaves, `SELECT`,
`INSERT`, `UPDATE`, `DELETE`, filtros, joins, constraints, indices, transacoes
e migrations.

**Evidencia:** ler consultas simples, modelar relacionamento ficticio e
explicar os riscos de alterar dados.

**Por que agora:** Supabase usa PostgreSQL; o banco nao deve parecer magia.

## Fase 8 — Supabase no Coelo

**Objetivo:** entender Supabase na arquitetura segura e multi-tenant.

**Assuntos:** Auth, Database, migrations, RLS, policies, RPCs, Edge Functions,
Realtime, Storage versus R2, `tenant_id`, memberships, auditoria e segredos.

**Evidencia:** explicar fluxo autenticado, escrever policy didatica com dados
ficticios e identificar o que nunca vai para o cliente.

**Por que por ultimo:** combina interface, backend, banco e seguranca.
