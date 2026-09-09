-- =====================================================================
-- Coelo | E2 noturna | perfil-para-voce
-- action_id: principal.profile-view, principal.profile-edit
-- Proposta de leitura autorizada no servidor: public.get_profile_about
-- ---------------------------------------------------------------------
-- STATUS: PROPOSTA. NAO APLICADA. NAO E MIGRATION.
--   Vive em packages/coelo_database/plans/ e NAO em
--   packages/coelo_database/migrations/. Nenhum runner deve executa-lo.
--   Promover a migration exige numero forward-only proprio.
-- FORWARD-ONLY: cria uma funcao nova. Nao faz drop, alter ou revoke de
--   nenhum objeto existente. Nao altera tabelas, policies, enums, grants
--   ou a RPC de escrita public.save_profile_about.
-- AUTORIZACAO: todo recurso Supabase do Coelo e PRODUCAO. A aplicacao
--   remota exige autorizacao nominal do Owner e serializacao pelo
--   coordenador. Quem escreveu este arquivo NAO tem essa autorizacao e
--   NAO validou este SQL contra nenhum banco, local ou remoto.
--
-- PROBLEMA QUE RESOLVE
--   A unica migration versionada do dominio,
--   20260825193131_final_review_profile_about_lint_hardening.sql, expoe
--   somente a ESCRITA. Por isso
--   apps/superadmin/lib/features/profile_about/data/supabase_profile_about_repository.dart
--   le public.profile_about_pages, _structured_fields e _sections direto
--   por PostgREST e depende inteiramente de RLS. Se essas tabelas
--   estiverem deny-by-default com grants revogados, a leitura do Sobre
--   falha fechada em producao: o editor abre negado e o Perfil nunca
--   mostra o Sobre, mesmo para quem pode salva-lo.
--
-- FUNDAMENTACAO, NAO INFERENCIA
--   Tudo abaixo reutiliza objetos que a RPC de escrita ja chama e que,
--   portanto, existem no banco remoto:
--     app_private.current_person_id()
--     app_private.profile_about_can(inst, capability, unit, group, activity)
--     app_private.profile_about_page_for(subject_type, subject_id)
--   As colunas lidas sao exatamente as que os INSERTs da mesma RPC
--   escrevem. Nenhum nome de coluna, enum ou capacidade novo e inventado.
--   O schema dessas tabelas continua remote-only: esta proposta NAO o
--   versiona e nao pretende substituir esse trabalho.
--
-- DECISAO AINDA NECESSARIA (registrada, nao decidida aqui)
--   Existem duas audiencias de leitura e apenas UMA capacidade confirmada
--   no repositorio inteiro para gerenciar o Sobre:
--   'profiles.about.manage'. Nao existe token de leitura confirmado.
--     (a) EDITOR — quem administra o Sobre. Coberto sem inventar nada:
--         exige a mesma 'profiles.about.manage' que a escrita exige, e
--         recebe a pagina inteira, inclusive rascunho.
--     (b) LEITOR NO PRINCIPAL — quem apenas ve o Perfil contextual.
--         Aqui NAO ha regra canonica aprovada. Esta proposta erra para o
--         lado fechado: exige vinculo ativo do ator na instituicao do
--         sujeito e entrega SOMENTE pagina com state='published' e
--         somente campos/secoes com visibility='profile_access' — o unico
--         token de visibilidade confirmado, porque e o default dos
--         INSERTs da RPC de escrita. Qualquer outro token e tratado como
--         mais restrito e omitido.
--   Se o Owner ou o dono do dominio decidir outra regra de visibilidade,
--   o bloco (b) muda; o bloco (a) nao depende dessa decisao.
--
-- CONTRATO DE RETORNO
--   jsonb_build_object(
--     'page',     null | {id, version, state},
--     'fields',   [ {field_key, value, latitude, longitude, visibility,
--                    origin, source_label} ],
--     'sections', [ {id, section_type, title, body, items, position,
--                    visibility, state, origin, revision} ]
--   )
--   As chaves sao as MESMAS colunas que o cliente ja le hoje por
--   PostgREST, de proposito: parseProfileAboutPage nao precisa mudar e a
--   troca de fonte nao vira uma segunda gramatica de leitura.
--   'page' nulo significa "nao ha pagina para este sujeito", que o
--   cliente ja distingue de negacao e de falha.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.get_profile_about(
  p_subject_type text,
  p_subject_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  actor uuid := app_private.current_person_id();
  p public.profile_about_pages;
  inst uuid;
  unit_id uuid;
  group_id uuid;
  activity_id uuid;
  can_manage boolean := false;
  has_membership boolean := false;
  published_only boolean;
begin
  if actor is null then
    raise insufficient_privilege;
  end if;

  -- Mesma retencao da escrita: o Sobre de pessoa nao esta liberado.
  if p_subject_type = 'person' then
    raise insufficient_privilege using message = 'person About is not released';
  end if;

  -- Resolucao do sujeito identica a de public.save_profile_about.
  if p_subject_type = 'institution' then
    select id into inst from public.institutions where id = p_subject_id;
  elsif p_subject_type = 'unit' then
    select unit_row.institution_id, unit_row.id
      into inst, unit_id
      from public.units unit_row
     where unit_row.id = p_subject_id;
  elsif p_subject_type = 'group' then
    select group_row.institution_id, group_row.unit_id, group_row.id
      into inst, unit_id, group_id
      from public.groups group_row
     where group_row.id = p_subject_id;
  elsif p_subject_type = 'activity' then
    select institution_id, id
      into inst, activity_id
      from public.activity_definitions
     where id = p_subject_id;
  else
    raise check_violation using message = 'unknown subject type';
  end if;

  if inst is null then
    raise insufficient_privilege;
  end if;

  can_manage := app_private.profile_about_can(
    inst, 'profiles.about.manage', unit_id, group_id, activity_id
  );

  if not can_manage then
    -- Leitor do Principal: vinculo ativo e nao revogado na instituicao do
    -- sujeito. O vinculo e conferido no SERVIDOR; o cliente nunca decide.
    select exists (
      select 1
        from public.institution_memberships m
       where m.person_id = actor
         and m.institution_id = inst
         and m.status = 'active'
         and m.revoked_at is null
    ) into has_membership;

    if not has_membership then
      raise insufficient_privilege;
    end if;
  end if;

  published_only := not can_manage;

  p := app_private.profile_about_page_for(p_subject_type, p_subject_id);

  if p.id is null then
    return jsonb_build_object(
      'page', null,
      'fields', '[]'::jsonb,
      'sections', '[]'::jsonb
    );
  end if;

  if published_only and coalesce(p.state, 'draft') <> 'published' then
    -- Ha pagina, mas nada publicado para este leitor. "Sem conteudo" e o
    -- estado correto aqui, e nao negacao: o ator esta autorizado a ver o
    -- Perfil, so nao existe Sobre publicado.
    return jsonb_build_object(
      'page', null,
      'fields', '[]'::jsonb,
      'sections', '[]'::jsonb
    );
  end if;

  return jsonb_build_object(
    'page', jsonb_build_object('id', p.id, 'version', p.version, 'state', p.state),
    'fields', coalesce(
      (
        select jsonb_agg(
                 jsonb_build_object(
                   'field_key', f.field_key,
                   'value', f.value,
                   'latitude', f.latitude,
                   'longitude', f.longitude,
                   'visibility', f.visibility,
                   'origin', f.origin,
                   'source_label', f.source_label
                 )
               )
          from public.profile_about_structured_fields f
         where f.page_id = p.id
           and (not published_only or f.visibility = 'profile_access')
      ),
      '[]'::jsonb
    ),
    'sections', coalesce(
      (
        select jsonb_agg(
                 jsonb_build_object(
                   'id', s.id,
                   'section_type', s.section_type,
                   'title', s.title,
                   'body', s.body,
                   'items', to_jsonb(s.items),
                   'position', s.position,
                   'visibility', s.visibility,
                   'state', s.state,
                   'origin', s.origin,
                   'revision', s.revision
                 )
                 order by s.position
               )
          from public.profile_about_sections s
         where s.page_id = p.id
           and (not published_only or (s.visibility = 'profile_access' and s.state = 'published'))
      ),
      '[]'::jsonb
    )
  );
end
$function$;

-- Grant deliberadamente minimo: somente o papel autenticado. A funcao e
-- SECURITY DEFINER e faz toda a autorizacao internamente; anon nao le.
REVOKE ALL ON FUNCTION public.get_profile_about(text, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.get_profile_about(text, uuid) TO authenticated;

-- =====================================================================
-- VERIFICACAO ESPERADA APOS APLICACAO NOMINAL (nao executada aqui)
--   1. Ator sem sessao -> insufficient_privilege.
--   2. Ator com 'profiles.about.manage' -> pagina inteira, inclusive
--      rascunho e secoes nao publicadas.
--   3. Ator apenas com vinculo ativo -> somente published/profile_access.
--   4. Ator sem vinculo e sem capacidade -> insufficient_privilege.
--   5. Sujeito inexistente -> insufficient_privilege (nao vaza existencia).
--   6. p_subject_type='person' -> insufficient_privilege.
--   7. Sujeito sem pagina -> {'page': null, ...}, nunca erro.
--   8. save_profile_about continua com assinatura e privilegios intactos.
-- =====================================================================
