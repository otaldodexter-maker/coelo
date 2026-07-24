---
title: "Atividades Contextuais E Criacao Delegada Pela Unidade"
source: "conversa com usuario em 2026-07-23; docs/product/prd-master.md; docs/product/prd-admin.md; docs/data/data-model.md; docs/security/auth-multitenant-permissions.md; specs/014-atividade-contextual.md; packages/coelo_database/migrations/20260724120307_contextual_activities_foundation.sql"
status: "Accepted and implemented"
generated_at: "2026-07-24"
---

# Atividades Contextuais E Criacao Delegada Pela Unidade

## Contexto

A hierarquia institucional do Coelo usa instituicao, unidade e grupo/turma.
Algumas operacoes da turma, como Biologia, Capoeira, Musica ou uma oficina,
precisam de professores, conversas, presenca, eventos e publicacoes com
permissoes proprias, sem transformar a atividade em uma turma independente.

A mesma definicao de atividade pode ser usada em varias turmas da mesma
instituicao. Cada turma pode ter professores diferentes, inclusive mais de um
professor para a mesma atividade, e permissoes diferentes.

## Decisao

### Propriedade E Contexto

- `Atividade` e um dominio proprio e reutilizavel dentro de uma instituicao.
- A instituicao e sempre proprietaria da definicao da atividade.
- Toda atividade nasce vinculada a pelo menos uma unidade.
- A atividade so produz efeitos operacionais quando vinculada a um grupo/turma.
- Conversa, presenca, eventos e midia continuam pertencendo aos seus dominios;
  a atividade fornece o contexto e os vinculos de autorizacao.

### Criacao Pela Instituicao Ou Unidade

- A instituicao pode criar atividades diretamente.
- Uma unidade ou usuario com escopo de unidade pode criar atividade somente
  quando uma capacidade especifica estiver habilitada na gestao do perfil.
- Na criacao pela unidade, a instituicao-mae e derivada no servidor, nunca
  escolhida livremente pelo cliente.
- A unidade de origem e registrada e se torna o primeiro vinculo obrigatorio.
- A instituicao pode editar, ampliar vinculos, restringir, arquivar ou desativar
  qualquer atividade criada por uma unidade filha.
- Um ator restrito a unidade nao pode vincular a atividade a unidades irmas ou
  grupos fora do seu escopo sem permissao institucional adicional.

### Pessoas E Permissoes Por Turma

- Pessoas sao convidadas ou adicionadas a atividade no contexto da turma.
- A mesma atividade pode ter professores diferentes em turmas diferentes.
- A mesma atividade pode ter mais de um professor na mesma turma.
- Permissoes padrao podem vir da instituicao ou unidade e receber restricoes ou
  complementos no vinculo com a turma.
- A autorizacao efetiva considera pessoa, atividade, turma, unidade e
  instituicao e e validada no backend/RLS.

## Consequencias

- O banco precisa separar definicao da atividade, vinculos com unidades,
  vinculos com grupos e atribuicoes de pessoas por grupo.
- A criacao da definicao e do primeiro vinculo com unidade deve ocorrer em uma
  operacao transacional server-side.
- O registro deve preservar origem da criacao e ator para auditoria, sem
  transferir ownership da instituicao para a unidade.
- O menu do Superadmin e, depois, do Admin deve prever Atividades antes da tela
  final de gerenciamento.
- A implementacao segue a ordem: Supabase/Postgres e RLS, menu, depois telas.

## Materializacao Fisica

A decisao foi materializada em 2026-07-24 com tabelas normalizadas para definicao, unidades, turmas, atribuicoes, perfis, capacidades, overrides e sugestoes. A criacao institucional e a criacao delegada usam RPCs transacionais distintas; a RPC da unidade recebe apenas `origin_unit_id`, deriva a instituicao no servidor e exige `activities.create` naquele escopo.

O catalogo institucional separa `activities.read`, `activities.create`, `activities.manage`, `activities.link_units`, `activities.link_groups`, `activities.assign_people` e `activities.manage_permissions`. Grants de unidade continuam limitados ao `unit_id` ou `group_id` do grant. Operacoes entre unidades irmas exigem grant institucional adicional.

## Fora De Escopo Desta Decisao

- Definir o schema final de conversa, presenca, eventos ou midia.
- Definir a tela final de atividades.
- Definir quais papeis recebem cada capacidade por padrao.
