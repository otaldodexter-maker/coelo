---
title: "Proposta de mapeamento de Circulares para o inventário da Etapa 2"
source: "specs/037-principal-circulars.md; specs/050-principal-ui-ux-closure.md; decisions/0027-circulars-private-supabase-storage-and-versioned-feed.md; decisions/0032-mvp-private-media-r2.md; docs/reviews/etapa-2-operacao/next-round/R02-20260909/escopo.json; packages/coelo_database/migrations/20260821190000_circulars_production.sql; packages/coelo_database/migrations/20260901191921_superadmin_internal_circulars_v2.sql; código observado em apps/superadmin em 2026-09-09"
status: "proposta-para-reconciliacao-d00"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Circulares — proposta de mapeamento de `action_id` (L01 → D00)

## Objetivo

`escopo.json` da rodada E2-R02-20260909 registra, em `coverageGaps`, que
Circulares tem "diretório, criação/publicação, detalhe e edição sem IDs próprios
suficientes" e que hoje apenas `principal.profile-view` cobre a projeção no
Perfil. Este documento é a **proposta** de L01 para fechar essa lacuna: nomes de
`action_id` no padrão já vigente, ancorados em superfícies reais observadas no
código e na spec037, com evidência linha a linha e separação explícita entre o
que foi **observado** e o que é **proposto**.

## O que esta proposta NÃO faz

- Não altera `escopo.json`, `registro.json`, `handoffs/**`, `assignments/**` nem
  os rastreadores em `docs/reviews/*.md`. Nenhum desses arquivos pertence a L01.
- Não cria IDs no inventário. Só D00 reconcilia e publica.
- Não certifica nenhuma tela, ação ou integração. Todos os itens observados
  permanecem `pending-verification` até prova própria.
- Não fecha o denominador do recorte L01 sozinha. Enquanto D00 não reconciliar,
  o denominador de Circulares continua **aberto**.
- Não esconde Circulares dentro de `principal.profile-view` e não remove ações
  do escopo para facilitar percentual.
- Não decide a questão de mídia (Supabase Storage × R2). Registra a divergência.

## Padrão de nomeação adotado

Lido diretamente de `escopo.json` (219 registros). O padrão observado é
`<familia>.<acao>`, com `family` em `snake_case` e o sufixo do `id` em
`kebab-case` quando composto. Exemplos observados:
`institutions.list`, `institutions.filter`, `institutions.access-denied`,
`units.copy-institution-location`, `notices.schedule`, `notices.publish`,
`assessments.close`, `access-profiles.delete`, `forms.respond`,
`chat.attach`, `acontece.feed`, `momentos.remove`, `daily-routine.publish`.

A família proposta para Circulares é `circulars` (mesma palavra já usada pelo
código de permissões: `circulars.circulars.*` na migration, e pelo diretório de
rotas `/circulars`). O campo `screen` segue o formato `Circulares / <sufixo>` ou
`Criar/Editar Circular`, como em `institutions` e `notices`.

## Tabela de mapeamento proposto

Todos os `action_id` abaixo são **propostos** — nenhum existe hoje em
`escopo.json`. As colunas FE/BE descrevem o que foi **observado** no checkout
`C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-l01-publicacoes` em 2026-09-09.
Caminhos são relativos à raiz do repositório.

Aviso de baseline: a worktree tinha alterações não commitadas de outros
trabalhos de L01 no momento da leitura (`git status --short` em 2026-09-09, com
`principal_happens_preview_page.dart`, `production_circular_hosts.dart`,
`circular_media_upload_coordinator.dart`,
`supabase_circular_auxiliary_repositories.dart` e
`principal_circular_reader.dart` entre os modificados). Os números de linha
citados são do **working tree** nessa data, não de um commit. D00 deve
reconferir contra o SHA que consolidar.

| # | Tela | Subtela/estado | `action_id` proposto | Origem na spec037 | Rota real observada | FE observado | BE observado | Evidência (arquivo:linha) | Observado ou Proposto |
| - | ---- | -------------- | -------------------- | ----------------- | ------------------- | ------------ | ------------ | ------------------------- | --------------------- |
| 1 | Circulares / Diretório | Lista, tabela desktop, cards compacto, paginação | `circulars.list` | §UX e estados, l.78-83 | `/circulars` (prod) e `/dev/circulars` | Página existe e é montada em produção | RPC `superadmin_circular_directory_v2` | `apps/superadmin/lib/app/router/superadmin_routes.dart:152-153`; `apps/superadmin/lib/app/router/superadmin_router.dart:4366-4382`; `apps/superadmin/lib/features/circulars/presentation/circular_directory_page.dart:59-80,344-403`; `apps/superadmin/lib/features/circulars/data/supabase_superadmin_circular_repository.dart:19`; `packages/coelo_database/migrations/20260901191921_superadmin_internal_circulars_v2.sql:254,580` | Observado |
| 2 | Circulares / Tabs, busca e filtro de contexto | `Todas / Rascunhos / Agendadas / Publicadas / Encerradas`, busca, filtro `Todos` | `circulars.filter` | §UX e estados, l.81-83 | mesma rota do item 1 | Enum de tabs e busca implementados | `superadmin_circular_directory_v2` aceita `search` e `statuses` | `apps/superadmin/lib/features/circulars/presentation/circular_directory_page.dart:12-29,139-146,274`; `apps/superadmin/lib/features/circulars/domain/superadmin_circular_repository.dart:7-22`; `apps/superadmin/lib/features/circulars/data/supabase_superadmin_circular_repository.dart:19-35` | Observado |
| 3 | Criar Circular | Composer: título, blocos de texto/mídia/pergunta, rascunho | `circulars.create` | §Escopo, l.19-24; §UX, l.98-105 | `/circulars/new` | `SuperadminCircularComposerPage` montada via `ProductionCircularComposerHost` | RPCs `superadmin_circular_load_draft_v2` e `superadmin_circular_save_draft_v2`; capacidade `circulars.circulars.create` | `apps/superadmin/lib/app/router/superadmin_routes.dart:154-155`; `apps/superadmin/lib/app/router/superadmin_router.dart:4384-4398`; `apps/superadmin/lib/features/circulars/presentation/superadmin_circular_composer_page.dart:1-120`; `apps/superadmin/lib/features/circulars/data/supabase_superadmin_circular_repository.dart:37,53`; `packages/coelo_database/migrations/20260901191921_superadmin_internal_circulars_v2.sql:313,355`; `packages/coelo_database/migrations/20260821190000_circulars_production.sql:253` | Observado |
| 4 | Editar Circular | Correção que cria nova revisão | `circulars.edit` | §Escopo, l.25-26; §Domínio, l.34-38 | `/circulars/:circularId/edit` | Rota montada, reaproveita o mesmo composer com `circularId` | `superadmin_circular_save_draft_v2` (mesmo RPC do rascunho). **Sem RPC específico de nova revisão publicada** no gateway v2 | `apps/superadmin/lib/app/router/superadmin_routes.dart:158-159`; `apps/superadmin/lib/app/router/superadmin_router.dart:4422-4446`; `apps/superadmin/lib/features/circulars/presentation/production_circular_hosts.dart:220-231`; `packages/coelo_database/migrations/20260901191921_superadmin_internal_circulars_v2.sql:355` | Observado |
| 5 | Circular / Detalhe | Leitor com conteúdo, contexto e resumo de respostas | `circulars.detail` | §Escopo, l.27; §UX, l.86-96 | `/circulars/:circularId/read` | `SuperadminCircularDetailPage`, com ação `Editar circular` | RPCs `superadmin_circular_detail_v2` e `superadmin_circular_response_summary_v2` | `apps/superadmin/lib/app/router/superadmin_routes.dart:156-157`; `apps/superadmin/lib/app/router/superadmin_router.dart:4400-4420`; `apps/superadmin/lib/features/circulars/presentation/superadmin_circular_detail_page.dart:9-24,113-118`; `apps/superadmin/lib/features/circulars/data/supabase_superadmin_circular_repository.dart:126,131`; `packages/coelo_database/migrations/20260901191921_superadmin_internal_circulars_v2.sql:333,548` | Observado |
| 6 | Circulares / Agendar | Escolha de data/hora antes de publicar | `circulars.schedule` | §Escopo, l.25 | `/circulars/new` e `/circulars/:circularId/edit` | Seletor de agendamento e rótulo `Agendar circular` | `superadmin_circular_publish_v2(..., timestamptz)` e `public.publish_circular(..., p_publish_at)` | `apps/superadmin/lib/features/circulars/presentation/superadmin_circular_composer_page.dart:36,82,98-104,172-173,297-303`; `packages/coelo_database/migrations/20260901191921_superadmin_internal_circulars_v2.sql:471,584`; `packages/coelo_database/migrations/20260821190000_circulars_production.sql:611` | Observado |
| 7 | Circulares / Publicar | Publicação imediata com versão otimista | `circulars.publish` | §Escopo, l.25; §Permissões, l.58 | mesma rota do item 6 | Ação primária do composer | `superadmin_circular_publish_v2` / `public.publish_circular`; capacidade `circulars.circulars.publish` | `apps/superadmin/lib/features/circulars/presentation/superadmin_circular_composer_page.dart:82`; `apps/superadmin/lib/features/circulars/data/supabase_superadmin_circular_repository.dart:70`; `packages/coelo_database/migrations/20260821190000_circulars_production.sql:254,611` | Observado |
| 8 | Circulares / Encerrar respostas | Encerramento manual auditado | `circulars.close` | §Escopo, l.25; §Domínio, l.47 | sem evidência de rota/affordance | **Sem affordance de UI.** Só o método de repositório existe | `superadmin_circular_close_v2` e `public.close_circular_responses`; capacidade `circulars.circulars.manage` | `apps/superadmin/lib/features/circulars/data/supabase_superadmin_circular_repository.dart:79-84`; `apps/superadmin/lib/features/principal_circulars/data/supabase_circular_repository.dart:149-160`; `packages/coelo_database/migrations/20260821190000_circulars_production.sql:257,645`; `packages/coelo_database/migrations/20260901191921_superadmin_internal_circulars_v2.sql:515,585`; busca por `Encerrar` em `apps/superadmin/lib/features/circulars` e `.../principal_circulars` sem resultado | Proposto (BE observado, FE ausente) |
| 9 | Circulares / Excluir | Exclusão lógica quando existir histórico | `circulars.delete` | §Escopo, l.25-26 | sem evidência de rota/affordance | **Sem affordance de UI.** Nenhum botão `Excluir` no diretório ou no detalhe | RPC `public.delete_circular` existe e é chamado só pelo repositório do Principal. **Ausente no gateway v2** usado em produção | `apps/superadmin/lib/features/principal_circulars/data/supabase_circular_repository.dart:180-186`; `packages/coelo_database/migrations/20260821190000_circulars_production.sql:657,982`; `packages/coelo_database/migrations/20260901191921_superadmin_internal_circulars_v2.sql:580-586` (sem `delete`) | Proposto (BE parcial, FE ausente) |
| 10 | Responder Circular | Rascunho parcial, envio, conflito de versão, estado `Encerrada` | `circulars.respond` | §Escopo, l.23-24; §Domínio, l.47-49; §Permissões, l.58 | sem rota própria em produção | `PrincipalCircularReader` implementa seleção e envio, mas `PrincipalCircularDetailPage` **não é montado em nenhuma rota** do `lib` | RPCs `save_circular_response_draft` e `submit_circular_response`; capacidade `circulars.circulars.respond`. **Ausentes no gateway v2** | `apps/superadmin/lib/features/principal_circulars/presentation/principal_circular_reader.dart:56-61,132,155,186`; `apps/superadmin/lib/features/principal_circulars/presentation/principal_circular_detail_page.dart:10-24`; `apps/superadmin/lib/features/principal_circulars/data/supabase_circular_auxiliary_repositories.dart:1-100`; `packages/coelo_database/migrations/20260821190000_circulars_production.sql:256,707,742` | Proposto (BE observado, FE não roteado) |
| 11 | Circular / Anexos | Upload, limite de 4 arquivos, MIME/tamanho, leitura assinada, remoção | `circulars.attach` | §Escopo, l.21-22; §Mídia privada, l.62-74 | `/circulars/new` e `/circulars/:circularId/edit` | Lista de anexos e contador `n/4` renderizam, mas o **seletor de arquivos está desabilitado em produção** com aviso honesto | Edge Function `circular-media` + RPCs `prepare_circular_media_upload`, `authorize_circular_media_finalize`, `finalize_circular_media_upload`, `remove_circular_media`, `authorize_circular_media_read` | `apps/superadmin/lib/features/circulars/presentation/superadmin_circular_composer_page.dart:238-262`; `apps/superadmin/lib/features/circulars/presentation/production_circular_hosts.dart:223-229`; `apps/superadmin/lib/features/principal_circulars/application/circular_media_upload_coordinator.dart:34-83`; `apps/superadmin/lib/features/principal_circulars/data/supabase_circular_auxiliary_repositories.dart:146`; `packages/coelo_database/migrations/20260821190000_circulars_production.sql:544,567,580,596,816` | Proposto (BE observado, FE bloqueado em produção) |
| 12 | Acontece / Card de Circular | Projeção autorizada no feed misto, ordenada por publicação efetiva | `circulars.happens-card` | §Escopo, l.27; §UX, l.86-87; §Critérios, l.113 | `/principal-happens` (rota de produção) | Widget e repositório existem; a rota de produção usa o construtor **sem** feed misto, então a projeção **não aparece** | RPC `list_visible_happens_feed`, que exige `circulars.circulars.read` | `apps/superadmin/lib/features/principal_circulars/presentation/principal_circular_surfaces.dart:332-505`; `apps/superadmin/lib/features/principal_happens/presentation/principal_happens_preview_page.dart:37-38,42-46,145-186,473`; `apps/superadmin/lib/app/router/superadmin_router.dart:676-693`; `apps/superadmin/lib/features/principal_circulars/data/supabase_principal_mixed_feed_repository.dart:20-30`; `packages/coelo_database/migrations/20260821190000_circulars_production.sql:908,932` | Proposto (FE/BE existem, composição de produção ausente) |

### Itens opcionais de estado (decisão de D00, não somados acima)

`institutions` e `units` têm IDs próprios de estado (`*.error`,
`*.access-denied`, `*.reload`); `acontece`, `agora`, `momentos` e `notices` não
têm. Circulares reutiliza a geometria de Instituições (spec037 l.81-82) e a
página de diretório tem enum de estados próprio. Registro os três candidatos
**sem** somá-los ao total proposto, porque a escolha entre "seguir Instituições"
e "seguir Publicações do Principal" é de D00.

| Tela | Subtela/estado | `action_id` candidato | Evidência | Observado ou Proposto |
| ---- | -------------- | --------------------- | --------- | --------------------- |
| Circulares / Erro e retry | `CircularDirectoryViewState.error` | `circulars.error` | `apps/superadmin/lib/features/circulars/presentation/circular_directory_page.dart:10,269` | Proposto |
| Circulares / Acesso negado | `CircularDirectoryViewState.forbidden` | `circulars.access-denied` | `apps/superadmin/lib/features/circulars/presentation/circular_directory_page.dart:10`; guarda de rota em `apps/superadmin/lib/app/router/superadmin_router.dart:514-515` | Proposto |
| Circulares / Recarregar | recarga após erro | `circulars.reload` | sem evidência de affordance dedicada | Proposto |

### O que fica fora desta proposta

- **Aba `Circulares` do Perfil**: continua coberta por `principal.profile-view`,
  como o próprio rastreador integrado registra ("ID cobre aba Circulares do
  Perfil; não fecha diretório/compositor/detalhe/edição em `/circulars`",
  `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md:275`). Não proponho
  ID novo para essa aba para não contar a mesma superfície duas vezes. O que a
  proposta acrescenta são exatamente as superfícies que aquele ID **não** cobre.

## Contrato de backend existente (observado)

### `20260821190000_circulars_production.sql` (987 linhas)

**Tipos** (l.2-10): `circular_status`, `circular_revision_status`,
`circular_block_kind`, `circular_question_kind`, `circular_response_policy`,
`circular_response_status`, `circular_audience_kind`, `circular_scope_kind`,
`circular_media_status`.

**Tabelas** `public` (l.12-199): `circulars`, `circular_revisions`,
`circular_blocks`, `circular_questions`, `circular_question_options`,
`circular_audience_rules`, `circular_media_assets`, `circular_media_links`,
`circular_response_sessions`, `circular_response_revisions`, `circular_answers`,
`circular_answer_options`.

**Tabelas** `app_private` (l.201-222): `circular_command_receipts`,
`circular_audit`.

**RLS** (l.233-248): todas as doze tabelas `public` recebem
`enable row level security` + `force row level security` + `revoke all ... from
anon, authenticated`; as duas tabelas `app_private` são revogadas de
`public, anon, authenticated`.

**Permissões catalogadas** em `public.institution_permissions` (l.252-258),
com os códigos exatos:
`circulars.circulars.create`, `circulars.circulars.publish`,
`circulars.circulars.read`, `circulars.circulars.respond`,
`circulars.circulars.manage`.

**RPCs `public` com `grant execute ... to authenticated`** (l.979-985):
`load_circular_draft`, `save_circular_draft`, `prepare_circular_media_upload`,
`authorize_circular_media_finalize`, `remove_circular_media`,
`publish_circular`, `close_circular_responses`, `delete_circular`,
`save_circular_response_draft`, `submit_circular_response`,
`list_visible_profile_circulars`, `get_visible_circular`,
`authorize_circular_media_read`, `list_visible_happens_feed`.

**RPCs restritas a `service_role`** (l.986-987):
`finalize_circular_media_upload`, `claim_stale_circular_media`,
`mark_circular_media_deleted`.

### `20260901191921_superadmin_internal_circulars_v2.sql` (588 linhas)

Gateway interno do Superadmin, com `grant execute ... to authenticated`
(l.580-586) para: `superadmin_circular_directory_v2`,
`superadmin_circular_load_draft_v2`, `superadmin_circular_detail_v2`,
`superadmin_circular_save_draft_v2`, `superadmin_circular_publish_v2`,
`superadmin_circular_close_v2`, `superadmin_circular_response_summary_v2`.

### O que a spec037 pede e não foi encontrado no backend

| Pedido da spec037 | Situação observada |
| ----------------- | ------------------ |
| Exclusão lógica quando existir histórico (l.25-26) | `public.delete_circular` existe (l.657), mas **não há equivalente `superadmin_*_v2`**; o caminho de produção do Superadmin não expõe exclusão |
| Responder Circular (l.23-24, 47-49) | `save_circular_response_draft` e `submit_circular_response` existem (l.707, 742), mas **não há equivalente `superadmin_*_v2`** |
| Anexos no gateway administrativo (l.21-22, 62-74) | as RPCs de mídia existem em `public.*`, mas **nenhuma RPC de mídia foi adicionada ao gateway v2** |
| pgTAP cobrindo constraints, grants, RLS, capacidades, idempotência, cross-tenant, cross-context e IDOR/BOLA (l.118-119) | sem evidência inspecionada nesta proposta; não afirmo ausência, apenas que não localizei prova no recorte lido |

## Mídia e anexos — divergência a registrar

**Onde os anexos vão hoje, no código observado:**

- Migration cria e reforça o bucket **Supabase Storage** `coelo-circulars-private`
  (`packages/coelo_database/migrations/20260821190000_circulars_production.sql:147-155`),
  e `circular_media_assets.bucket_id` tem `default 'coelo-circulars-private'`
  (mesma migration, l.117).
- A Edge Function `circular-media` usa `admin.storage.from(...)` do Supabase
  para assinar upload, assinar leitura de 120 s, remover e limpar órfãos:
  `packages/coelo_database/supabase/functions/circular-media/index.ts:202,232-236,251,283-291,307-315`.
- O cliente Flutter chama essa função por `functions.invoke('circular-media')`
  (`apps/superadmin/lib/features/principal_circulars/data/supabase_circular_auxiliary_repositories.dart:146`)
  e o coordenador faz `PUT` na URL assinada devolvida
  (`apps/superadmin/lib/features/principal_circulars/application/circular_media_upload_coordinator.dart:44-56`).
- Em produção o seletor de arquivos não abre: o host mostra
  "Envio de anexos será habilitado após a seleção segura."
  (`apps/superadmin/lib/features/circulars/presentation/production_circular_hosts.dart:227`).

**A divergência concreta:**

- `specs/037-principal-circulars.md:64-66` ainda declara Supabase Storage
  privado, apoiado na ADR 0027.
- `decisions/0027-...:10-12` já traz nota própria dizendo que a ADR 0032 define
  R2 privado para anexos e mídia **novos** de Circulares e que o contexto
  Supabase Storage "permanece apenas histórico".
- `decisions/0032-mvp-private-media-r2.md:12-14` estabelece R2 como storage
  principal de **todos** os binários privados novos do MVP; a topologia é
  `coelo-media-prod`, `coelo-documents-prod`, `coelo-transient-prod`
  (l.29-35); o gateway continua sendo Edge Function server-side (l.185).
- **Ambiguidade real:** a seção "Escopo e segurança" da ADR 0032 (l.163-175)
  detalha a política de distribuição por produto para Agora, Momentos, Acontece
  e Chat. **Circulares não aparece nessa lista.** A ADR também não declara
  supersessão da ADR 0027 no frontmatter (`supersedes: decisions/0030-...`).

Isto é uma **pendência a registrar**, não uma decisão a tomar por L01: código,
migration e spec037 apontam para Supabase Storage; as ADRs apontam para R2. O
ponto exato de recorte (bucket, chave opaca, tipo de anexo PDF, expiração,
auditoria) precisa de decisão nominal antes de qualquer migração de contrato.

## Projeções — contrato mantido por L01, consumido por L03

Circulares publicadas alimentam duas superfícies. O contrato canônico é de L01;
o consumo é de L03 (`principal.for-you`, `principal.profile-view`,
`principal.profile-edit`, todos de L03 em `escopo.json`).

### Feed do Acontece (feed misto)

- SQL: `public.list_visible_happens_feed`
  (`packages/coelo_database/migrations/20260821190000_circulars_production.sql:908`),
  que exige `circulars.circulars.read` por instituição/unidade/turma
  (mesma migration, l.932), apoiada em
  `app_private.circular_feed_post_visible` (l.847) e
  `app_private.circular_feed_post_media` (l.827).
- Repositório: `SupabasePrincipalMixedFeedRepository`
  (`apps/superadmin/lib/features/principal_circulars/data/supabase_principal_mixed_feed_repository.dart:8-30`),
  já instanciado em produção
  (`apps/superadmin/lib/core/config/superadmin_auth_scope.dart:367`) e propagado
  até o router (`apps/superadmin/lib/main.dart:57`;
  `apps/superadmin/lib/app/router/superadmin_router.dart:279`).
- Widget de card: `PrincipalCircularFeedCard`
  (`apps/superadmin/lib/features/principal_circulars/presentation/principal_circular_surfaces.dart:332`),
  consumido em `apps/superadmin/lib/features/principal_happens/presentation/principal_happens_preview_page.dart:473`.
- **O que falta:** a rota de produção do Acontece
  (`apps/superadmin/lib/app/router/superadmin_router.dart:676-693`) usa o
  construtor padrão de `PrincipalHappensPreviewPage`, que zera
  `mixedFeedRepository` e `mixedFeedScope`
  (mesmo arquivo de página, l.37-38). O construtor `.mixed` (l.42-46) existe,
  mas em `apps/superadmin/lib` **nenhuma chamada foi encontrada** — só testes
  (`apps/superadmin/test/features/principal_happens/presentation/principal_happens_mixed_feed_test.dart:31,66,97,117`).
  Enquanto isso não mudar, o critério da spec037 l.113 ("Circular aparece uma vez
  no feed misto, ordenado por publicação efetiva") não tem como ser provado na
  rota real.

### Aba Circulares do Perfil

- SQL: `public.list_visible_profile_circulars`
  (`packages/coelo_database/migrations/20260821190000_circulars_production.sql:763`)
  e `public.get_visible_circular` (l.782), ambas exigindo
  `circulars.circulars.read`.
- Repositório: `SupabaseCircularRepository.listProfile` / `getVisible`
  (`apps/superadmin/lib/features/principal_circulars/data/supabase_circular_repository.dart:89,116`).
- Widget: `PrincipalProfileCircularsTab`
  (`apps/superadmin/lib/features/principal_circulars/presentation/principal_circular_surfaces.dart:132`),
  consumido em
  `apps/superadmin/lib/features/principal_profile/presentation/principal_profile_preview_page.dart:899`.
- **O que falta para L03 consumir:** a página de Perfil só é montada na rota
  `/dev/principal-profile`
  (`apps/superadmin/lib/app/router/superadmin_router.dart:930-939`), e essa
  montagem **não passa** `circularRepository` nem `circularScope`. Sem eles, a
  aba cai no placeholder "Contexto não autorizado"
  (`apps/superadmin/lib/features/principal_profile/presentation/principal_profile_preview_page.dart:893-898`).
  Ou seja: existe contrato de dados, existe widget, e **não existe composição de
  produção**. Para L03 consumir, é preciso (a) uma rota de Perfil em produção,
  (b) injeção de `CircularRepository` e `CircularScope` a partir do contexto
  autorizado, e (c) `onOpenCircular` apontando para um detalhe roteado.

## Efeito no denominador

- Denominador anterior do recorte L01 em `escopo.json`: **12 IDs**
  (`countsByOwner.L01.total = 12`), todos `mvp`, todos `e2eActiveApplicable`,
  todos `pending-verification` nos três eixos:
  `acontece.feed`, `acontece.create`, `acontece.publish`, `acontece.remove`,
  `agora.view`, `agora.create`, `agora.publish`, `agora.expire`,
  `momentos.view`, `momentos.create`, `momentos.publish`, `momentos.remove`.
- Esta proposta acrescenta **12 IDs** na tabela principal, mais **3 candidatos
  opcionais de estado** apresentados separadamente.
- Se D00 aceitar apenas a tabela principal: denominador L01 passa de **12** para
  **24**. O total global de `escopo.json` passaria de **219** para **231**.
- Se D00 aceitar também os três opcionais: denominador L01 = **27**; global = **234**.
- Sugestão de atributos, para D00 avaliar: `family: "circulars"`,
  `scope: "mvp"`, `owner: "L01"`, `selected: true`,
  `e2eActiveApplicable: true`, e os três eixos de snapshot em
  `pending-verification`. Nenhum item desta proposta tem prova de conclusão.

**Isto não é regressão de implementação.** Nenhuma funcionalidade foi perdida,
revertida ou rebaixada. É cobertura de inventário que estava faltando: as
superfícies das linhas 1-7 e 11-12 já existiam no código antes desta rodada e
simplesmente não tinham `action_id` próprio para serem verificadas, medidas ou
certificadas. Qualquer queda de percentual observada após a reconciliação é
efeito de o denominador passar a refletir o produto real — não de o produto ter
piorado.

## Decisões que só D00/Owner podem tomar

1. **Aceitar ou renomear** a família `circulars` e os 12 `action_id` propostos,
   e publicá-los em `docs/reviews/inventario-etapa-2.json` e em `escopo.json`.
2. **Decidir sobre os 3 IDs opcionais de estado** (`circulars.error`,
   `circulars.access-denied`, `circulars.reload`): Circulares segue o padrão de
   Instituições, que os tem, ou o padrão de Acontece/Agora/Momentos, que não os tem?
3. **Decidir se `circulars.happens-card` é ID próprio** de L01 ou subestado de
   `acontece.feed`. A projeção tem repositório, RPC e widget próprios, mas
   renderiza dentro do feed que já pertence a `acontece.feed`.
4. **Confirmar a fronteira com `principal.profile-view` (L03)**: a aba do Perfil
   permanece em L03 e o contrato de dados permanece em L01, como propus, ou D00
   quer um ID de projeção explícito?
5. **Decidir Circulares × ADR 0032**: o bucket Supabase `coelo-circulars-private`
   continua válido enquanto durar o MVP, ou os anexos de Circulares migram para
   `coelo-media-prod`/`coelo-documents-prod`? A ADR 0032 não lista Circulares na
   política de distribuição por produto, e a ADR 0027 já se declara histórica.
   Enquanto não houver decisão, o item 11 da tabela não pode ser certificado.
6. **Decidir a paridade do gateway v2**: `delete_circular`,
   `save_circular_response_draft`, `submit_circular_response` e as RPCs de mídia
   não têm equivalente `superadmin_*_v2`. Sem decisão, `circulars.delete`,
   `circulars.respond` e `circulars.attach` nascem estruturalmente incompletos
   no caminho de produção.
7. **Autorizar (ou não) a composição de produção** das duas projeções: rota real
   de Perfil com repositório injetado e uso do construtor
   `PrincipalHappensPreviewPage.mixed` na rota de Acontece. Sem isso, o critério
   da spec037 l.113 e a aba do Perfil permanecem improváveis na rota real.
8. **Reconciliar a spec037** com a decisão de mídia: hoje a spec (l.64-66)
   contradiz a ADR 0027 revisada e a ADR 0032.

## Ambiguidades explícitas da spec037

- **l.25-26, "exclusão lógica quando existir histórico"**: a spec não define se
  a exclusão sem histórico é física, nem quem é o ator autorizado (autor ou
  `manage`). A migration resolve por autor **ou** `circulars.circulars.manage`
  (`packages/coelo_database/migrations/20260821190000_circulars_production.sql:664`),
  mas isso é implementação, não texto aprovado.
- **l.23-24, "ordenação, duplicação e exclusão" de perguntas**: são operações do
  editor, não ações de tela. Não propus IDs separados para elas; se D00 quiser
  IDs, a spec não dá base para dizer quantos.
- **l.88-96, prévia em popup contextual no web**: a spec descreve uma ação
  explícita que abre a prévia do card do Acontece dentro do Perfil. Não
  localizei essa affordance no código; não propus ID próprio porque não sei se
  D00 a considera subestado de `circulars.detail` ou de `principal.profile-view`.
- **l.98-99, "o editor pertence ao fluxo de publicação do Principal ... não
  reutiliza wizard administrativo do Superadmin"**: o código observado faz o
  contrário — o composer roteado em produção é
  `SuperadminCircularComposerPage`, enquanto `PrincipalCircularComposerPage`
  existe mas só aparece em testes
  (`apps/superadmin/test/features/principal_circulars/presentation/principal_circular_composer_page_test.dart:23`).
  Há duas leituras possíveis: a spec está desatualizada em relação à Etapa 2 do
  Superadmin, ou o composer roteado é o errado. Não resolvo isso aqui.
- **l.107-109, lista de estados exigidos**: são dezessete estados. Não há base
  na spec para dizer se cada um vira ID, subestado ou apenas critério de aceite.
