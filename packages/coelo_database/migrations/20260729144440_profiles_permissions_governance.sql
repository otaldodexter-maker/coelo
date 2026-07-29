-- Reusable Superadmin/Admin access profiles and Principal capability summary.

alter table public.platform_roles
  add column if not exists max_scope_kind text not null default 'platform',
  add column if not exists version bigint not null default 1;
alter table public.platform_roles
  add constraint platform_roles_max_scope_check
    check (max_scope_kind in ('platform','institution')),
  add constraint platform_roles_version_check check (version > 0);

alter table public.institution_roles
  add column if not exists max_scope_kind text not null default 'institution',
  add column if not exists version bigint not null default 1;
alter table public.institution_roles
  add constraint institution_roles_max_scope_check
    check (max_scope_kind in ('institution','unit','group')),
  add constraint institution_roles_version_check check (version > 0);

insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status
) values
  ('platform.roles.manage','platform','roles','manage',
   'Gerenciar perfis de acesso do Superadmin.','critical',true,'active'),
  ('institution.roles.manage','institutions','roles','manage',
   'Gerenciar perfis administrativos institucionais.','critical',true,'active')
on conflict (code) do update set
  description=excluded.description,risk_level=excluded.risk_level,
  requires_mfa=true,status='active',updated_at=now();

insert into public.platform_role_permissions(
  role_id,permission_id,effect,conditions_json,status
)
select role_record.id,permission_record.id,'allow','{}','active'
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code='owner'
  and permission_record.code in ('platform.roles.manage','institution.roles.manage')
on conflict (role_id,permission_id) do update set
  effect='allow',status='active',revoked_at=null;

create table app_private.access_profile_command_receipts(
  request_id uuid primary key,
  actor_person_id uuid not null references public.people(id) on delete cascade,
  command_kind text not null check(command_kind in ('save','delete_and_reassign')),
  request_json jsonb not null,
  result_json jsonb not null,
  created_at timestamptz not null default now()
);
revoke all on app_private.access_profile_command_receipts from public,anon,authenticated;

create or replace function app_private.has_platform_permission(permission_code text)
returns boolean language sql stable security definer
set search_path=pg_catalog,public as $$
  with memberships as (
    select membership.id,membership.role_id
    from public.platform_memberships membership
    join public.platform_roles role_record on role_record.id=membership.role_id
    where membership.person_id=app_private.current_person_id()
      and membership.status='active' and membership.revoked_at is null
      and membership.scope_kind='platform'
      and membership.scope_institution_id is null
      and role_record.status='active'
  ), target as (
    select id from public.platform_permissions
    where code=permission_code and status='active'
  ), effects as (
    select grant_record.effect from memberships
    join public.platform_role_permissions grant_record
      on grant_record.role_id=memberships.role_id
     and grant_record.status='active' and grant_record.revoked_at is null
    join target on target.id=grant_record.permission_id
    union all
    select override_record.effect from memberships
    join public.platform_member_permission_overrides override_record
      on override_record.membership_id=memberships.id
     and override_record.status='active'
     and (override_record.starts_at is null or override_record.starts_at<=now())
     and (override_record.expires_at is null or override_record.expires_at>now())
    join target on target.id=override_record.permission_id
  )
  select exists(select 1 from effects where effect='allow')
     and not exists(select 1 from effects where effect='deny')
$$;

create or replace function app_private.access_scope_rank(value text)
returns integer language sql immutable set search_path=pg_catalog as $$
  select case value when 'platform' then 4 when 'institution' then 3
    when 'unit' then 2 when 'group' then 1 else -1 end
$$;

create or replace function app_private.validate_platform_profile_scope()
returns trigger language plpgsql set search_path=pg_catalog,public as $$
declare maximum text;
begin
  select max_scope_kind into maximum from public.platform_roles where id=new.role_id;
  if app_private.access_scope_rank(new.scope_kind)>
     app_private.access_scope_rank(maximum) then
    raise check_violation using message='membership scope exceeds profile maximum';
  end if;
  if (new.scope_kind='platform' and new.scope_institution_id is not null)
     or (new.scope_kind='institution' and new.scope_institution_id is null)
     or new.scope_kind not in ('platform','institution') then
    raise check_violation using message='inconsistent platform membership scope';
  end if;
  return new;
end $$;
create trigger platform_profile_scope_guard before insert or update of
  role_id,scope_kind,scope_institution_id on public.platform_memberships
  for each row execute function app_private.validate_platform_profile_scope();

create or replace function app_private.validate_institution_role_assignment()
returns trigger language plpgsql set search_path=pg_catalog,public as $$
declare membership_institution uuid; role_institution uuid; maximum text;
  unit_institution uuid; group_institution uuid; group_unit uuid;
begin
  select institution_id into membership_institution
    from public.institution_memberships where id=new.membership_id;
  select institution_id,max_scope_kind into role_institution,maximum
    from public.institution_roles where id=new.role_id;
  if role_institution is not null and role_institution<>membership_institution then
    raise check_violation using message='role and membership tenant mismatch';
  end if;
  if app_private.access_scope_rank(new.scope_kind)>
     app_private.access_scope_rank(maximum) then
    raise check_violation using message='assignment scope exceeds profile maximum';
  end if;
  if new.scope_unit_id is not null then
    select institution_id into unit_institution from public.units where id=new.scope_unit_id;
    if unit_institution<>membership_institution then
      raise check_violation using message='unit tenant mismatch';
    end if;
  end if;
  if new.scope_group_id is not null then
    select institution_id,unit_id into group_institution,group_unit
      from public.groups where id=new.scope_group_id;
    if group_institution<>membership_institution or group_unit is distinct from new.scope_unit_id then
      raise check_violation using message='group scope mismatch';
    end if;
  end if;
  return new;
end $$;

create or replace function app_private.require_profile_authority(domain text)
returns uuid language plpgsql stable security definer
set search_path=pg_catalog,public as $$
declare actor uuid:=app_private.current_person_id(); permission text;
begin
  permission:=case domain when 'platform' then 'platform.roles.manage'
    when 'institution' then 'institution.roles.manage'
    when 'principal' then 'platform.read' end;
  if actor is null or permission is null
     or not app_private.has_platform_permission(permission) then
    raise insufficient_privilege using message='profile management permission required';
  end if;
  return actor;
end $$;

create or replace function app_private.assert_full_authority_remains()
returns void language plpgsql security definer set search_path=pg_catalog,public as $$
begin
  if not exists(
    select 1 from public.platform_memberships membership
    join public.platform_roles role_record on role_record.id=membership.role_id
    where membership.status='active' and membership.revoked_at is null
      and membership.mfa_required and role_record.status='active'
      and membership.scope_kind='platform'
      and membership.scope_institution_id is null
      and not exists(
        select 1 from public.platform_member_permission_overrides override_record
        where override_record.membership_id=membership.id
          and override_record.effect='deny'
          and override_record.status='active'
          and (override_record.starts_at is null or override_record.starts_at<=now())
          and (override_record.expires_at is null or override_record.expires_at>now())
      )
      and not exists(
        select 1 from public.platform_role_permissions denied_grant
        where denied_grant.role_id=role_record.id
          and denied_grant.effect='deny'
          and denied_grant.status='active'
          and denied_grant.revoked_at is null
      )
      and not exists(
        select 1 from public.platform_permissions permission_record
        where permission_record.status='active' and not exists(
          select 1 from public.platform_role_permissions grant_record
          where grant_record.role_id=role_record.id
            and grant_record.permission_id=permission_record.id
            and grant_record.status='active' and grant_record.revoked_at is null
            and grant_record.effect='allow'
        )
      )
  ) then
    raise check_violation using
      message='active full-authority MFA replacement required';
  end if;
end $$;

create or replace function public.superadmin_access_profiles_list(
  p_domain text,p_search text,p_status text,p_scope text,p_page integer,p_page_size integer
) returns jsonb language plpgsql stable security definer
set search_path=pg_catalog,public as $$
declare result jsonb; page_no int:=greatest(coalesce(p_page,1),1);
  size_no int:=least(greatest(coalesce(p_page_size,10),1),100);
begin
  perform app_private.require_profile_authority(p_domain);
  if p_domain='platform' then
    with rows as (
      select role_record.id,role_record.code,role_record.name,role_record.description,
        role_record.status::text,role_record.max_scope_kind,role_record.version,
        role_record.is_system,count(membership.id)::int membership_count
      from public.platform_roles role_record left join public.platform_memberships membership
        on membership.role_id=role_record.id and membership.status='active'
      where (coalesce(btrim(p_search),'')='' or role_record.name ilike '%'||p_search||'%')
        and (p_status is null or role_record.status::text=any(string_to_array(p_status,',')))
        and (p_scope is null or role_record.max_scope_kind=any(string_to_array(p_scope,',')))
      group by role_record.id
    ), paged as (
      select * from rows order by lower(name) limit size_no offset (page_no-1)*size_no
    ) select jsonb_build_object('domain',p_domain,'items',coalesce(jsonb_agg(to_jsonb(paged)),'[]'),
      'page',page_no,'page_size',size_no,'total',(select count(*) from rows),'demo',false)
      into result from paged;
  elsif p_domain='institution' then
    with rows as (
      select role_record.id,role_record.institution_id,role_record.code,role_record.name,
        role_record.description,role_record.status::text,role_record.max_scope_kind,
        role_record.version,role_record.is_system,count(assignment.id)::int membership_count
      from public.institution_roles role_record
      left join public.institution_role_assignments assignment
        on assignment.role_id=role_record.id and assignment.status='active'
      where (coalesce(btrim(p_search),'')='' or role_record.name ilike '%'||p_search||'%')
        and (p_status is null or role_record.status::text=any(string_to_array(p_status,',')))
        and (p_scope is null or role_record.max_scope_kind=any(string_to_array(p_scope,',')))
      group by role_record.id
    ), paged as (
      select * from rows order by lower(name) limit size_no offset (page_no-1)*size_no
    ) select jsonb_build_object('domain',p_domain,'items',coalesce(jsonb_agg(to_jsonb(paged)),'[]'),
      'page',page_no,'page_size',size_no,'total',(select count(*) from rows),'demo',false)
      into result from paged;
  else raise invalid_parameter_value using message='unsupported profile domain';
  end if;
  return result;
end $$;

create or replace function public.superadmin_access_profile_detail(
  p_domain text,p_profile_id uuid
) returns jsonb language plpgsql stable security definer
set search_path=pg_catalog,public as $$
declare result jsonb;
begin
  perform app_private.require_profile_authority(p_domain);
  if p_domain='platform' then
    select jsonb_build_object('domain',p_domain,'id',coalesce(role_record.id::text,''),
      'code',coalesce(role_record.code,''),'name',coalesce(role_record.name,''),
      'description',coalesce(role_record.description,''),'status',coalesce(role_record.status::text,'active'),
      'max_scope_kind',coalesce(role_record.max_scope_kind,'platform'),
      'version',coalesce(role_record.version,0),'is_system',coalesce(role_record.is_system,false),
      'membership_count',(select count(*) from public.platform_memberships where role_id=role_record.id),
      'memberships',coalesce((select jsonb_agg(jsonb_build_object(
        'id',membership.id,'person_name',person_record.display_name,
        'scope',case when membership.scope_kind='platform' then 'Plataforma'
          else 'Instituição: '||membership.scope_institution_id::text end
      ) order by lower(person_record.display_name))
      from public.platform_memberships membership
      join public.people person_record on person_record.id=membership.person_id
      where membership.role_id=role_record.id and membership.status='active'
        and membership.revoked_at is null),'[]'),
      'permissions',coalesce((select jsonb_agg(jsonb_build_object(
        'code',permission_record.code,'module',permission_record.module_code,
        'name',permission_record.description,'description',permission_record.description,
        'risk',permission_record.risk_level,'requires_mfa',permission_record.requires_mfa,
        'selected',grant_record.id is not null and grant_record.effect='allow',
        'grantable',app_private.has_platform_permission(permission_record.code),
        'unavailable_reason',case when app_private.has_platform_permission(permission_record.code)
          then null else 'Você não pode conceder uma permissão que não possui.' end
      ) order by permission_record.module_code,permission_record.code)
      from public.platform_permissions permission_record
      left join public.platform_role_permissions grant_record
        on grant_record.permission_id=permission_record.id and grant_record.role_id=role_record.id
       and grant_record.status='active' and grant_record.revoked_at is null
      where permission_record.status='active'),'[]'),
      'audit',case when app_private.has_platform_permission('audit.read') then
        coalesce((select jsonb_agg(jsonb_build_object('action',audit_record.action_code,
          'reason',audit_record.reason,'occurred_at',audit_record.occurred_at)
          order by audit_record.occurred_at desc)
          from (select * from audit.audit_logs where object_id=role_record.id
            order by occurred_at desc limit 10) audit_record),'[]') else null end)
    into result from (select * from public.platform_roles where id=p_profile_id
      union all select null,null,null,null,'active',false,null,now(),now(),'platform',0
      where p_profile_id is null limit 1) role_record;
  elsif p_domain='institution' then
    select jsonb_build_object('domain',p_domain,'id',coalesce(role_record.id::text,''),
      'institution_id',role_record.institution_id,'code',coalesce(role_record.code,''),
      'name',coalesce(role_record.name,''),'description',coalesce(role_record.description,''),
      'status',coalesce(role_record.status::text,'active'),
      'max_scope_kind',coalesce(role_record.max_scope_kind,'institution'),
      'version',coalesce(role_record.version,0),'is_system',coalesce(role_record.is_system,false),
      'membership_count',(select count(*) from public.institution_role_assignments where role_id=role_record.id),
      'memberships',coalesce((select jsonb_agg(jsonb_build_object(
        'id',assignment.id,'person_name',person_record.display_name,
        'scope',case assignment.scope_kind
          when 'institution' then 'Instituição'
          when 'unit' then 'Unidade: '||assignment.scope_unit_id::text
          when 'group' then 'Grupo: '||assignment.scope_group_id::text end
      ) order by lower(person_record.display_name))
      from public.institution_role_assignments assignment
      join public.institution_memberships membership on membership.id=assignment.membership_id
      join public.people person_record on person_record.id=membership.person_id
      where assignment.role_id=role_record.id and assignment.status='active'
        and (assignment.expires_at is null or assignment.expires_at>now())),'[]'),
      'permissions',coalesce((select jsonb_agg(jsonb_build_object(
        'code',permission_record.code,'module',permission_record.module_code,
        'name',permission_record.description,'description',permission_record.description,
        'risk',permission_record.risk_level,'requires_mfa',permission_record.requires_mfa,
        'selected',grant_record.id is not null and grant_record.effect='allow',
        'grantable',app_private.has_platform_permission('institution.roles.manage')
          and coalesce(grant_record.effect,'allow')<>'deny',
        'unavailable_reason',case
          when grant_record.effect='deny' then 'Uma negação explícita deve ser tratada separadamente.'
          when not app_private.has_platform_permission('institution.roles.manage')
            then 'Você não pode conceder permissões institucionais.'
          else null end
      ) order by permission_record.module_code,permission_record.code)
      from public.institution_permissions permission_record
      left join public.institution_role_permissions grant_record
        on grant_record.permission_id=permission_record.id and grant_record.role_id=role_record.id
       and grant_record.status='active' and grant_record.revoked_at is null
      where permission_record.status='active'),'[]'),
      'audit',case when app_private.has_platform_permission('audit.read') then
        coalesce((select jsonb_agg(jsonb_build_object('action',audit_record.action_code,
          'reason',audit_record.reason,'occurred_at',audit_record.occurred_at)
          order by audit_record.occurred_at desc)
          from (select * from audit.audit_logs where object_id=role_record.id
            order by occurred_at desc limit 10) audit_record),'[]') else null end)
    into result from (select * from public.institution_roles where id=p_profile_id
      union all select null,null,null,null,null,false,'active',now(),now(),'institution',0
      where p_profile_id is null limit 1) role_record;
  else raise invalid_parameter_value using message='unsupported profile domain';
  end if;
  if result is null then raise no_data_found using message='access profile not found'; end if;
  return result;
end $$;

create or replace function public.superadmin_principal_capabilities_summary()
returns jsonb language plpgsql stable security definer
set search_path=pg_catalog,public as $$
begin
  perform app_private.require_profile_authority('principal');
  return (select jsonb_build_object('domain','principal','read_only',true,'demo',false,
    'items',coalesce(jsonb_agg(jsonb_build_object('id',capability.id,'code',capability.code,
      'name',capability.name,'description',capability.description,
      'context_count',(select count(distinct grant_record.guardian_context_permission_id)
        from public.guardian_context_permission_grants grant_record
        where grant_record.capability_id=capability.id and grant_record.status='active'
          and grant_record.revoked_at is null and grant_record.effect='allow'))
      order by capability.name),'[]'))
    from public.guardian_permission_capabilities capability where capability.status='active');
end $$;

create or replace function public.superadmin_access_profile_save(
  p_request_id uuid,p_expected_version bigint,p_reason text,p_draft jsonb
) returns jsonb language plpgsql volatile security definer
set search_path=pg_catalog,public as $$
declare actor uuid; domain text:=p_draft->>'domain'; profile_id uuid;
  current_version bigint; requested_permission_code text; result jsonb;
  before_data jsonb; prior_request jsonb;
  request_payload jsonb:=jsonb_build_object(
    'expected_version',p_expected_version,'reason',p_reason,'draft',p_draft
  );
begin
  if p_request_id is null or p_expected_version is null or btrim(coalesce(p_reason,''))='' then
    raise invalid_parameter_value using message='request, version and reason required';
  end if;
  if domain not in ('platform','institution')
     or btrim(coalesce(p_draft->>'code',''))=''
     or btrim(coalesce(p_draft->>'name',''))=''
     or jsonb_typeof(coalesce(p_draft->'permission_codes','[]'::jsonb))<>'array' then
    raise invalid_parameter_value using message='invalid profile draft';
  end if;
  actor:=app_private.require_profile_authority(domain);
  if not app_private.has_mfa_aal2() then raise insufficient_privilege using message='MFA AAL2 required'; end if;
  select result_json,request_json into result,prior_request
    from app_private.access_profile_command_receipts
    where request_id=p_request_id and actor_person_id=actor and command_kind='save';
  if result is not null then
    if prior_request<>request_payload then
      raise unique_violation using message='request id already used with different payload';
    end if;
    return result;
  end if;
  profile_id:=nullif(p_draft->>'id','')::uuid;
  if domain='platform' then
    for requested_permission_code in
      select jsonb_array_elements_text(coalesce(p_draft->'permission_codes','[]'))
    loop
      if not app_private.has_platform_permission(requested_permission_code) then
        raise insufficient_privilege using message='cannot grant permission operator does not hold';
      end if;
    end loop;
    if profile_id is null then
      if p_expected_version<>0 then raise serialization_failure using message='stale profile version'; end if;
      insert into public.platform_roles(code,name,description,status,is_system,created_by,max_scope_kind)
      values(lower(btrim(p_draft->>'code')),btrim(p_draft->>'name'),p_draft->>'description',
        coalesce(p_draft->>'status','active')::public.record_status,
        false,actor,p_draft->>'max_scope_kind')
      returning id,version into profile_id,current_version;
    else
      select role_record.version,
        to_jsonb(role_record)||jsonb_build_object(
          'permission_codes',coalesce((
            select jsonb_agg(permission_record.code order by permission_record.code)
            from public.platform_role_permissions grant_record
            join public.platform_permissions permission_record
              on permission_record.id=grant_record.permission_id
            where grant_record.role_id=role_record.id
              and grant_record.effect='allow' and grant_record.status='active'
              and grant_record.revoked_at is null
          ),'[]'::jsonb)
        )
        into current_version,before_data
        from public.platform_roles role_record where role_record.id=profile_id for update;
      if current_version is null then raise no_data_found using message='access profile not found'; end if;
      if current_version is distinct from p_expected_version then raise serialization_failure using message='stale profile version'; end if;
      if exists(
        select 1 from public.platform_memberships membership
        where membership.role_id=profile_id
          and membership.status='active' and membership.revoked_at is null
          and app_private.access_scope_rank(membership.scope_kind)>
            app_private.access_scope_rank(p_draft->>'max_scope_kind')
      ) then raise check_violation using message='profile scope is in use'; end if;
      update public.platform_roles set name=btrim(p_draft->>'name'),code=lower(btrim(p_draft->>'code')),
        description=p_draft->>'description',status=(p_draft->>'status')::public.record_status,
        max_scope_kind=p_draft->>'max_scope_kind',version=version+1,updated_at=now()
        where id=profile_id returning version into current_version;
    end if;
    if exists(
      select 1 from public.platform_role_permissions grant_record
      join public.platform_permissions permission_record on permission_record.id=grant_record.permission_id
      where grant_record.role_id=profile_id and grant_record.effect='deny'
        and grant_record.status='active' and grant_record.revoked_at is null
        and permission_record.code in(
          select jsonb_array_elements_text(coalesce(p_draft->'permission_codes','[]'))
        )
    ) then raise check_violation using message='explicit deny cannot be replaced by profile editor'; end if;
    update public.platform_role_permissions grant_record
      set status='inactive',revoked_at=now()
      where grant_record.role_id=profile_id and grant_record.effect='allow'
        and grant_record.status='active' and grant_record.revoked_at is null
        and grant_record.permission_id not in(
          select permission_record.id from public.platform_permissions permission_record
          where permission_record.code in(
            select jsonb_array_elements_text(coalesce(p_draft->'permission_codes','[]'))
          )
        );
    insert into public.platform_role_permissions(role_id,permission_id,effect,granted_by,status)
      select profile_id,permission_record.id,'allow',actor,'active'
      from public.platform_permissions permission_record
      where permission_record.status='active'
        and permission_record.code in(
          select jsonb_array_elements_text(coalesce(p_draft->'permission_codes','[]'))
        )
    on conflict(role_id,permission_id) do update set
      effect='allow',status='active',revoked_at=null,granted_by=actor;
    perform app_private.assert_full_authority_remains();
  elsif domain='institution' then
    if exists(
      select 1
      from jsonb_array_elements_text(coalesce(p_draft->'permission_codes','[]'))
        as requested(requested_permission_code)
      left join public.institution_permissions permission_record
        on permission_record.code=requested.requested_permission_code
       and permission_record.status='active'
      where permission_record.id is null
    ) then raise invalid_parameter_value using message='unknown or inactive permission'; end if;
    if profile_id is null then
      if p_expected_version<>0 then raise serialization_failure using message='stale profile version'; end if;
      insert into public.institution_roles(institution_id,code,name,description,status,is_system,max_scope_kind)
      values(nullif(p_draft->>'institution_id','')::uuid,lower(btrim(p_draft->>'code')),
        btrim(p_draft->>'name'),p_draft->>'description',
        coalesce(p_draft->>'status','active')::public.record_status,
        nullif(p_draft->>'institution_id','') is null,p_draft->>'max_scope_kind')
      returning id,version into profile_id,current_version;
    else
      select role_record.version,
        to_jsonb(role_record)||jsonb_build_object(
          'permission_codes',coalesce((
            select jsonb_agg(permission_record.code order by permission_record.code)
            from public.institution_role_permissions grant_record
            join public.institution_permissions permission_record
              on permission_record.id=grant_record.permission_id
            where grant_record.role_id=role_record.id
              and grant_record.effect='allow' and grant_record.status='active'
              and grant_record.revoked_at is null
          ),'[]'::jsonb)
        )
        into current_version,before_data
        from public.institution_roles role_record where role_record.id=profile_id for update;
      if current_version is null then raise no_data_found using message='access profile not found'; end if;
      if current_version is distinct from p_expected_version then raise serialization_failure using message='stale profile version'; end if;
      if exists(
        select 1 from public.institution_role_assignments assignment
        where assignment.role_id=profile_id and assignment.status='active'
          and (assignment.expires_at is null or assignment.expires_at>now())
          and app_private.access_scope_rank(assignment.scope_kind)>
            app_private.access_scope_rank(p_draft->>'max_scope_kind')
      ) then raise check_violation using message='profile scope is in use'; end if;
      update public.institution_roles set name=btrim(p_draft->>'name'),code=lower(btrim(p_draft->>'code')),
        description=p_draft->>'description',status=(p_draft->>'status')::public.record_status,
        max_scope_kind=p_draft->>'max_scope_kind',version=version+1,updated_at=now()
        where id=profile_id returning version into current_version;
    end if;
    if exists(
      select 1 from public.institution_role_permissions grant_record
      join public.institution_permissions permission_record on permission_record.id=grant_record.permission_id
      where grant_record.role_id=profile_id and grant_record.effect='deny'
        and grant_record.status='active' and grant_record.revoked_at is null
        and permission_record.code in(
          select jsonb_array_elements_text(coalesce(p_draft->'permission_codes','[]'))
        )
    ) then raise check_violation using message='explicit deny cannot be replaced by profile editor'; end if;
    update public.institution_role_permissions grant_record
      set status='inactive',revoked_at=now()
      where grant_record.role_id=profile_id and grant_record.effect='allow'
        and grant_record.status='active' and grant_record.revoked_at is null
        and grant_record.permission_id not in(
          select permission_record.id from public.institution_permissions permission_record
          where permission_record.code in(
            select jsonb_array_elements_text(coalesce(p_draft->'permission_codes','[]'))
          )
        );
    insert into public.institution_role_permissions(role_id,permission_id,effect,granted_by,status)
      select profile_id,permission_record.id,'allow',actor,'active'
      from public.institution_permissions permission_record
      where permission_record.status='active'
        and permission_record.code in(
          select jsonb_array_elements_text(coalesce(p_draft->'permission_codes','[]'))
        )
    on conflict(role_id,permission_id) do update set
      effect='allow',status='active',revoked_at=null,granted_by=actor;
  else raise invalid_parameter_value using message='unsupported profile domain'; end if;
  result:=public.superadmin_access_profile_detail(domain,profile_id);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    outcome,reason,before_json,after_json) values(actor,'aal2',
    case when domain='platform' then 'platform_permission_changed' else 'permission_changed' end,
    domain||'_access_profile',profile_id,'success',p_reason,
    before_data-'created_at'-'updated_at',
    (result-'memberships'-'permissions'-'audit')||jsonb_build_object(
      'permission_codes',coalesce((
        select jsonb_agg(permission_item->>'code' order by permission_item->>'code')
        from jsonb_array_elements(result->'permissions') permission_item
        where coalesce((permission_item->>'selected')::boolean,false)
      ),'[]'::jsonb)
    ));
  insert into app_private.access_profile_command_receipts(
    request_id,actor_person_id,command_kind,request_json,result_json
  ) values(p_request_id,actor,'save',request_payload,result);
  return result;
end $$;

create or replace function public.superadmin_access_profile_delete_and_reassign(
  p_request_id uuid,p_domain text,p_profile_id uuid,p_expected_version bigint,
  p_replacement_profile_id uuid,p_reason text
) returns jsonb language plpgsql volatile security definer
set search_path=pg_catalog,public as $$
declare actor uuid; current_version bigint; links bigint; result jsonb;
  before_data jsonb; prior_request jsonb;
  request_payload jsonb:=jsonb_build_object(
    'domain',p_domain,'profile_id',p_profile_id,'expected_version',p_expected_version,
    'replacement_profile_id',p_replacement_profile_id,'reason',p_reason
  );
begin
  if p_request_id is null or p_profile_id is null or p_expected_version is null
     or btrim(coalesce(p_reason,''))='' then
    raise invalid_parameter_value using message='request, profile, version and reason required';
  end if;
  actor:=app_private.require_profile_authority(p_domain);
  if not app_private.has_mfa_aal2() then raise insufficient_privilege using message='MFA AAL2 required'; end if;
  select result_json,request_json into result,prior_request
    from app_private.access_profile_command_receipts
   where request_id=p_request_id and actor_person_id=actor and command_kind='delete_and_reassign';
  if result is not null then
    if prior_request<>request_payload then
      raise unique_violation using message='request id already used with different payload';
    end if;
    return result;
  end if;
  if p_replacement_profile_id=p_profile_id then raise invalid_parameter_value using message='invalid replacement'; end if;
  if p_domain='platform' then
    select version,to_jsonb(platform_roles) into current_version,before_data from public.platform_roles where id=p_profile_id for update;
    if current_version is null then raise no_data_found using message='access profile not found'; end if;
    select count(*) into links from public.platform_memberships where role_id=p_profile_id;
    if links>0 and p_replacement_profile_id is null then raise check_violation using message='in-use profile requires reassignment'; end if;
    if p_replacement_profile_id is not null and not exists(select 1 from public.platform_roles where id=p_replacement_profile_id and status='active')
      then raise check_violation using message='active replacement required'; end if;
    if current_version is distinct from p_expected_version then raise serialization_failure using message='stale profile version'; end if;
    update public.platform_memberships set role_id=p_replacement_profile_id where role_id=p_profile_id;
    delete from public.platform_roles where id=p_profile_id;
    perform app_private.assert_full_authority_remains();
  elsif p_domain='institution' then
    select version,to_jsonb(institution_roles) into current_version,before_data from public.institution_roles where id=p_profile_id for update;
    if current_version is null then raise no_data_found using message='access profile not found'; end if;
    select count(*) into links from public.institution_role_assignments where role_id=p_profile_id;
    if links>0 and p_replacement_profile_id is null then raise check_violation using message='in-use profile requires reassignment'; end if;
    if p_replacement_profile_id is not null and not exists(select 1 from public.institution_roles replacement
      join public.institution_roles removed on removed.id=p_profile_id
      where replacement.id=p_replacement_profile_id and replacement.status='active'
        and (replacement.institution_id is null or replacement.institution_id=removed.institution_id)
        and not exists(select 1 from public.institution_role_assignments assignment where assignment.role_id=p_profile_id
          and app_private.access_scope_rank(assignment.scope_kind)>app_private.access_scope_rank(replacement.max_scope_kind)))
      then raise check_violation using message='incompatible replacement'; end if;
    if current_version is distinct from p_expected_version then raise serialization_failure using message='stale profile version'; end if;
    update public.institution_role_assignments set role_id=p_replacement_profile_id,updated_at=now() where role_id=p_profile_id;
    delete from public.institution_roles where id=p_profile_id;
  else raise invalid_parameter_value using message='unsupported profile domain'; end if;
  result:=jsonb_build_object('domain',p_domain,'deleted_profile_id',p_profile_id,
    'replacement_profile_id',p_replacement_profile_id,'reassigned_count',links);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    outcome,reason,before_json,after_json) values(actor,'aal2','membership_changed',
    p_domain||'_access_profile',p_profile_id,'success',p_reason,before_data,result);
  insert into app_private.access_profile_command_receipts(
    request_id,actor_person_id,command_kind,request_json,result_json
  ) values(p_request_id,actor,'delete_and_reassign',request_payload,result);
  return result;
end $$;

revoke all on function public.superadmin_access_profiles_list(text,text,text,text,integer,integer) from public,anon;
revoke all on function public.superadmin_access_profile_detail(text,uuid) from public,anon;
revoke all on function public.superadmin_access_profile_save(uuid,bigint,text,jsonb) from public,anon;
revoke all on function public.superadmin_access_profile_delete_and_reassign(uuid,text,uuid,bigint,uuid,text) from public,anon;
revoke all on function public.superadmin_principal_capabilities_summary() from public,anon;
grant execute on function public.superadmin_access_profiles_list(text,text,text,text,integer,integer) to authenticated;
grant execute on function public.superadmin_access_profile_detail(text,uuid) to authenticated;
grant execute on function public.superadmin_access_profile_save(uuid,bigint,text,jsonb) to authenticated;
grant execute on function public.superadmin_access_profile_delete_and_reassign(uuid,text,uuid,bigint,uuid,text) to authenticated;
grant execute on function public.superadmin_principal_capabilities_summary() to authenticated;

revoke all on function app_private.has_platform_permission(text) from public,anon;
grant execute on function app_private.has_platform_permission(text) to authenticated;
revoke all on function app_private.access_scope_rank(text) from public,anon;
grant execute on function app_private.access_scope_rank(text) to authenticated;
revoke all on function app_private.require_profile_authority(text) from public,anon,authenticated;
revoke all on function app_private.assert_full_authority_remains() from public,anon,authenticated;
