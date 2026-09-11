-- Detalhe de perfil de acesso (Superadmin) com rascunho em branco e matriz de
-- permissoes: app_private.access_profile_detail_v3 e o wrapper publico
-- public.superadmin_access_profile_detail. Grupo acessos-pessoas, R04.
--
-- ORIGEM
--   O formulario Criar/Editar perfil de acesso do Superadmin
--   (apps/superadmin/lib/features/access_profiles/data/supabase_access_profile_repository.dart,
--   fetchDetail e fetchTemplate) chama
--   public.superadmin_access_profile_detail(p_domain, p_profile_id) e:
--     (1) para perfil NOVO envia p_profile_id = null esperando um rascunho em
--         branco (id '', code '', name '', status 'active', version 0,
--         permissions = catalogo completo do dominio com selected=false);
--     (2) le no JSON as chaves consumidas por AccessProfile.fromJson
--         (id, code, name, description, status, max_scope_kind, version,
--         is_system, institution_id, membership_count, memberships[{id,
--         person_name, scope}], permissions[{code, module, screen_code,
--         action_code, name, description, risk, requires_mfa, selected,
--         grantable, inherited, unavailable_reason}] e audit[{action,
--         occurred_at, reason}] quando o ator pode ler auditoria).
--   Em producao (baseline migrations/20260910000000_baseline_producao.sql) o
--   wrapper publico delega a app_private.access_profile_detail_v2, que devolve
--   somente to_jsonb(role) || {domain, linked_people_count, capability_count}
--   e levanta no_data_found (P0002) quando p_profile_id e nulo. Resultado: a
--   tela de criacao falha e a tela de edicao nao recebe matriz nem vinculos.
--   A forma rica existia na cadeia historica, que nunca chegou a producao
--   nessa forma:
--     * migrations-historico/20260729144440_profiles_permissions_governance.sql
--       (ramos platform/institution, rascunho por `where p_profile_id is null`);
--     * migrations-historico/20260804205732_access_profile_permission_matrix_metadata.sql
--       (screen_code e action_code em cada permissao).
--
-- O QUE ESTE PACOTE FAZ (forward-only, sem tocar em objetos aplicados)
--   * cria app_private.access_profile_detail_v3(p_domain text, p_profile_id uuid):
--     security definer, search_path vazio, autorizacao por
--     app_private.require_profile_authority(p_domain) exatamente como a v2;
--     ramos 'platform' (public.platform_roles / platform_role_permissions /
--     platform_memberships / platform_permissions) e 'institution'
--     (public.institution_roles / institution_role_permissions /
--     institution_role_assignments / institution_permissions); rascunho em
--     branco quando p_profile_id e nulo; no_data_found quando o id nao existe;
--     invalid_parameter_value para outro dominio.
--   * faz public.superadmin_access_profile_detail delegar a v3, mantendo a
--     assinatura, language sql stable security definer, search_path vazio e a
--     ACL observada em producao (revogada de PUBLIC/anon; execute para
--     authenticated e service_role).
--   * app_private.access_profile_detail_v2 permanece intacta: save, duplicate,
--     delete_and_reassign e a auditoria before/after continuam a usa-la.
--
-- AJUSTES DELIBERADOS EM RELACAO AO HISTORICO
--   * search_path vazio (a versao historica usava pg_catalog, public); todos os
--     objetos sao qualificados.
--   * O rascunho e montado por lista explicita de colunas, nao por `select *
--     union all select null,...` posicional: platform_roles e institution_roles
--     ganharam colunas (source_template_id, source_template_version) depois do
--     historico e a forma posicional quebraria.
--   * membership_count conta somente vinculos ativos (platform: status='active'
--     e revoked_at nulo; institution: status='active' e nao expirado), o mesmo
--     recorte da lista `memberships`; no historico contava todos os registros e
--     o numero divergia da lista exibida.
--   * `name` de cada permissao usa description, com fallback para action_label
--     (coluna NOT NULL desde 20260811215451); tambem sao expostos module_label,
--     screen_label e action_label, chaves adicionais que o cliente ignora hoje
--     e que a matriz pode usar como rotulo humano.
--   * escopo de atribuicao institucional por grupo rotulado 'Turma: ' (versao
--     20260804), alinhado a AccessProfileScope.group.label do cliente.
--   * `inherited` e sempre false: nao existe heranca de permissao entre perfis
--     no modelo atual; a chave e enviada para o contrato ficar explicito.
--   Nenhuma exigencia nova de MFA (ADR 0034, Decisao 12).

create or replace function app_private.access_profile_detail_v3(
  p_domain text,
  p_profile_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  result jsonb;
  can_read_audit boolean;
begin
  perform app_private.require_profile_authority(p_domain);
  can_read_audit := app_private.has_platform_permission('audit.read');

  if p_domain = 'platform' then
    select jsonb_build_object(
      'domain', 'platform',
      'id', coalesce(role_record.id::text, ''),
      'code', coalesce(role_record.code, ''),
      'name', coalesce(role_record.name, ''),
      'description', coalesce(role_record.description, ''),
      'status', coalesce(role_record.status, 'active'),
      'max_scope_kind', coalesce(role_record.max_scope_kind, 'platform'),
      'version', coalesce(role_record.version, 0),
      'is_system', coalesce(role_record.is_system, false),
      'membership_count', (
        select count(*)
        from public.platform_memberships membership
        where membership.role_id = role_record.id
          and membership.status = 'active'
          and membership.revoked_at is null
      ),
      'memberships', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', membership.id,
          'person_name', person_record.display_name,
          'scope', case
            when membership.scope_kind = 'platform' then 'Plataforma'
            else 'Instituição: ' || coalesce(institution_record.public_name,
              membership.scope_institution_id::text)
          end
        ) order by lower(person_record.display_name), membership.id)
        from public.platform_memberships membership
        join public.people person_record on person_record.id = membership.person_id
        left join public.institutions institution_record
          on institution_record.id = membership.scope_institution_id
        where membership.role_id = role_record.id
          and membership.status = 'active'
          and membership.revoked_at is null
      ), '[]'::jsonb),
      'permissions', coalesce((
        select jsonb_agg(jsonb_build_object(
          'code', permission_record.code,
          'module', permission_record.module_code,
          'screen_code', coalesce(permission_record.screen_code, 'general'),
          'action_code', permission_record.action_code,
          'module_label', permission_record.module_label,
          'screen_label', permission_record.screen_label,
          'action_label', permission_record.action_label,
          'name', coalesce(permission_record.description, permission_record.action_label),
          'description', permission_record.description,
          'risk', permission_record.risk_level,
          'requires_mfa', permission_record.requires_mfa,
          'selected', grant_record.id is not null and grant_record.effect = 'allow',
          'grantable', actor_grant.allowed,
          'inherited', false,
          'unavailable_reason', case
            when actor_grant.allowed then null
            else 'Você não pode conceder uma permissão que não possui.'
          end
        ) order by permission_record.module_code, permission_record.screen_code,
          permission_record.action_code, permission_record.code)
        from public.platform_permissions permission_record
        cross join lateral (
          select app_private.has_platform_permission(permission_record.code) as allowed
        ) actor_grant
        left join public.platform_role_permissions grant_record
          on grant_record.permission_id = permission_record.id
          and grant_record.role_id = role_record.id
          and grant_record.status = 'active'
          and grant_record.revoked_at is null
        where permission_record.status = 'active'
      ), '[]'::jsonb),
      'audit', case when can_read_audit then
        coalesce((
          select jsonb_agg(jsonb_build_object(
            'action', audit_record.action_code,
            'reason', audit_record.reason,
            'occurred_at', audit_record.occurred_at
          ) order by audit_record.occurred_at desc)
          from (
            select audit_row.action_code, audit_row.reason, audit_row.occurred_at
            from audit.audit_logs audit_row
            where audit_row.object_id = role_record.id
            order by audit_row.occurred_at desc
            limit 10
          ) audit_record
        ), '[]'::jsonb)
      else null end
    )
    into result
    from (
      select role_row.id, role_row.code, role_row.name, role_row.description,
        role_row.status::text as status, role_row.max_scope_kind,
        role_row.version, role_row.is_system
      from public.platform_roles role_row
      where role_row.id = p_profile_id
      union all
      select null::uuid, '', '', '', 'active', 'platform', 0::bigint, false
      where p_profile_id is null
      limit 1
    ) role_record;

  elsif p_domain = 'institution' then
    select jsonb_build_object(
      'domain', 'institution',
      'id', coalesce(role_record.id::text, ''),
      'institution_id', role_record.institution_id,
      'code', coalesce(role_record.code, ''),
      'name', coalesce(role_record.name, ''),
      'description', coalesce(role_record.description, ''),
      'status', coalesce(role_record.status, 'active'),
      'max_scope_kind', coalesce(role_record.max_scope_kind, 'institution'),
      'version', coalesce(role_record.version, 0),
      'is_system', coalesce(role_record.is_system, false),
      'membership_count', (
        select count(*)
        from public.institution_role_assignments assignment
        where assignment.role_id = role_record.id
          and assignment.status = 'active'
          and (assignment.expires_at is null or assignment.expires_at > now())
      ),
      'memberships', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', assignment.id,
          'person_name', person_record.display_name,
          'scope', case assignment.scope_kind
            when 'institution' then 'Instituição'
            when 'unit' then 'Unidade: ' || coalesce(unit_record.name, assignment.scope_unit_id::text)
            when 'group' then 'Turma: ' || coalesce(group_record.name, assignment.scope_group_id::text)
            else assignment.scope_kind
          end
        ) order by lower(person_record.display_name), assignment.id)
        from public.institution_role_assignments assignment
        join public.institution_memberships membership on membership.id = assignment.membership_id
        join public.people person_record on person_record.id = membership.person_id
        left join public.units unit_record on unit_record.id = assignment.scope_unit_id
        left join public.groups group_record on group_record.id = assignment.scope_group_id
        where assignment.role_id = role_record.id
          and assignment.status = 'active'
          and (assignment.expires_at is null or assignment.expires_at > now())
      ), '[]'::jsonb),
      'permissions', coalesce((
        select jsonb_agg(jsonb_build_object(
          'code', permission_record.code,
          'module', permission_record.module_code,
          'screen_code', coalesce(permission_record.screen_code, 'general'),
          'action_code', permission_record.action_code,
          'module_label', permission_record.module_label,
          'screen_label', permission_record.screen_label,
          'action_label', permission_record.action_label,
          'name', coalesce(permission_record.description, permission_record.action_label),
          'description', permission_record.description,
          'risk', permission_record.risk_level,
          'requires_mfa', permission_record.requires_mfa,
          'selected', grant_record.id is not null and grant_record.effect = 'allow',
          'grantable', actor_can_manage.allowed and coalesce(grant_record.effect, 'allow') <> 'deny',
          'inherited', false,
          'unavailable_reason', case
            when grant_record.effect = 'deny'
              then 'Uma negação explícita deve ser tratada separadamente.'
            when not actor_can_manage.allowed
              then 'Você não pode conceder permissões institucionais.'
            else null
          end
        ) order by permission_record.module_code, permission_record.screen_code,
          permission_record.action_code, permission_record.code)
        from public.institution_permissions permission_record
        cross join (
          select app_private.has_platform_permission('institution.roles.manage') as allowed
        ) actor_can_manage
        left join public.institution_role_permissions grant_record
          on grant_record.permission_id = permission_record.id
          and grant_record.role_id = role_record.id
          and grant_record.status = 'active'
          and grant_record.revoked_at is null
        where permission_record.status = 'active'
      ), '[]'::jsonb),
      'audit', case when can_read_audit then
        coalesce((
          select jsonb_agg(jsonb_build_object(
            'action', audit_record.action_code,
            'reason', audit_record.reason,
            'occurred_at', audit_record.occurred_at
          ) order by audit_record.occurred_at desc)
          from (
            select audit_row.action_code, audit_row.reason, audit_row.occurred_at
            from audit.audit_logs audit_row
            where audit_row.object_id = role_record.id
            order by audit_row.occurred_at desc
            limit 10
          ) audit_record
        ), '[]'::jsonb)
      else null end
    )
    into result
    from (
      select role_row.id, role_row.institution_id, role_row.code, role_row.name,
        role_row.description, role_row.status::text as status,
        role_row.max_scope_kind, role_row.version, role_row.is_system
      from public.institution_roles role_row
      where role_row.id = p_profile_id
      union all
      select null::uuid, null::uuid, '', '', '', 'active', 'institution', 0::bigint, false
      where p_profile_id is null
      limit 1
    ) role_record;

  else
    raise invalid_parameter_value using message = 'unsupported profile domain';
  end if;

  if result is null then
    raise no_data_found using message = 'access profile not found';
  end if;
  return result;
end
$$;

alter function app_private.access_profile_detail_v3(text, uuid) owner to postgres;
revoke all on function app_private.access_profile_detail_v3(text, uuid) from public, anon, authenticated;

comment on function app_private.access_profile_detail_v3(text, uuid) is
  'Detalhe rico de perfil de acesso (platform/institution) para o formulario do Superadmin: rascunho em branco quando p_profile_id e nulo, matriz completa de permissoes com selected/grantable, vinculos ativos e auditoria quando o ator pode le-la. Autoriza por require_profile_authority.';

-- Wrapper publico: mesma assinatura e ACL de producao, agora delegando a v3.
create or replace function public.superadmin_access_profile_detail(
  p_domain text,
  p_profile_id uuid
) returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select app_private.access_profile_detail_v3(p_domain, p_profile_id)
$$;

alter function public.superadmin_access_profile_detail(text, uuid) owner to postgres;
revoke all on function public.superadmin_access_profile_detail(text, uuid) from public, anon;
grant execute on function public.superadmin_access_profile_detail(text, uuid) to authenticated, service_role;
