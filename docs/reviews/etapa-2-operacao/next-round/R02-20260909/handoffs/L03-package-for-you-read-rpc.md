---
title: "L03 - Pacote revisavel: RPC de leitura do Principal / Para Voce"
source: "E2 R02 L03 (worktree e2-r02-l03-perfil-para-voce); migrations de packages/coelo_database; codigo de apps/superadmin"
status: "proposto-nao-aplicado"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# L03 - Pacote revisavel: RPC de leitura do Principal / Para Voce

Recorte: `apps/superadmin -> menu Coelo (Principal) -> Perfil / Para Voce -> action_id
`principal.for-you`` (id confirmado em `escopo.json`, linha 1881 da rodada R02-20260909).

Este documento e um **pacote revisavel**, nao uma entrega aplicada. Nada foi executado
em Supabase. Nenhum commit ou push foi feito.

## 1. Achado de autorizacao

A tela "Para Voce" le comunicacoes atraves do repositorio administrativo do Superadmin:

- `apps/superadmin/lib/features/principal_for_you/presentation/principal_for_you_route_page.dart`
  recebe um `NoticeRepository` (linha 27) e chama `repository.fetchPage(...)` (linha 98).
- `apps/superadmin/lib/features/notices/data/supabase_notice_repository.dart` implementa
  `fetchPage` chamando a RPC `public.superadmin_notice_directory_v2` (linha 18).
- Essa RPC pertence ao dominio **interno do Superadmin**, definida em
  `packages/coelo_database/migrations/20260901185008_superadmin_internal_notices_v2.sql`
  (linha 403). Ela e guardada por
  `app_private.superadmin_notice_context('notices.read')`, ou seja, por permissao
  administrativa, e devolve o **diretorio inteiro** de `public.platform_notices`,
  filtrado apenas por busca, tipo, status e prioridade recebidos do cliente.
- A elegibilidade por audiencia e decidida no **cliente**, em
  `apps/superadmin/lib/features/principal_for_you/data/principal_for_you_communications_adapter.dart`
  (`isEligible`, `matchesAudience`, `_ruleGrants`).

Isso contraria a invariante do `AGENTS.md`: "Regra de negocio, ownership, tenant,
hierarquia e autorizacao sao validados no backend/RLS em toda leitura e escrita; o
frontend apenas solicita e renderiza." A filtragem que existe hoje no adapter e
**defesa em profundidade**, nao controle de acesso: o servidor ja entregou os dados
antes de qualquer decisao de audiencia.

Nao existe hoje nenhuma RPC nem tabela de leitura "para voce" voltada ao Principal.
`highlight`, `for_you` e `content_card` existem apenas como valores do enum
`public.notice_type` (`20260820204752_app_communications_types.sql` e
`20260901185008_superadmin_internal_notices_v2.sql`).

### Achado secundario (corrige uma hipotese do recorte)

`public.notice_rules` (definida em `20260623191021_superadmin_foundation_v1.sql`,
linha 481) **nao e populada por nenhuma migration do repositorio**: nao ha um unico
`insert into public.notice_rules`. A audiencia real e persistida em
`public.platform_notices.audience_json`, validada por
`app_private.validate_notice_audience` (`20260812003000_notices_production.sql`,
linha 133) e pelo validador equivalente do v2 (`20260901185008`, linhas 300-338).
Qualquer RPC de audiencia server-side precisa avaliar `audience_json`; `notice_rules`
so pode ser usada como exclusao defensiva.

## 2. Por que `principal.for-you` nao pode ser certificado E2E hoje

- O gate de audiencia roda no cliente. Um ator de outra instituicao, unidade ou turma
  recebe do servidor o payload de comunicacoes que nao lhe pertencem; apenas a
  renderizacao e suprimida. Isso e exatamente o padrao IDOR/BOLA que o `AGENTS.md`
  proibe.
- A leitura depende de permissao administrativa (`notices.read` no contexto interno do
  Superadmin). Um ator Principal real, sem esse contexto, receberia negacao. Ou seja, o
  caminho atual so funciona porque a tela esta hospedada dentro do Superadmin.
- Nao ha teste cross-tenant possivel contra o backend: nao existe superficie
  server-side que decida audiencia para poder ser testada.

Consequencia: a acao pode ser marcada como avanco local de Front-end, mas **nao** como
conclusao BE nem E2E. Nenhum "local-green" desta tela certifica a acao ponta a ponta.

## 3. O que este pacote propoe

Arquivo SQL da proposta:
`packages/coelo_database/plans/2026-09-09-principal-for-you-read-rpc.sql`

Funcao proposta: `public.list_my_principal_for_you(p_limit int default 50)`.

- `security definer`, `stable`, `set search_path = ''`,
  `revoke all ... from public, anon, authenticated`,
  `grant execute ... to authenticated` - mesmo padrao de
  `public.list_my_principal_contexts()`
  (`20260901161700_principal_runtime_contexts.sql`).
- Resolve o ator pelo mesmo caminho de `list_my_principal_contexts`: pessoa ativa
  ligada ao `auth.uid()` por `public.person_auth_links` ativo e nao revogado, com
  `public.institution_memberships` ativo e nao revogado, instituicao ativa, e escopo
  de unidade/turma resolvido.
- Devolve apenas `notice_type` em `('highlight','content_card','for_you')`. Nunca
  `popup`, `notice` ou `critical_notice`.
- Exige `status = 'active'`, `starts_at <= now()` e
  `ends_at is null or ends_at > now()`.
- Aplica no servidor os mesmos gates que hoje vivem no adapter Dart: papel via
  `audience_json.role_codes`, inclusao pela dimensao da regra
  (`platform`/`institution`/`unit`/`group`/`person`, com `select_all` ou `target_ids`),
  e exclusao por `excluded_ids` **vencendo** qualquer inclusao. Dimensao desconhecida
  nunca inclui (fail-closed).
- Exclusao defensiva adicional por `public.notice_rules` com `effect = 'exclude'`
  (hoje inerte, porque a tabela nao e escrita), sem qualquer inclusao por essa via.
- Ordena por prioridade (`urgent`, `important`, `routine`) e depois por
  `coalesce(starts_at, published_at, created_at)` desc, com desempate por `id`.

A funcao **nao substitui** as RPCs `_v2` do Superadmin. O diretorio administrativo
continua sendo `public.superadmin_notice_directory_v2`, com o guarda de permissao
interna. A proposta e forward-only e nao faz `drop` de nada.

### O que muda no cliente depois da aprovacao

1. Criar um repositorio de leitura do Principal (por exemplo
   `SupabasePrincipalForYouRepository`) que chame `list_my_principal_for_you` e
   devolva um modelo proprio do hub, sem os campos administrativos de popup
   (comportamento, cores, recorrencia, contadores de alcance).
2. Trocar a injecao em
   `apps/superadmin/lib/features/principal_for_you/presentation/principal_for_you_route_page.dart`
   e no wiring de `apps/superadmin/lib/app/superadmin_app.dart` /
   `apps/superadmin/lib/app/router/superadmin_router.dart`, para que a tela deixe de
   depender de `NoticeRepository`.
3. Manter `PrincipalForYouCommunicationsAdapter` como defesa em profundidade e como
   projecao visual, mas sem que ele continue sendo o unico gate.
4. `plan_ids` e `NoticeAudience.coeloTeam` seguem sem contrapartida no runtime do
   Principal; isso vira decisao explicita e nao suposicao do cliente.

## 4. Plano de verificacao

### Local (executavel sem autorizacao remota)

- Revisao de leitura do SQL contra as migrations citadas (feita neste pacote).
- Aplicacao em banco Postgres local descartavel com a base de migrations do repositorio
  e seeds sinteticos: dois tenants, duas unidades, duas turmas, atores com papeis
  distintos.
- Casos minimos: regra `platform` alcanca todos; regra `institution` de A nao alcanca
  ator de B; regra `unit`/`group` nao alcanca ator sem aquele escopo; `excluded_ids`
  derruba inclusao `platform`; `role_codes` preenchido bloqueia papel fora da lista;
  comunicacao `popup` nunca aparece; comunicacao fora de vigencia nunca aparece;
  `p_limit` fora de 1..100 falha.
- Testes Dart do adapter permanecem validos e passam a ser teste de defesa em
  profundidade, nao de autorizacao.

### Remota (NAO autorizada agora)

- Aplicacao nominal, forward-only, revisada e serializada por D00 no projeto Supabase
  de producao, seguida de reexecucao dos casos cross-tenant contra atores reais.

Nada disso foi executado. Este pacote nao afirma validacao contra banco algum.

## 5. Recuperacao e rollback

- Forward-only: a proposta apenas cria `public.list_my_principal_for_you`. Nao faz
  `drop`, `alter` nem `revoke` sobre objetos existentes.
- Rollback, se necessario, e um `revoke execute ... from authenticated` seguido de
  `drop function public.list_my_principal_for_you(int)` em uma migration forward-only
  propria, sem impacto sobre as RPCs `_v2` nem sobre `platform_notices`.
- Enquanto a funcao nao existir remotamente, o cliente continua no caminho atual: nada
  quebra, e a acao permanece nao certificavel E2E.

## 6. Pontos abertos (`CONFIRMAR` no SQL)

- **`plan_ids`**: `audience_json` aceita ate 50 planos, mas o vinculo do ator nao
  carrega plano. Falta confirmar a ligacao entre `institution_memberships` /
  `institutions` e `public.plans` / subscriptions. Decisao do Owner: `plan_ids`
  preenchido deve virar gate adicional fail-closed ou permanecer rotulo de audiencia?
- **`notice_rules.segment_id` / `public.audience_segments`**: nenhum comando do
  repositorio cria segmentos; `expression_json` nao e interpretado pela proposta.
- **`public.target_type` nao tem valor `person`**: exclusao por pessoa so existe em
  `audience_json.excluded_ids`.
- **Indices de `public.platform_notices`**: nao foram inventariados neste pacote; um
  indice de apoio para `(notice_type, status, starts_at)` deve ser avaliado antes de
  carga real.

## 7. O que NAO esta autorizado agora

- Aplicar qualquer coisa em Supabase remoto. Todo recurso Supabase do Coelo e
  producao; a aplicacao exige **autorizacao nominal do Owner** e serializacao por D00.
- Commit, push ou deploy deste pacote.
- Usar MCP ou CLI para mutar recurso remoto.
- Declarar `principal.for-you` concluida em BE ou E2E.

Quem decide: **Owner**, com serializacao e ordem de aplicacao por **D00**. L03 apenas
entrega o pacote revisavel e o achado.
