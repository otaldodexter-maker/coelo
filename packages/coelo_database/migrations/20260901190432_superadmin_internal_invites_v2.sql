begin;

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using
      message = 'internal invitations migration must run as postgres';
  end if;
  if to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure(
      'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)'
    ) is null
    or to_regprocedure(
      'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)'
    ) is null
    or to_regclass('public.invitations') is null then
    raise object_not_in_prerequisite_state using
      message = 'internal Auth, audit and invitation foundations are required';
  end if;
end
$preflight$;

insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,
  requires_mfa,status,module_label,screen_label,action_label
) values
  ('platform.invites.read','platform','invites','read',
    'Read the internal Superadmin invitation directory.','normal',false,'active',
    'Plataforma','Convites','Visualizar'),
  ('platform.invites.manage','platform','invites','manage',
    'Issue, resend and revoke invitations through the internal gateway.',
    'high',true,'active','Plataforma','Convites','Gerenciar')
on conflict(code) do update set
  module_code=excluded.module_code,
  screen_code=excluded.screen_code,
  action_code=excluded.action_code,
  description=excluded.description,
  risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa,
  status='active',
  module_label=excluded.module_label,
  screen_label=excluded.screen_label,
  action_label=excluded.action_label,
  updated_at=now();

update public.platform_role_permissions role_permission
set status='inactive',revoked_at=coalesce(role_permission.revoked_at,now())
from public.platform_permissions permission_record,
  public.platform_roles role_record
where permission_record.id=role_permission.permission_id
  and role_record.id=role_permission.role_id
  and permission_record.code in('platform.invites.read','platform.invites.manage')
  and role_record.code<>'owner'
  and (role_permission.status<>'inactive' or role_permission.revoked_at is null);

insert into public.platform_role_permissions(
  role_id,permission_id,effect,conditions_json,status,revoked_at
)
select role_record.id,permission_record.id,'allow','{}'::jsonb,'active',null
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code='owner'
  and role_record.status='active'
  and permission_record.code in('platform.invites.read','platform.invites.manage')
on conflict(role_id,permission_id) do update set
  effect='allow',conditions_json='{}'::jsonb,status='active',revoked_at=null;

alter table public.invitations
  add column if not exists invited_by_internal_identity_id uuid,
  add column if not exists profile_id uuid,
  add column if not exists channels text[],
  add column if not exists version bigint,
  add column if not exists updated_at timestamptz;

do $constraints$
begin
  if not exists(
    select 1 from pg_constraint
    where conrelid='public.invitations'::regclass
      and conname='invitations_internal_issuer_fkey'
  ) then
    alter table public.invitations
      add constraint invitations_internal_issuer_fkey
      foreign key(invited_by_internal_identity_id)
      references app_private.superadmin_internal_identities(id)
      on delete restrict;
  end if;
  if not exists(
    select 1 from pg_constraint
    where conrelid='public.invitations'::regclass
      and conname='invitations_profile_id_fkey'
  ) then
    alter table public.invitations
      add constraint invitations_profile_id_fkey
      foreign key(profile_id) references public.institution_roles(id)
      on delete restrict;
  end if;
  if not exists(
    select 1 from pg_constraint
    where conrelid='public.invitations'::regclass
      and conname='invitations_single_issuer_realm_check'
  ) then
    alter table public.invitations
      add constraint invitations_single_issuer_realm_check
      check(not(invited_by is not null and invited_by_internal_identity_id is not null));
  end if;
  if not exists(
    select 1 from pg_constraint
    where conrelid='public.invitations'::regclass
      and conname='invitations_internal_channels_check'
  ) then
    alter table public.invitations
      add constraint invitations_internal_channels_check check(
        channels is null or(
          cardinality(channels) between 1 and 2
          and channels <@ array['email','link']::text[]
          and(cardinality(channels)=1 or channels[1]<>channels[2])
        )
      );
  end if;
  if not exists(
    select 1 from pg_constraint
    where conrelid='public.invitations'::regclass
      and conname='invitations_internal_version_check'
  ) then
    alter table public.invitations
      add constraint invitations_internal_version_check
      check(version is null or version>0);
  end if;
end
$constraints$;

create index if not exists invitations_internal_issuer_idx
  on public.invitations(invited_by_internal_identity_id,created_at desc)
  where invited_by_internal_identity_id is not null;
create index if not exists invitations_internal_directory_idx
  on public.invitations(institution_id,invitation_state,created_at desc,id desc);
create index if not exists invitations_internal_profile_idx
  on public.invitations(profile_id,created_at desc)
  where profile_id is not null;

alter table public.invitations enable row level security;
revoke all on public.invitations from anon;
revoke insert,update,delete,truncate,references,trigger
  on public.invitations from authenticated;
grant select on public.invitations to authenticated;

create table app_private.superadmin_internal_invite_receipts(
  request_id uuid primary key,
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id),
  internal_auth_link_id uuid not null
    references app_private.superadmin_internal_auth_links(id),
  internal_membership_id uuid not null
    references app_private.superadmin_internal_memberships(id),
  command_kind text not null check(command_kind in('issue','resend','revoke')),
  invitation_id uuid not null references public.invitations(id) on delete restrict,
  request_hash bytea not null check(octet_length(request_hash)=32),
  result_json jsonb not null,
  created_at timestamptz not null default now()
);

create index superadmin_internal_invite_receipts_actor_idx
  on app_private.superadmin_internal_invite_receipts(
    internal_identity_id,created_at desc
  );
create index superadmin_internal_invite_receipts_invitation_idx
  on app_private.superadmin_internal_invite_receipts(invitation_id,created_at desc);
alter table app_private.superadmin_internal_invite_receipts enable row level security;
alter table app_private.superadmin_internal_invite_receipts force row level security;
revoke all on app_private.superadmin_internal_invite_receipts
  from public,anon,authenticated,service_role;

create function app_private.superadmin_invite_error_envelope_v2(
  p_code text,p_correlation_id uuid
) returns jsonb
language sql
immutable
security invoker
set search_path=''
as $$
  select jsonb_build_object(
    'ok',false,
    'data',null,
    'error',jsonb_build_object(
      'code',case when p_code in(
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED','SAI_CONCURRENT_CHANGE',
        'SAI_INVALID_ARGUMENT'
      ) then p_code else 'SAI_INTERNAL_ERROR' end,
      'message',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID')
          then 'Autenticação necessária.'
        when p_code='SAI_MFA_REQUIRED' then 'Confirme o segundo fator.'
        when p_code='SAI_CONCURRENT_CHANGE'
          then 'O estado mudou. Recarregue e tente novamente.'
        when p_code='SAI_INVALID_ARGUMENT' then 'Revise os dados informados.'
        when p_code like 'SAI_%DENIED' or p_code like 'SAI_MEMBERSHIP_%'
          then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'correlation_id',p_correlation_id,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code='SAI_CONCURRENT_CHANGE' then 409
        when p_code='SAI_INVALID_ARGUMENT' then 422
        when p_code in(
          'SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED'
        ) then 403 else 500 end
    )
  )
$$;

create function app_private.superadmin_invite_payload_v2(p_invite_id uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'id',invitation.id,
    'scope_kind',invitation.scope_kind,
    'institution_id',invitation.institution_id,
    'unit_id',invitation.unit_id,
    'group_id',invitation.group_id,
    'scope_label',concat_ws(' · ',institution.public_name,unit_record.name,group_record.name),
    'profile_id',coalesce(invitation.profile_id::text,'legacy'),
    'profile_label',coalesce(profile_record.name,invitation.role_code,'Perfil legado'),
    'recipient_label',case when invitation.target_person_id is not null
      then 'Pessoa vinculada' end,
    'recipient_masked',invitation.masked_destination,
    'channels',to_jsonb(coalesce(invitation.channels,'{}'::text[])),
    'status',case
      when invitation.invitation_state='pending' and invitation.expires_at<=now()
        then 'expired'
      else invitation.invitation_state::text end,
    'issuer',case
      when invitation.invited_by_internal_identity_id is not null then
        jsonb_build_object('kind','superadmin_internal','display','Usuário interno')
      when invitation.invited_by is not null then
        jsonb_build_object('kind','legacy_person','display','Emissor institucional')
      else jsonb_build_object('kind','unknown','display','Emissor não informado') end,
    'created_at',invitation.created_at,
    'expires_at',invitation.expires_at,
    'accepted_at',invitation.accepted_at,
    'revoked_at',invitation.revoked_at,
    'email_delivery_status','not_requested',
    'management_version',coalesce(invitation.version,0),
    'timeline',jsonb_build_array(jsonb_build_object(
      'label','Convite criado','occurred_at',invitation.created_at
    ))
      || case when invitation.last_sent_at is not null then jsonb_build_array(
        jsonb_build_object('label','Convite reenviado','occurred_at',invitation.last_sent_at)
      ) else '[]'::jsonb end
      || case when invitation.accepted_at is not null then jsonb_build_array(
        jsonb_build_object('label','Convite aceito','occurred_at',invitation.accepted_at)
      ) else '[]'::jsonb end
      || case when invitation.revoked_at is not null then jsonb_build_array(
        jsonb_build_object('label','Convite revogado','occurred_at',invitation.revoked_at)
      ) else '[]'::jsonb end
  )
  from public.invitations invitation
  join public.institutions institution on institution.id=invitation.institution_id
  left join public.units unit_record on unit_record.id=invitation.unit_id
  left join public.groups group_record on group_record.id=invitation.group_id
  left join public.institution_roles profile_record on profile_record.id=invitation.profile_id
  where invitation.id=p_invite_id
$$;

create function app_private.superadmin_invite_directory_payload_v2(
  p_search text,p_statuses text[],p_channels text[],p_institution_ids uuid[],
  p_unit_ids uuid[],p_group_ids uuid[],p_profile_ids uuid[],
  p_created_from timestamptz,p_created_to timestamptz,p_limit integer,
  p_offset integer,p_sort_ascending boolean
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare result jsonb;
begin
  if length(coalesce(p_search,''))>120
    or p_limit not in(8,11,20,50,100)
    or p_offset<0 or p_offset>10000
    or not(coalesce(p_statuses,'{}'::text[])
      <@ array['pending','accepted','expired','revoked']::text[])
    or not(coalesce(p_channels,'{}'::text[]) <@ array['email','link']::text[])
    or p_created_from>p_created_to then
    raise invalid_parameter_value using
      message='invalid invitation directory query',detail='SAI_INVALID_ARGUMENT';
  end if;

  with filtered as(
    select invitation.id,invitation.created_at,
      case when invitation.invitation_state='pending' and invitation.expires_at<=now()
        then 'expired' else invitation.invitation_state::text end as effective_status
    from public.invitations invitation
    join public.institutions institution on institution.id=invitation.institution_id
    left join public.units unit_record on unit_record.id=invitation.unit_id
    left join public.groups group_record on group_record.id=invitation.group_id
    left join public.institution_roles profile_record on profile_record.id=invitation.profile_id
    where(p_search is null or btrim(p_search)=''
      or institution.public_name ilike '%'||btrim(p_search)||'%'
      or coalesce(unit_record.name,'') ilike '%'||btrim(p_search)||'%'
      or coalesce(group_record.name,'') ilike '%'||btrim(p_search)||'%'
      or coalesce(profile_record.name,invitation.role_code,'') ilike '%'||btrim(p_search)||'%'
      or coalesce(invitation.masked_destination,'') ilike '%'||btrim(p_search)||'%')
      and(p_institution_ids is null or invitation.institution_id=any(p_institution_ids))
      and(p_unit_ids is null or invitation.unit_id=any(p_unit_ids))
      and(p_group_ids is null or invitation.group_id=any(p_group_ids))
      and(p_profile_ids is null or invitation.profile_id=any(p_profile_ids))
      and(p_channels is null or invitation.channels&&p_channels)
      and(p_created_from is null or invitation.created_at>=p_created_from)
      and(p_created_to is null or invitation.created_at<=p_created_to)
  ), status_filtered as(
    select * from filtered
    where p_statuses is null or effective_status=any(p_statuses)
  ), page_rows as(
    select * from status_filtered
    order by
      case when p_sort_ascending then created_at end asc,
      case when p_sort_ascending then id end asc,
      case when not p_sort_ascending then created_at end desc,
      case when not p_sort_ascending then id end desc
    limit p_limit offset p_offset
  )
  select jsonb_build_object(
    'items',coalesce((select jsonb_agg(
      app_private.superadmin_invite_payload_v2(page_rows.id)
      order by case when p_sort_ascending then page_rows.created_at end asc,
        case when not p_sort_ascending then page_rows.created_at end desc
    ) from page_rows),'[]'::jsonb),
    'total_count',(select count(*) from status_filtered)
  ) into result;
  return result;
end
$$;

create function app_private.superadmin_invite_options_payload_v2(
  p_search text,p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_limit integer
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare result jsonb;
begin
  if length(coalesce(p_search,''))>120 or p_limit<1 or p_limit>100 then
    raise invalid_parameter_value using
      message='invalid invitation options query',detail='SAI_INVALID_ARGUMENT';
  end if;
  if p_unit_id is not null and not exists(
    select 1 from public.units unit_record
    where unit_record.id=p_unit_id and unit_record.institution_id=p_institution_id
  ) or p_group_id is not null and not exists(
    select 1 from public.groups group_record
    where group_record.id=p_group_id and group_record.unit_id=p_unit_id
      and group_record.institution_id=p_institution_id
  ) then
    raise insufficient_privilege using
      message='invitation options denied',detail='SAI_PERMISSION_DENIED';
  end if;

  select jsonb_build_object(
    'scopes',coalesce((
      select jsonb_agg(scope_record.payload order by scope_record.label)
      from(
        select institution.public_name label,jsonb_build_object(
          'scope_kind','institution','institution_id',institution.id,
          'unit_id',null,'group_id',null,'label',institution.public_name
        ) payload
        from public.institutions institution
        where institution.status='active'
          and(p_institution_id is null or institution.id=p_institution_id)
          and(p_search is null or institution.public_name ilike '%'||btrim(p_search)||'%')
        union all
        select unit_record.name,jsonb_build_object(
          'scope_kind','unit','institution_id',unit_record.institution_id,
          'unit_id',unit_record.id,'group_id',null,'label',unit_record.name
        )
        from public.units unit_record
        where unit_record.status='active'
          and(p_institution_id is null or unit_record.institution_id=p_institution_id)
          and(p_unit_id is null or unit_record.id=p_unit_id)
          and(p_search is null or unit_record.name ilike '%'||btrim(p_search)||'%')
        union all
        select group_record.name,jsonb_build_object(
          'scope_kind','group','institution_id',group_record.institution_id,
          'unit_id',group_record.unit_id,'group_id',group_record.id,
          'label',group_record.name
        )
        from public.groups group_record
        where group_record.status='active'
          and(p_institution_id is null or group_record.institution_id=p_institution_id)
          and(p_unit_id is null or group_record.unit_id=p_unit_id)
          and(p_group_id is null or group_record.id=p_group_id)
          and(p_search is null or group_record.name ilike '%'||btrim(p_search)||'%')
        limit p_limit
      ) scope_record
    ),'[]'::jsonb),
    'profiles',coalesce((
      select jsonb_agg(jsonb_build_object(
        'profile_id',profile_record.id,'label',profile_record.name,
        'institution_id',coalesce(profile_record.institution_id,p_institution_id),
        'unit_id',null,'group_id',null
      ) order by profile_record.name)
      from(
        select profile.*
        from public.institution_roles profile
        where profile.status='active'
          and p_institution_id is not null
          and(profile.institution_id=p_institution_id
            or profile.institution_id is null)
          and(p_search is null or profile.name ilike '%'||btrim(p_search)||'%')
        order by profile.name,profile.id
        limit p_limit
      ) profile_record
    ),'[]'::jsonb),
    'recipients',coalesce((
      select jsonb_agg(jsonb_build_object(
        'person_id',person_record.id,'label',person_record.display_name,
        'masked_email',contact_record.masked_value
      ) order by person_record.display_name)
      from(
        select person.*
        from public.people person
        where person.status='active' and person.person_type='adult'
          and(p_search is null or person.display_name ilike '%'||btrim(p_search)||'%')
        order by person.display_name,person.id
        limit p_limit
      ) person_record
      left join lateral(
        select contact.masked_value
        from public.person_contacts contact
        where contact.person_id=person_record.id
          and contact.contact_type='email' and contact.status='active'
        order by contact.verified_at desc nulls last,contact.created_at desc limit 1
      ) contact_record on true
    ),'[]'::jsonb)
  ) into result;
  return result;
end
$$;

revoke all on function app_private.superadmin_invite_error_envelope_v2(text,uuid)
  from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_invite_payload_v2(uuid)
  from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_invite_directory_payload_v2(
  text,text[],text[],uuid[],uuid[],uuid[],uuid[],timestamptz,timestamptz,
  integer,integer,boolean
) from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_invite_options_payload_v2(
  text,uuid,uuid,uuid,integer
) from public,anon,authenticated,service_role;

create function public.superadmin_invite_directory_v2(
  p_search text default null,p_statuses text[] default null,
  p_channels text[] default null,p_institution_ids uuid[] default null,
  p_unit_ids uuid[] default null,p_group_ids uuid[] default null,
  p_profile_ids uuid[] default null,p_created_from timestamptz default null,
  p_created_to timestamptz default null,p_limit integer default 8,
  p_offset integer default 0,p_sort_ascending boolean default false
) returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context;
  correlation uuid:=gen_random_uuid(); result jsonb; error_code text; error_detail text;
begin
  begin
    select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.invites.read');
    if ctx.platform_role_code<>'owner' or ctx.scope_kind<>'platform'
      or ctx.scope_institution_id is not null then
      raise insufficient_privilege using
        message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    result:=app_private.superadmin_invite_directory_payload_v2(
      p_search,p_statuses,p_channels,p_institution_ids,p_unit_ids,p_group_ids,
      p_profile_ids,p_created_from,p_created_to,p_limit,p_offset,p_sort_ascending);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail like 'SAI_%' then error_detail
        else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
    when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'platform.invites.read','invite.directory',error_code,correlation,null);
    return app_private.superadmin_invite_error_envelope_v2(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'platform.invites.read',ctx.aal,'invite.directory','success',
    null,correlation);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

create function public.superadmin_invite_options_v2(
  p_search text default null,p_institution_id uuid default null,
  p_unit_id uuid default null,p_group_id uuid default null,p_limit integer default 25
) returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context;
  correlation uuid:=gen_random_uuid(); result jsonb; error_code text; error_detail text;
begin
  begin
    select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.invites.manage');
    if ctx.platform_role_code<>'owner' or ctx.scope_kind<>'platform'
      or ctx.scope_institution_id is not null then
      raise insufficient_privilege using
        message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    result:=app_private.superadmin_invite_options_payload_v2(
      p_search,p_institution_id,p_unit_id,p_group_id,p_limit);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail like 'SAI_%' then error_detail
        else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
    when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'platform.invites.manage','invite.options',error_code,correlation,null);
    return app_private.superadmin_invite_error_envelope_v2(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'platform.invites.manage',ctx.aal,'invite.options','success',
    null,correlation);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

create function public.superadmin_invite_detail_v2(p_invite_id uuid)
returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context;
  correlation uuid:=gen_random_uuid(); result jsonb; error_code text; error_detail text;
  result_institution_id uuid;
begin
  begin
    select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.invites.read');
    if ctx.platform_role_code<>'owner' or ctx.scope_kind<>'platform'
      or ctx.scope_institution_id is not null or p_invite_id is null then
      raise insufficient_privilege using
        message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    result:=app_private.superadmin_invite_payload_v2(p_invite_id);
    if result is null then
      raise insufficient_privilege using
        message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    result_institution_id:=(result->>'institution_id')::uuid;
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail like 'SAI_%' then error_detail
        else 'SAI_INTERNAL_ERROR' end;
    when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'platform.invites.read','invite.detail',error_code,correlation,null);
    return app_private.superadmin_invite_error_envelope_v2(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'platform.invites.read',ctx.aal,'invite.detail','success',null,
    correlation,result_institution_id,'invitation',p_invite_id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

create function public.superadmin_invite_issue_v2(
  p_request_id uuid,p_institution_id uuid,p_unit_id uuid,p_group_id uuid,
  p_profile_id uuid,p_target_person_id uuid,p_recipient_email text,
  p_channels text[],p_expires_in_hours integer
) returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
  normalized_channels text[]; normalized_email text; target_hash text;
  masked_destination text; clear_token text; stored_token_hash text;
  request_hash bytea; invitation_id uuid:=gen_random_uuid(); invite_payload jsonb;
  result jsonb; receipt app_private.superadmin_internal_invite_receipts%rowtype;
  scope_kind text; profile_code text;
begin
  begin
    select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.invites.manage');
    if ctx.platform_role_code<>'owner' or ctx.scope_kind<>'platform'
      or ctx.scope_institution_id is not null then
      raise insufficient_privilege using
        message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    select array_agg(distinct channel order by channel)
      into normalized_channels from unnest(p_channels) channel;
    normalized_email:=lower(btrim(p_recipient_email));
    if p_request_id is null or p_institution_id is null or p_profile_id is null
      or p_expires_in_hours not between 1 and 168
      or normalized_channels is null or cardinality(normalized_channels) not between 1 and 2
      or not(normalized_channels <@ array['email','link']::text[])
      or ((p_target_person_id is null)=(normalized_email is null or normalized_email=''))
      or (normalized_email is not null and(
        length(normalized_email)>254
        or normalized_email!~'^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
      )) then
      raise invalid_parameter_value using
        message='invalid invitation issue request',detail='SAI_INVALID_ARGUMENT';
    end if;
    scope_kind:=case when p_group_id is not null then 'group'
      when p_unit_id is not null then 'unit' else 'institution' end;
    if not exists(select 1 from public.institutions institution
      where institution.id=p_institution_id and institution.status='active')
      or (p_unit_id is not null and not exists(select 1 from public.units unit_record
        where unit_record.id=p_unit_id and unit_record.institution_id=p_institution_id
          and unit_record.status='active'))
      or (p_group_id is not null and(p_unit_id is null or not exists(
        select 1 from public.groups group_record where group_record.id=p_group_id
          and group_record.unit_id=p_unit_id
          and group_record.institution_id=p_institution_id
          and group_record.status='active'))) then
      raise insufficient_privilege using
        message='invitation hierarchy denied',detail='SAI_PERMISSION_DENIED';
    end if;
    select profile_record.code into profile_code
    from public.institution_roles profile_record
    where profile_record.id=p_profile_id and profile_record.status='active'
      and(profile_record.institution_id=p_institution_id
        or profile_record.institution_id is null)
      and app_private.access_scope_rank(scope_kind)
        <=app_private.access_scope_rank(profile_record.max_scope_kind);
    if profile_code is null or(p_target_person_id is not null and not exists(
      select 1 from public.people person_record
      where person_record.id=p_target_person_id and person_record.status='active'
        and person_record.person_type='adult'
    )) then
      raise insufficient_privilege using
        message='invitation target denied',detail='SAI_PERMISSION_DENIED';
    end if;

    request_hash:=extensions.digest(convert_to(jsonb_build_object(
      'institution_id',p_institution_id,'unit_id',p_unit_id,'group_id',p_group_id,
      'profile_id',p_profile_id,'target_person_id',p_target_person_id,
      'recipient_email',normalized_email,'channels',normalized_channels,
      'expires_in_hours',p_expires_in_hours
    )::text,'UTF8'),'sha256');
    select * into receipt from app_private.superadmin_internal_invite_receipts
      where request_id=p_request_id for update;
    if receipt.request_id is not null then
      if receipt.internal_identity_id<>ctx.internal_identity_id
        or receipt.command_kind<>'issue' or receipt.request_hash<>request_hash then
        raise serialization_failure using
          message='invitation request conflict',detail='SAI_CONCURRENT_CHANGE';
      end if;
      result:=receipt.result_json||jsonb_build_object('replayed',true,'link',null);
    else
      clear_token:=encode(gen_random_bytes(32),'hex');
      stored_token_hash:=encode(extensions.digest(convert_to(clear_token,'UTF8'),'sha256'),'hex');
      if normalized_email is not null then
        target_hash:=encode(extensions.digest(convert_to(normalized_email,'UTF8'),'sha256'),'hex');
        masked_destination:=left(normalized_email,1)||'***@'||split_part(normalized_email,'@',2);
      end if;
      insert into public.invitations(
        id,scope_kind,institution_id,unit_id,group_id,target_person_id,role_code,
        token_hash,expires_at,status,invitation_state,invited_by,
        invited_by_internal_identity_id,target_contact_hash,masked_destination,
        send_count,profile_id,channels,version,updated_at
      ) values(
        invitation_id,scope_kind,p_institution_id,p_unit_id,p_group_id,
        p_target_person_id,profile_code,stored_token_hash,
        now()+make_interval(hours=>p_expires_in_hours),'active','pending',null,
        ctx.internal_identity_id,target_hash,masked_destination,0,p_profile_id,
        normalized_channels,1,now()
      );
      invite_payload:=app_private.superadmin_invite_payload_v2(invitation_id);
      result:=jsonb_build_object(
        'invite',invite_payload,'replayed',false,
        'link','https://app.coelo.me/convites/'||clear_token
      );
      insert into app_private.superadmin_internal_invite_receipts(
        request_id,internal_identity_id,internal_auth_link_id,
        internal_membership_id,command_kind,invitation_id,request_hash,result_json
      ) values(
        p_request_id,ctx.internal_identity_id,ctx.internal_auth_link_id,
        ctx.internal_membership_id,'issue',invitation_id,request_hash,
        jsonb_build_object('invite',invite_payload,'replayed',false,'link',null)
      );
    end if;
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail like 'SAI_%' then error_detail
        else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation or foreign_key_violation
      then error_code:='SAI_INVALID_ARGUMENT';
    when serialization_failure or unique_violation then
      error_code:='SAI_CONCURRENT_CHANGE';
    when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'platform.invites.manage','invite.issue',error_code,correlation,null);
    return app_private.superadmin_invite_error_envelope_v2(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'platform.invites.manage',ctx.aal,'invite.issue','success',null,
    correlation,p_institution_id,'invitation',
    (result#>>'{invite,id}')::uuid);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

create function public.superadmin_invite_resend_v2(
  p_invite_id uuid,p_request_id uuid,p_expected_version bigint
) returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
  invitation_record public.invitations%rowtype; request_hash bytea;
  clear_token text; result jsonb; payload jsonb;
  receipt app_private.superadmin_internal_invite_receipts%rowtype;
begin
  begin
    select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.invites.manage');
    if ctx.platform_role_code<>'owner' or ctx.scope_kind<>'platform'
      or ctx.scope_institution_id is not null then
      raise insufficient_privilege using
        message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    if p_invite_id is null or p_request_id is null or p_expected_version<=0 then
      raise invalid_parameter_value using
        message='invalid invitation resend request',detail='SAI_INVALID_ARGUMENT';
    end if;
    request_hash:=extensions.digest(convert_to(jsonb_build_object(
      'invitation_id',p_invite_id,'expected_version',p_expected_version
    )::text,'UTF8'),'sha256');
    select * into receipt from app_private.superadmin_internal_invite_receipts
      where request_id=p_request_id for update;
    if receipt.request_id is not null then
      if receipt.internal_identity_id<>ctx.internal_identity_id
        or receipt.command_kind<>'resend' or receipt.request_hash<>request_hash then
        raise serialization_failure using
          message='invitation request conflict',detail='SAI_CONCURRENT_CHANGE';
      end if;
      result:=receipt.result_json||jsonb_build_object('replayed',true,'link',null);
    else
      select * into invitation_record from public.invitations invitation
        where invitation.id=p_invite_id for update;
      if invitation_record.id is null
        or invitation_record.invited_by_internal_identity_id is null then
        raise insufficient_privilege using
          message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
      end if;
      if invitation_record.version is distinct from p_expected_version then
        raise serialization_failure using
          message='invitation version conflict',detail='SAI_CONCURRENT_CHANGE';
      end if;
      if not(invitation_record.invitation_state='expired'
        or(invitation_record.invitation_state='pending'
          and invitation_record.expires_at<=now())) then
        raise invalid_parameter_value using
          message='invitation cannot be resent',detail='SAI_INVALID_ARGUMENT';
      end if;
      clear_token:=encode(gen_random_bytes(32),'hex');
      update public.invitations set
        token_hash=encode(extensions.digest(convert_to(clear_token,'UTF8'),'sha256'),'hex'),
        invitation_state='pending',status='active',expires_at=now()+interval '48 hours',
        accepted_at=null,accepted_by=null,revoked_at=null,last_sent_at=now(),
        send_count=send_count+1,version=version+1,updated_at=now()
      where id=p_invite_id returning * into invitation_record;
      payload:=app_private.superadmin_invite_payload_v2(p_invite_id);
      result:=jsonb_build_object('invite',payload,'replayed',false,
        'link','https://app.coelo.me/convites/'||clear_token);
      insert into app_private.superadmin_internal_invite_receipts(
        request_id,internal_identity_id,internal_auth_link_id,
        internal_membership_id,command_kind,invitation_id,request_hash,result_json
      ) values(
        p_request_id,ctx.internal_identity_id,ctx.internal_auth_link_id,
        ctx.internal_membership_id,'resend',p_invite_id,request_hash,
        jsonb_build_object('invite',payload,'replayed',false,'link',null)
      );
    end if;
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail like 'SAI_%' then error_detail
        else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation then error_code:='SAI_INVALID_ARGUMENT';
    when serialization_failure or unique_violation then error_code:='SAI_CONCURRENT_CHANGE';
    when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'platform.invites.manage','invite.resend',error_code,correlation,null);
    return app_private.superadmin_invite_error_envelope_v2(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'platform.invites.manage',ctx.aal,'invite.resend','success',null,
    correlation,(result#>>'{invite,institution_id}')::uuid,'invitation',p_invite_id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

create function public.superadmin_invite_revoke_v2(
  p_invite_id uuid,p_request_id uuid,p_expected_version bigint,p_reason text
) returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
  invitation_record public.invitations%rowtype; request_hash bytea;
  result jsonb; payload jsonb;
  receipt app_private.superadmin_internal_invite_receipts%rowtype;
begin
  begin
    select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.invites.manage');
    if ctx.platform_role_code<>'owner' or ctx.scope_kind<>'platform'
      or ctx.scope_institution_id is not null then
      raise insufficient_privilege using
        message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    if p_invite_id is null or p_request_id is null or p_expected_version<=0
      or length(btrim(coalesce(p_reason,''))) not between 3 and 240 then
      raise invalid_parameter_value using
        message='invalid invitation revoke request',detail='SAI_INVALID_ARGUMENT';
    end if;
    request_hash:=extensions.digest(convert_to(jsonb_build_object(
      'invitation_id',p_invite_id,'expected_version',p_expected_version,
      'reason',btrim(p_reason)
    )::text,'UTF8'),'sha256');
    select * into receipt from app_private.superadmin_internal_invite_receipts
      where request_id=p_request_id for update;
    if receipt.request_id is not null then
      if receipt.internal_identity_id<>ctx.internal_identity_id
        or receipt.command_kind<>'revoke' or receipt.request_hash<>request_hash then
        raise serialization_failure using
          message='invitation request conflict',detail='SAI_CONCURRENT_CHANGE';
      end if;
      result:=receipt.result_json||jsonb_build_object('replayed',true,'link',null);
    else
      select * into invitation_record from public.invitations invitation
        where invitation.id=p_invite_id for update;
      if invitation_record.id is null
        or invitation_record.invited_by_internal_identity_id is null then
        raise insufficient_privilege using
          message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
      end if;
      if invitation_record.version is distinct from p_expected_version then
        raise serialization_failure using
          message='invitation version conflict',detail='SAI_CONCURRENT_CHANGE';
      end if;
      if invitation_record.invitation_state<>'pending'
        or invitation_record.expires_at<=now() then
        raise invalid_parameter_value using
          message='invitation cannot be revoked',detail='SAI_INVALID_ARGUMENT';
      end if;
      update public.invitations set
        invitation_state='revoked',status='inactive',revoked_at=now(),
        version=version+1,updated_at=now()
      where id=p_invite_id returning * into invitation_record;
      payload:=app_private.superadmin_invite_payload_v2(p_invite_id);
      result:=jsonb_build_object('invite',payload,'replayed',false,'link',null);
      insert into app_private.superadmin_internal_invite_receipts(
        request_id,internal_identity_id,internal_auth_link_id,
        internal_membership_id,command_kind,invitation_id,request_hash,result_json
      ) values(
        p_request_id,ctx.internal_identity_id,ctx.internal_auth_link_id,
        ctx.internal_membership_id,'revoke',p_invite_id,request_hash,result
      );
    end if;
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail like 'SAI_%' then error_detail
        else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation then error_code:='SAI_INVALID_ARGUMENT';
    when serialization_failure or unique_violation then error_code:='SAI_CONCURRENT_CHANGE';
    when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'platform.invites.manage','invite.revoke',error_code,correlation,null);
    return app_private.superadmin_invite_error_envelope_v2(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'platform.invites.manage',ctx.aal,'invite.revoke','success',null,
    correlation,(result#>>'{invite,institution_id}')::uuid,'invitation',p_invite_id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

revoke all on function public.superadmin_invite_directory_v2(
  text,text[],text[],uuid[],uuid[],uuid[],uuid[],timestamptz,timestamptz,
  integer,integer,boolean
) from public,anon,authenticated,service_role;
revoke all on function public.superadmin_invite_options_v2(
  text,uuid,uuid,uuid,integer
) from public,anon,authenticated,service_role;
revoke all on function public.superadmin_invite_detail_v2(uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.superadmin_invite_issue_v2(
  uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer
) from public,anon,authenticated,service_role;
revoke all on function public.superadmin_invite_resend_v2(uuid,uuid,bigint)
  from public,anon,authenticated,service_role;
revoke all on function public.superadmin_invite_revoke_v2(uuid,uuid,bigint,text)
  from public,anon,authenticated,service_role;

grant execute on function public.superadmin_invite_directory_v2(
  text,text[],text[],uuid[],uuid[],uuid[],uuid[],timestamptz,timestamptz,
  integer,integer,boolean
) to authenticated;
grant execute on function public.superadmin_invite_options_v2(
  text,uuid,uuid,uuid,integer
) to authenticated;
grant execute on function public.superadmin_invite_detail_v2(uuid) to authenticated;
grant execute on function public.superadmin_invite_issue_v2(
  uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer
) to authenticated;
grant execute on function public.superadmin_invite_resend_v2(uuid,uuid,bigint)
  to authenticated;
grant execute on function public.superadmin_invite_revoke_v2(uuid,uuid,bigint,text)
  to authenticated;

commit;
