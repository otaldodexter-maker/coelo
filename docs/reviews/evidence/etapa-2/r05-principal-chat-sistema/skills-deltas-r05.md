---
title: "Deltas para as skills — R05 principal-chat-sistema"
source: "comunicacao/principal-chat-sistema.json revs 21–26; rota real com qa-r03 em 11/09/2026; pacotes 20260911130000..130300"
status: "proposta ao coordenador (aplicar nas SKILL.md de coelo-backend, coelo-frontend, coelo-frontend-backend e coelo-ui)"
generated_at: "2026-09-11"
---

# Deltas para as skills — R05, frente Principal, Chat e Sistema

## coelo-backend (`.agents/skills/coelo-supabase/SKILL.md`)

- **Ponte de ator não cobre quem resolve por `person_auth_links`.** A ponte
  220400 só alcança `app_private.current_person_id()`. Toda função que
  resolvia a pessoa por `public.person_auth_links` (contexto do Principal,
  `happens_actor`, `now_actor`, `moments_actor_for_auth_user`, resgates de
  ticket de mídia) não enxergava a identidade interna. Desde 130000 existe
  `app_private.person_id_for_auth_user(uuid)` (people-based com precedência,
  espelho interno em seguida): função nova que precise do ator por auth user
  usa esse helper, nunca `person_auth_links` diretamente.
- **Membership sem `institution_role_assignments` não autoriza nada.**
  `has_context_permission` exige papel atribuído; uma membership semeada só
  com `role_code` (lote 27) resulta em `*_permission_denied`. "Superadmin vê
  tudo" (P35) vive em `superadmin_internal_actor_institution_access_sync()`:
  membership `owner` + papel de sistema `institution_admin` (P31) para todo
  espelho interno com `platform_membership` ativa em toda instituição ativa,
  com gatilhos em `institutions` e `superadmin_internal_actor_people`.
- **`role_code` fora da lista fixa cai em `else false`.**
  `circular_feed_post_visible` só reconhecia guardian/student/professional/
  institution_admin/unit_admin/teacher/coordinator: `owner` não via nem o
  próprio post. Desde 130200 `owner` vê qualquer público do escopo e
  `secretary` entra na equipe escolar. Ao criar papel novo, revisar os
  predicados de audiência (Acontece, Agora `now_viewer_role_class`,
  Momentos `moments_audience_matches_role`).
- **Migração histórica "presente no mapa" pode nunca ter sido aplicada.**
  `list_visible_moments`/`withdraw_moment` (20260909216000) só existiam em
  `migrations-historico`; a rota real respondeu PGRST202. O recarimbo
  idêntico (130300) aplicou sobre a baseline sem alteração. Antes de provar
  uma família na rota real, conferir `to_regprocedure` de cada RPC que o
  cliente chama.
- **Arrobas reservados** vivem em `public.reserved_handles` (RLS, sem grant a
  cliente) com `app_private.is_reserved_handle(text)` e gatilhos BEFORE em
  `institutions.slug` e `units.handle` (`check_violation handle_reserved`);
  quando pessoas ganharem coluna de @, reaproveitar o mesmo helper.
- **Perfil Coelo (P35 B):** pessoa de serviço fixa
  `c0e10000-0000-4000-8000-000000000001`, seguida por toda pessoa ativa e
  seguindo todas (`follow_links` origem `manual`, porque `automatic` exige
  contexto de criança; pendência: valor `system` no enum). Avatar e capa
  dependem de catálogo de mídia de perfil de pessoa, que não existe.
- **pgTAP e o privilégio padrão revogado (190900):** helper `security definer`
  criado em `pg_temp` pelo teste perde o EXECUTE de PUBLIC e falha como
  `permission denied for function` ao trocar para `authenticated`
  (`happens_media_private_r2_v1_test`, `now_media_private_r2_v1_test`).
  Conceder execute explícito no próprio teste.
- **Espelho descartável:** `supabase db reset` exige `supabase start` antes
  (`LegacyResetLocalDbNotRunningError`); a aplicação das 107 migrations na
  ordem de produção por `psql` leva ~9 min; nunca rodar dois `apply` no mesmo
  container (as guardas forward-only de 200300 e 171000 acusam replay).
- **Edge Functions de mídia têm allowlist própria de origens**
  (`MOMENTS_MEDIA_ALLOWED_ORIGINS`, `HAPPENS_`, `NOW_`, `CIRCULAR_`,
  `CHAT_`): 403 `origin_not_allowed` antes de qualquer autorização. O CORS do
  R2 liberar `localhost:3000` não basta para a prova local; a origem do
  servidor de teste precisa estar nas allowlists das funções.

## coelo-frontend (`.agents/skills/coelo-flutter-review/SKILL.md`)

- **Seletor de perfil do Principal (P28)** vive em
  `PrincipalRuntimeContextRoute`: com mais de um vínculo abre no primeiro e
  mostra a barra "Vendo como" (`PrincipalContextSelectorBar`, chave
  `principal-context-selector`), até 5 perfis inline, "Ver todos" em popup e,
  para híbridos, ver como Responsável/Funcionário/ambos. O painel "Selecione
  um contexto" deixou de existir. A escolha é preferência de filtro, não
  autorização.
- **Contexto de runtime** carrega `institutionHandle`/`unitHandle` (o @,
  desde 130100), `canPublish` (responsável e aluno não publicam) e `label`.
- **Cabeçalho do Principal** usa `PrincipalBrandButton` (SuperadminBrandMark
  36 px + "Coelo" + chevron, tooltip "Abrir menu"), igual ao cabeçalho mobile
  do shell; o wordmark tipográfico "coelo" saiu (P28). O "+" do dock chama-se
  "Publicar", leva ao Acontece e só aparece com `canPublish`.
- **Perfil (P28):** o Stack do hero contém o avatar
  (`coverHeight + avatarSize * .55 + space2`); o @ aparece sob o nome
  (`principal-profile-handle`); avatares de vínculos sobrepostos têm contorno
  na cor da superfície; goldens `principal_profile_*` regravados após as
  quatro correções.
- **Publicadores aceitam contexto de instituição:** `unitId`/`groupId`
  opcionais em `HappensPublicationContext`, `NowPublicationContext` e
  `MomentsPublicationContext` (`scopeLabel` cai para o nome da instituição);
  o router não devolve mais "composição indisponível" para escopo
  institucional (`principal_happens_composition_gaps_test` invertido).
- **`get_profile_about` devolve `null`** (não um envelope) quando o sujeito
  não tem Sobre: `parseProfileAboutReadResponse` trata como ausência de
  página; antes o Perfil real caía em "Não foi possível carregar".
- **Cardápios em produção:** `authorizedMealPlanTenantId` nunca é injetado
  pela composição, então criar/editar cardápio e modelo respondem 503
  (`meal-plan-authorized-tenant-unavailable`) na rota real. O assistente
  deriva o tenant da instituição escolhida e o servidor valida
  (`meal_plan_scope_allowed`); a remoção do fail-closed é decisão registrada
  (P43), não foi aplicada.
- **Testes de composição** (`composition_root_sanitization_test`,
  `superadmin_auth_scope_test`) afirmam o estado ligado da R04: Atividades
  compõem os adapters Supabase só no auth scope; rotas de Acessos compostas;
  Rotina, Medicação, Turmas, Unidades e `structureMutationsEnabled` reais.
- **Pré-existentes em `origin/dev`** (medidos com `git stash`):
  `principal_real_route_test` ("never uses demo fixtures", "keeps its host":
  `Bad state: No element`), `person_detail_golden` (2), `structure_detail_golden`
  (4), `import_development_routes`, `people_creation_requirements_red`,
  `prototype_navigation_routes`, `persistent_shell_routes`,
  `superadmin_error_routes` "503".

## coelo-frontend-backend (`.agents/skills/coelo-flutter-supabase-review/SKILL.md`)

- **Primeiro E2E do Principal:** `acontece.feed/create/publish/remove` pela
  rota real com `qa-r03` (contexto de instituição `QA R04 Cuidado`):
  `save_happens_draft` + `publish_happens_post` 200, feed lista após reload,
  retirada pela tela persiste, outro tenant 42501. Foram necessários quatro
  pacotes (130000–130300) descobertos um a um na rota real: a régua só fecha
  provando pela tela, não pela presença das RPCs.
- **Upload de mídia pela rota real:** `cdp_file.dart` intercepta
  `Page.setInterceptFileChooserDialog` e entrega o arquivo por
  `DOM.setFileInputFiles(backendNodeId)`; `DOM.querySelector('input[type=file]')`
  não encontra o input do file_picker. A publicação com mídia parou na Edge
  Function (allowlist de origens): registrar o status pelo Network antes de
  culpar o R2.
- **`cdp_net.dart` com `-` não navega**, mas cliques por coordenada mudam
  com a altura da viewport (905 vs 849 px entre relançamentos do Chrome):
  recalcular as coordenadas a partir da captura atual antes de cada etapa.
- **Prova de RPC com credencial só em memória:** `ferramentas/rpc.py` lê
  `qa-r03.env` e `.env.local`, entra por senha e chama RPCs com
  `Prefer: params=single-object`; útil para medir o que a tela não mostra
  (feed devolvendo `[]` para owner, PGRST202 de função ausente).
- **Publicação e reload:** o publicador do Acontece volta à etapa 1 após
  reload (rascunho não salvo automaticamente); a prova de "reload mantém" é
  o item publicado no feed, não o formulário.

## coelo-ui

- Perfil do Principal: avatar inteiro sobre a capa, @ sob o nome, contorno
  nos avatares sobrepostos, cabeçalho com a marca real (SuperadminBrandMark)
  em todas as telas do Principal e nos publicadores; goldens de Perfil,
  Acontece, Para você e dos três publicadores regravados após a observação
  do Owner (P28), no SDK 3.44.2.
- Barra "Vendo como" (chip com nome e @) acima do conteúdo do Principal
  hospedado no Superadmin; folha inferior "Ver como" com segmentos
  Responsável/Funcionário/Ambos para híbridos, lista de até 5 e "Ver todos".
- Pendência de UI (pré-existente): as páginas do Principal em `embedded`
  ainda desenham o próprio cabeçalho e o dock dentro do shell (captura 01).
