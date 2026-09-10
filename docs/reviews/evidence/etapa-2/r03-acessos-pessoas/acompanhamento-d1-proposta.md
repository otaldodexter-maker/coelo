---
title: "D1 - modelo de acompanhamento: proposta de contrato"
source: "Decisao D1 do Owner em 10/09/2026 (ADR 0034, Decisao 6); schema real de producao lido em 10/09/2026"
status: "proposal-awaiting-agreement"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
author: "Rodada 3, grupo acessos-pessoas"
audience: "coordenacao e grupo principal-chat-sistema"
---

# Acompanhamento automatico da hierarquia (D1)

## O que a decisao pede

O Owner fechou em 10/09/2026: ao cadastrar uma crianca em unidade, turma e
demais niveis, **ela e seus responsaveis passam a acompanhar automaticamente
toda a hierarquia acima, inclusive a instituicao**. O Perfil do Principal
mantem a referencia aprovada com **Acompanhar**, **Seguidores** e **Seguindo**,
e precisa de fonte de dados real por tras dessas secoes.

Isso tem dois donos: eu modelo no backend, `principal-chat-sistema` consome no
Perfil. Esta nota existe para fecharmos **um** contrato antes de qualquer um dos
dois escrever codigo, e nao dois modelos diferentes.

## Ponto de partida: nao existe nada

Varri as 186 migrations por `follow`, `following`, `follower`, `acompanh`,
`subscription`, `watch` e `tracking`. **Nao existe tabela, view ou funcao de
acompanhamento.** `institution_subscriptions` e plano comercial;
`student_tracking` e avaliacao pedagogica. Os unicos hits de `follow` sao
`lead(...) as following_id`, cursor de paginacao em Circulares.

O que existe e reusavel sao os vinculos **estruturais**, todos ja em producao:

| Tabela | Liga |
| --- | --- |
| `public.child_contexts` | crianca -> instituicao |
| `public.child_unit_links` | contexto da crianca -> unidade |
| `public.child_group_links` | link de unidade -> turma |
| `public.guardian_links` | responsavel -> crianca |
| `public.guardian_context_permissions` | responsavel -> contexto, com `can_view`, `starts_at`, `expires_at` |
| `public.institution_memberships` / `institution_role_assignments` | adulto -> instituicao/unidade/grupo com papel |

## A pergunta que decide o modelo

**Acompanhamento e derivado da estrutura ou e um fato proprio?**

Se fosse so derivado, uma view resolveria e nao haveria o que decidir. Mas a
referencia aprovada tem um botao **Acompanhar**, e um botao e uma escrita. Um
acompanhamento manual precisa sobreviver a mudancas de estrutura, e um
acompanhamento automatico precisa sumir quando a estrutura que o gerou some.
Os dois nao cabem numa view.

Por isso a proposta e **uma tabela materializada com procedencia**, nao uma view
e nao uma tabela solta.

## Proposta

```
public.follow_links
  id                        uuid pk
  follower_person_id        uuid -> public.people(id)
  target_kind               enum: institution | unit | group | person
  target_id                 uuid
  origin                    enum: automatic | manual
  source_child_context_id   uuid null -> public.child_contexts(id)
  source_relationship       enum null: self | guardian
  status                    public.record_status
  created_at, updated_at, revoked_at
```

Regras:

1. **Uma linha por (follower, target, origin, source).** Indice unico parcial
   com `where status = 'active'`. Automatico e manual coexistem na mesma dupla
   follower/target sem se anular; e isso que faz o manual sobreviver a saida da
   crianca da turma.
2. **`origin = 'automatic'` nasce por trigger** nas insercoes de
   `child_contexts`, `child_unit_links` e `child_group_links`. Para cada
   insercao, gera as linhas da crianca e as de cada responsavel com
   `guardian_links` ativo, cobrindo toda a cadeia ate a instituicao. O
   `source_child_context_id` grava **qual** vinculo causou.
3. **Revogacao e por procedencia.** Ao revogar um vinculo estrutural, revogam-se
   somente as linhas automaticas cujo `source_child_context_id` e aquele. Se
   sobrar outra fonte ativa para a mesma dupla (irmao na mesma unidade, por
   exemplo), a linha daquela outra fonte permanece. Linha manual nunca e
   revogada por mudanca de estrutura.
4. **`origin = 'manual'` nasce e morre pelo botao Acompanhar**, por RPC, com
   autorizacao propria.
5. **Consultas do Perfil**: `Seguindo` de uma pessoa sao as linhas ativas com
   `follower_person_id` = ela; `Seguidores` de um alvo sao as linhas ativas com
   `target_kind`/`target_id` = ele. Ambas com cursor, no padrao das demais
   listagens.

## Seguranca

- RLS deny-by-default, sem policy de INSERT, UPDATE ou DELETE. Toda escrita
  passa por `security definer`, como ja e o padrao do dominio de pessoas.
- A policy de SELECT precisa correlacionar a permissao com **a linha exata**.
  Nao repetir o defeito que `20260729153000_superadmin_people_directory_policy_hardening.sql`
  teve de corrigir, em que a permissao de guardiao nao se correlacionava com a
  linha selecionada e vazava entre contextos.
- `Seguidores` de uma instituicao expoe uma lista de pessoas, incluindo
  criancas. **Isso e dado pessoal de crianca.** A leitura precisa de capacidade
  explicita e minimizacao: nome de exibicao e tipo, nunca identificadores. Sugiro
  que, para alvo `institution`, `unit` e `group`, a contagem seja publica ao
  contexto e a **lista** exija capacidade; e que criancas nao aparecam em lista
  de seguidores para ator sem vinculo com elas.
- Trigger que escreve em massa precisa de limite: uma turma com muitas criancas
  gera muitas linhas por insercao. Fazer em `statement`-level com insercao em
  conjunto, nao `row`-level com laco.

## O que preciso combinar com principal-chat-sistema

1. **O botao Acompanhar cria linha manual em qual alvo?** So instituicao/unidade/
   turma, ou tambem pessoa -> pessoa? A referencia aprovada mostra Seguidores e
   Seguindo num Perfil de pessoa, o que sugere pessoa -> pessoa. Preciso da
   confirmacao para dimensionar `target_kind`.
2. **Seguidores e Seguindo mostram contagem, lista, ou as duas?** Muda se a RPC
   devolve agregado barato ou pagina completa.
3. **O automatico aparece na lista de Seguindo do usuario?** Se aparecer, ele ve
   que segue a instituicao sem ter clicado. Se nao aparecer, o numero de
   Seguindo nao bate com o que o backend guarda. Recomendo aparecer, com o
   automatico distinguivel, mas quem decide a leitura da tela e o grupo do
   Perfil.
4. **Quem consome primeiro?** Se o Perfil precisa da leitura antes do meu
   pacote de escrita ficar pronto, entrego a RPC de leitura sobre a derivacao
   dos vinculos existentes e materializo depois, sem mudar a assinatura.

## Encaminhamento

Nao vou escrever a migration antes de fechar os quatro pontos acima com
`principal-chat-sistema`, via coordenador. Escrever agora seria arriscar dois
modelos incompativeis, que e exatamente o retrabalho que a Rodada 3 se propos a
eliminar. Os pontos 1 e 2 podem precisar do Owner; se precisarem, vao em lote com
as demais duvidas, com referencia visual da tela de Perfil.
