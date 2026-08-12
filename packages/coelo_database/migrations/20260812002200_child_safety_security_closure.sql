-- Child safety security closure. Commands are server-authorized, idempotent and audited.

-- SECURITY MODEL: direct browser writes are denied. Public RPCs are SECURITY
-- INVOKER wrappers over narrowly granted functions in the unexposed app_private schema.

insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status
) values (
  'child_safety.review','child_safety','approvals','review',
  'Revisar decisões de segurança da criança no escopo exato da unidade.',
  'critical',true,'active'
) on conflict (code) do update set
  description=excluded.description,risk_level='critical',requires_mfa=true,
  status='active',updated_at=now();

drop index if exists public.authorized_people_institution_person_idx;
create unique index authorized_people_institution_person_idx
  on public.authorized_people(institution_id,person_id)
  where person_id is not null and status<>'archived';
create index if not exists authorized_person_authorizations_decision_context_idx
  on public.authorized_person_authorizations(child_context_id,unit_id,decision_status,status,valid_until);
create index if not exists authorized_person_authorizations_decided_by_idx
  on public.authorized_person_authorizations(decided_by_person_id)
  where decided_by_person_id is not null;
create index if not exists child_safety_restrictions_unit_idx
  on public.child_safety_restrictions(unit_id);
create index if not exists child_safety_restrictions_child_idx
  on public.child_safety_restrictions(child_context_id);
create index if not exists child_safety_restrictions_created_by_idx
  on public.child_safety_restrictions(created_by_person_id);
create index if not exists child_safety_restrictions_updated_by_idx
  on public.child_safety_restrictions(updated_by_person_id);
create index if not exists child_safety_alerts_unit_idx
  on public.child_safety_alerts(unit_id);
create index if not exists child_safety_alerts_child_idx
  on public.child_safety_alerts(child_context_id);
create index if not exists child_safety_alerts_authorization_idx
  on public.child_safety_alerts(authorization_id) where authorization_id is not null;
create index if not exists child_safety_alerts_restriction_idx
  on public.child_safety_alerts(restriction_id) where restriction_id is not null;
create index if not exists child_safety_alerts_acknowledged_by_idx
  on public.child_safety_alerts(acknowledged_by_person_id)
  where acknowledged_by_person_id is not null;
create index if not exists child_safety_evidence_unit_idx
  on public.child_safety_evidence(unit_id);
create index if not exists child_safety_evidence_child_idx
  on public.child_safety_evidence(child_context_id);
create index if not exists child_safety_evidence_authorization_idx
  on public.child_safety_evidence(authorization_id) where authorization_id is not null;
create index if not exists child_safety_evidence_restriction_idx
  on public.child_safety_evidence(restriction_id) where restriction_id is not null;
create index if not exists child_safety_evidence_alert_idx
  on public.child_safety_evidence(alert_id) where alert_id is not null;
create index if not exists child_safety_evidence_created_by_idx
  on public.child_safety_evidence(created_by_person_id);
create index if not exists child_safety_receipts_actor_idx
  on app_private.child_safety_command_receipts(actor_person_id);

create or replace function app_private.validate_child_safety_context()
returns trigger language plpgsql security definer set search_path=''
as $$ begin
  if not exists (
    select 1 from public.child_contexts child_context
    join public.child_unit_links child_unit
      on child_unit.child_context_id=child_context.id and child_unit.unit_id=new.unit_id
     and child_unit.status in ('active','awaiting_allocation')
    join public.units unit_record on unit_record.id=new.unit_id
    where child_context.id=new.child_context_id
      and child_context.institution_id=new.institution_id
      and unit_record.institution_id=new.institution_id
  ) then raise check_violation using message='invalid child safety context'; end if;
  if tg_table_name='authorized_person_authorizations' then
    if not exists (
      select 1 from public.authorized_people ap
      where ap.id=new.authorized_person_id
        and ap.institution_id=new.institution_id
        and ap.status<>'archived'
    ) then raise check_violation using message='invalid authorized person context'; end if;
  elsif tg_table_name='child_safety_alerts' then
    if new.authorization_id is not null and not exists (
      select 1 from public.authorized_person_authorizations a where a.id=new.authorization_id
        and (a.institution_id,a.unit_id,a.child_context_id)=
          (new.institution_id,new.unit_id,new.child_context_id)
    ) then raise check_violation using message='invalid child safety subject'; end if;
    if new.restriction_id is not null and not exists (
      select 1 from public.child_safety_restrictions r where r.id=new.restriction_id
        and (r.institution_id,r.unit_id,r.child_context_id)=
          (new.institution_id,new.unit_id,new.child_context_id)
    ) then raise check_violation using message='invalid child safety subject'; end if;
  elsif tg_table_name='child_safety_evidence' then
    if new.authorization_id is not null and not exists (
      select 1 from public.authorized_person_authorizations a where a.id=new.authorization_id
        and (a.institution_id,a.unit_id,a.child_context_id)=
          (new.institution_id,new.unit_id,new.child_context_id)
    ) then raise check_violation using message='invalid child safety subject'; end if;
    if new.restriction_id is not null and not exists (
      select 1 from public.child_safety_restrictions r where r.id=new.restriction_id
        and (r.institution_id,r.unit_id,r.child_context_id)=
          (new.institution_id,new.unit_id,new.child_context_id)
    ) then raise check_violation using message='invalid child safety subject'; end if;
    if new.alert_id is not null and not exists (
      select 1 from public.child_safety_alerts a where a.id=new.alert_id
        and (a.institution_id,a.unit_id,a.child_context_id)=
          (new.institution_id,new.unit_id,new.child_context_id)
    ) then raise check_violation using message='invalid child safety subject'; end if;
  end if;
  return new;
end $$;
revoke all on function app_private.validate_child_safety_context() from public,anon,authenticated;
drop trigger if exists authorized_person_authorizations_validate on public.authorized_person_authorizations;
create trigger authorized_person_authorizations_validate before insert or update
on public.authorized_person_authorizations for each row
execute function app_private.validate_child_safety_context();

create or replace function app_private.child_safety_has_exact_unit_review(
  p_institution_id uuid,p_unit_id uuid
) returns boolean language sql stable security definer set search_path=''
as $$
  with memberships as (
    select m.id from public.institution_memberships m
    where m.person_id=app_private.current_person_id()
      and m.institution_id=p_institution_id and m.status='active' and m.revoked_at is null
  ), effects as (
    select rp.effect from memberships m
    join public.institution_role_assignments a on a.membership_id=m.id
      and a.status='active' and a.scope_kind='unit' and a.scope_unit_id=p_unit_id
      and (a.starts_at is null or a.starts_at<=now())
      and (a.expires_at is null or a.expires_at>now())
    join public.institution_roles r on r.id=a.role_id and r.status='active'
      and (r.institution_id is null or r.institution_id=p_institution_id)
    join public.institution_role_permissions rp on rp.role_id=r.id
      and rp.status='active' and rp.revoked_at is null
    join public.institution_permissions p on p.id=rp.permission_id
      and p.code='authorized_people.manage' and p.status='active'
    union all
    select o.effect from memberships m
    join public.institution_member_permission_overrides o on o.membership_id=m.id
      and o.institution_id=p_institution_id and o.permission_code='authorized_people.manage'
      and o.scope_kind='unit' and o.scope_unit_id=p_unit_id
      and o.status='active' and o.revoked_at is null
      and (o.starts_at is null or o.starts_at<=now())
      and (o.expires_at is null or o.expires_at>now())
  )
  select not exists(select 1 from effects where effect='deny')
     and exists(select 1 from effects where effect='allow')
$$;
revoke all on function app_private.child_safety_has_exact_unit_review(uuid,uuid)
  from public,anon,authenticated;

create or replace function app_private.child_safety_add_unit_review_recipients(
  p_event_id uuid,p_institution_id uuid,p_unit_id uuid
) returns void language sql security definer set search_path=''
as $$
  with memberships as (
    select m.id,m.person_id from public.institution_memberships m
    where m.institution_id=p_institution_id and m.status='active' and m.revoked_at is null
  ), effects as (
    select m.person_id,rp.effect from memberships m
    join public.institution_role_assignments a on a.membership_id=m.id
      and a.status='active' and a.scope_kind='unit' and a.scope_unit_id=p_unit_id
      and (a.starts_at is null or a.starts_at<=now())
      and (a.expires_at is null or a.expires_at>now())
    join public.institution_roles r on r.id=a.role_id and r.status='active'
      and (r.institution_id is null or r.institution_id=p_institution_id)
    join public.institution_role_permissions rp on rp.role_id=r.id
      and rp.status='active' and rp.revoked_at is null
    join public.institution_permissions p on p.id=rp.permission_id
      and p.code='authorized_people.manage' and p.status='active'
    union all
    select m.person_id,o.effect from memberships m
    join public.institution_member_permission_overrides o on o.membership_id=m.id
      and o.institution_id=p_institution_id and o.permission_code='authorized_people.manage'
      and o.scope_kind='unit' and o.scope_unit_id=p_unit_id
      and o.status='active' and o.revoked_at is null
      and (o.starts_at is null or o.starts_at<=now())
      and (o.expires_at is null or o.expires_at>now())
  ), allowed as (
    select person_id from effects group by person_id
    having bool_or(effect='allow') and not bool_or(effect='deny')
  )
  insert into public.context_notification_recipients(event_id,person_id)
    select p_event_id,person_id from allowed on conflict do nothing
$$;
revoke all on function app_private.child_safety_add_unit_review_recipients(uuid,uuid,uuid)
  from public,anon,authenticated;

create or replace function app_private.child_safety_can_manage(
  p_institution_id uuid,p_unit_id uuid,p_child_context_id uuid
) returns boolean language sql stable security definer set search_path=''
as $$ select
  app_private.has_platform_permission('child_safety.manage')
  or app_private.has_context_permission(
    p_institution_id,'authorized_people.manage',p_unit_id,null,null,p_child_context_id,false
  )
  or app_private.guardian_has_capability(p_child_context_id,'manage_authorized_people')
$$;
revoke all on function app_private.child_safety_can_manage(uuid,uuid,uuid)
  from public,anon,authenticated;

create or replace function app_private.child_safety_can_administer(
  p_institution_id uuid,p_unit_id uuid,p_child_context_id uuid
) returns boolean language sql stable security definer set search_path=''
as $$ select
  app_private.has_platform_permission('child_safety.manage')
  or app_private.has_context_permission(
    p_institution_id,'authorized_people.manage',p_unit_id,null,null,p_child_context_id,false
  )
$$;
revoke all on function app_private.child_safety_can_administer(uuid,uuid,uuid)
  from public,anon,authenticated;

create or replace function app_private.child_safety_receipt(
  p_request_id uuid,p_actor uuid,p_command text,p_hash bytea
) returns jsonb language plpgsql stable security definer set search_path=''
as $$ declare r app_private.child_safety_command_receipts%rowtype; begin
  select * into r from app_private.child_safety_command_receipts where request_id=p_request_id;
  if r.request_id is null then return null; end if;
  if r.actor_person_id<>p_actor or r.command_code<>p_command
     or r.request_hash<>p_hash or r.expires_at<=now() then
    raise invalid_parameter_value using message='idempotency key conflict';
  end if;
  return r.response_json;
end $$;
create or replace function app_private.child_safety_store_receipt(
  p_request_id uuid,p_actor uuid,p_command text,p_hash bytea,p_target_id uuid,p_response jsonb
) returns jsonb language plpgsql security definer set search_path=''
as $$ begin
  insert into app_private.child_safety_command_receipts(
    request_id,actor_person_id,command_code,request_hash,target_id,response_json
  ) values(p_request_id,p_actor,p_command,p_hash,p_target_id,p_response);
  return p_response;
end $$;
revoke all on function app_private.child_safety_receipt(uuid,uuid,text,bytea),
  app_private.child_safety_store_receipt(uuid,uuid,text,bytea,uuid,jsonb)
from public,anon,authenticated;

drop function if exists public.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,integer);
drop function if exists public.superadmin_child_safety_directory(
  text,text[],text[],uuid[],uuid[],timestamptz,uuid,integer
);
drop function if exists app_private.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,integer);

create or replace function app_private.superadmin_child_safety_directory(
  p_search text,p_institution_ids uuid[],p_unit_ids uuid[],p_segment text,
  p_limit integer,p_cursor jsonb
) returns jsonb language plpgsql stable security definer set search_path=''
as $$ declare result jsonb; cursor_name text; cursor_context uuid; cursor_unit uuid; begin
  perform app_private.assert_child_safety_platform('child_safety.read');
  if char_length(coalesce(p_search,''))>120
     or p_segment is null
     or p_segment not in ('all','awaiting_approval','attention','authorized','without_authorization')
     or p_limit is null or p_limit not in (8,11,20,50,100)
     or (p_cursor is not null and jsonb_typeof(p_cursor)<>'object') then
    raise invalid_parameter_value using message='invalid child safety directory filters';
  end if;
  begin
    cursor_name:=nullif(p_cursor->>'name','');
    cursor_context:=nullif(p_cursor->>'child_context_id','')::uuid;
    cursor_unit:=nullif(p_cursor->>'unit_id','')::uuid;
  exception when others then
    raise invalid_parameter_value using message='invalid child safety cursor';
  end;
  if (cursor_name is null)<>(cursor_context is null)
     or (cursor_name is null)<>(cursor_unit is null) then
    raise invalid_parameter_value using message='invalid child safety cursor';
  end if;
  if exists (
    select 1 from public.units u where u.id=any(coalesce(p_unit_ids,'{}'::uuid[]))
      and cardinality(coalesce(p_institution_ids,'{}'::uuid[]))>0
      and not u.institution_id=any(p_institution_ids)
  ) then raise invalid_parameter_value using message='invalid child safety hierarchy'; end if;

  with selected_units as (
    select distinct on (l.child_context_id) l.child_context_id,l.unit_id
    from public.child_unit_links l join public.units u on u.id=l.unit_id
    where l.status in ('active','awaiting_allocation')
      and (cardinality(coalesce(p_unit_ids,'{}'::uuid[]))=0 or l.unit_id=any(p_unit_ids))
      and (cardinality(coalesce(p_institution_ids,'{}'::uuid[]))=0
        or u.institution_id=any(p_institution_ids))
    order by l.child_context_id,case when l.status='active' then 0 else 1 end,l.unit_id
  ), scoped as (
    select c.id child_context_id,p.id child_id,p.display_name child_name,
      lower(p.display_name) sort_name,coalesce(c.local_identifier,'') internal_id,
      i.id institution_id,i.public_name institution_name,u.id unit_id,u.name unit_name,
      count(a.id) authorization_count,
      coalesce(bool_or(a.decision_status='pending') filter(where a.id is not null),false) has_pending,
      coalesce(bool_or(a.decision_status='approved' and a.status='active'
        and a.revoked_at is null and a.valid_from<=current_date
        and (a.valid_until is null or a.valid_until>=current_date))
        filter(where a.id is not null),false) has_authorized,
      exists(select 1 from public.child_safety_restrictions r
        where r.child_context_id=c.id and r.unit_id=u.id and r.status='active'
          and r.revoked_at is null and r.valid_from<=now()
          and (r.valid_until is null or r.valid_until>now()))
      or exists(select 1 from public.child_safety_alerts al
        where al.child_context_id=c.id and al.unit_id=u.id
          and al.status in ('open','acknowledged')) has_attention,
      max(a.updated_at) last_safety_change
    from public.child_contexts c
    join public.people p on p.id=c.child_person_id and p.person_type='child'
    join public.institutions i on i.id=c.institution_id
    join selected_units su on su.child_context_id=c.id
    join public.units u on u.id=su.unit_id
    left join public.authorized_person_authorizations a
      on a.child_context_id=c.id and a.unit_id=u.id
    where c.status='active' and p.status='active'
      and (nullif(btrim(p_search),'') is null
        or lower(p.display_name) like '%'||lower(btrim(p_search))||'%'
        or lower(coalesce(c.local_identifier,'')) like '%'||lower(btrim(p_search))||'%')
    group by c.id,p.id,p.display_name,c.local_identifier,i.id,i.public_name,u.id,u.name
  ), segmented as (
    select *,case when has_pending then 'awaiting_approval'
      when has_attention then 'attention' when has_authorized then 'authorized'
      else 'without_authorization' end segment from scoped
  ), filtered as (
    select * from segmented where p_segment='all' or segment=p_segment
  ), page_plus_one as (
    select * from filtered where cursor_name is null
      or (sort_name,child_context_id,unit_id)>(cursor_name,cursor_context,cursor_unit)
    order by sort_name,child_context_id,unit_id limit p_limit+1
  ), page_rows as (
    select * from page_plus_one order by sort_name,child_context_id,unit_id limit p_limit
  ), last_row as (
    select * from page_rows order by sort_name desc,child_context_id desc,unit_id desc limit 1
  )
  select jsonb_build_object(
    'items',coalesce((select jsonb_agg(jsonb_build_object(
      'child_id',child_id,'child_context_id',child_context_id,'child_name',child_name,
      'internal_id',internal_id,'institution_id',institution_id,'institution_name',institution_name,
      'unit_id',unit_id,'unit_name',unit_name,'authorization_count',authorization_count,
      'segment',segment,'last_safety_change',last_safety_change
    ) order by sort_name,child_context_id,unit_id) from page_rows),'[]'::jsonb),
    'total_count',(select count(*) from filtered),
    'segment_counts',jsonb_build_object(
      'all',(select count(*) from segmented),
      'awaiting_approval',(select count(*) from segmented where segment='awaiting_approval'),
      'attention',(select count(*) from segmented where segment='attention'),
      'authorized',(select count(*) from segmented where segment='authorized'),
      'without_authorization',(select count(*) from segmented where segment='without_authorization')),
    'next_cursor',case when (select count(*) from page_plus_one)>p_limit then
      (select jsonb_build_object('name',sort_name,'child_context_id',child_context_id,'unit_id',unit_id)
       from last_row) else null end,
    'can_create',app_private.has_platform_permission('child_safety.manage')
  ) into result;
  return result;
end $$;
create or replace function public.superadmin_child_safety_directory(
  p_search text default '',p_institution_ids uuid[] default '{}',p_unit_ids uuid[] default '{}',
  p_segment text default 'all',p_limit integer default 11,p_cursor jsonb default null
) returns jsonb language sql stable security invoker set search_path=''
as $$ select app_private.superadmin_child_safety_directory($1,$2,$3,$4,$5,$6) $$;

-- Search and detail are redefined to query only after the platform capability/AAL2 gate.
create or replace function app_private.superadmin_child_safety_search_children(p_search text,p_limit integer)
returns jsonb language plpgsql stable security definer set search_path=''
as $$ begin
  perform app_private.assert_child_safety_platform('child_safety.read');
  if char_length(btrim(coalesce(p_search,'')))<2 or char_length(p_search)>120
     or p_limit is null or p_limit not between 1 and 20 then
    raise invalid_parameter_value using message='invalid child search';
  end if;
  return coalesce((select jsonb_agg(item order by item->>'display_name') from (
    select jsonb_build_object('id',p.id,'display_name',p.display_name,
      'internal_id',coalesce(c.local_identifier,''),
      'contexts',jsonb_agg(jsonb_build_object('child_context_id',c.id,
        'institution_id',i.id,'institution_name',i.public_name,
        'unit_id',u.id,'unit_name',u.name) order by i.public_name,u.name)) item
    from public.people p
    join public.child_contexts c on c.child_person_id=p.id and c.status='active'
    join public.institutions i on i.id=c.institution_id
    join public.child_unit_links l on l.child_context_id=c.id
      and l.status in ('active','awaiting_allocation')
    join public.units u on u.id=l.unit_id and u.institution_id=c.institution_id
    where p.person_type='child' and p.status='active'
      and (lower(p.display_name) like '%'||lower(btrim(p_search))||'%'
        or lower(coalesce(c.local_identifier,'')) like '%'||lower(btrim(p_search))||'%')
    group by p.id,p.display_name,c.local_identifier
    order by p.display_name,p.id limit p_limit
  ) rows),'[]'::jsonb);
end $$;

create or replace function app_private.superadmin_child_safety_get(p_child_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$ declare result jsonb; begin
  perform app_private.assert_child_safety_platform('child_safety.read');
  select jsonb_build_object('child_id',p.id,'child_name',p.display_name,
    'contexts',coalesce((select jsonb_agg(jsonb_build_object(
      'child_context_id',c.id,'internal_id',coalesce(c.local_identifier,''),
      'institution_id',i.id,'institution_name',i.public_name,'unit_id',u.id,'unit_name',u.name)
      order by i.public_name,u.name)
      from public.child_contexts c join public.institutions i on i.id=c.institution_id
      join public.child_unit_links l on l.child_context_id=c.id
        and l.status in ('active','awaiting_allocation')
      join public.units u on u.id=l.unit_id and u.institution_id=c.institution_id
      where c.child_person_id=p.id and c.status='active'),'[]'::jsonb),
    'authorizations',coalesce((select jsonb_agg(jsonb_build_object(
      'id',a.id,'child_context_id',a.child_context_id,'unit_id',a.unit_id,
      'person_id',ap.person_id,'name',ap.display_name,'relationship_code',rt.code,
      'relationship_detail',a.relationship_detail,
      'capability_codes',(select coalesce(jsonb_agg(cap.capability_code order by cap.capability_code),'[]')
        from public.authorized_person_authorization_capabilities cap where cap.authorization_id=a.id),
      'decision_status',a.decision_status,'lifecycle_status',a.status,
      'valid_from',a.valid_from,'valid_until',a.valid_until,'version',a.version,
      'request_reason',a.request_reason,'decision_reason',a.decision_reason)
      order by a.created_at desc)
      from public.authorized_person_authorizations a
      join public.authorized_people ap on ap.id=a.authorized_person_id
      join public.family_relationship_types rt on rt.id=a.relationship_type_id
      join public.child_contexts c on c.id=a.child_context_id
      where c.child_person_id=p.id),'[]'::jsonb),
    'restrictions',coalesce((select jsonb_agg(to_jsonb(r)-'created_by_person_id'-'updated_by_person_id')
      from public.child_safety_restrictions r join public.child_contexts c on c.id=r.child_context_id
      where c.child_person_id=p.id),'[]'::jsonb),
    'alerts',coalesce((select jsonb_agg(to_jsonb(a)-'acknowledged_by_person_id')
      from public.child_safety_alerts a join public.child_contexts c on c.id=a.child_context_id
      where c.child_person_id=p.id),'[]'::jsonb),
    'evidence',coalesce((select jsonb_agg(jsonb_build_object(
      'id',e.id,'child_context_id',e.child_context_id,'authorization_id',e.authorization_id,
      'restriction_id',e.restriction_id,'alert_id',e.alert_id,'file_name',e.file_name,
      'mime_type',e.mime_type,'size_bytes',e.size_bytes,'status',e.status,'created_at',e.created_at)
      order by e.created_at desc)
      from public.child_safety_evidence e join public.child_contexts c on c.id=e.child_context_id
      where c.child_person_id=p.id and e.status='active'),'[]'::jsonb)
  ) into result from public.people p
  where p.id=p_child_id and p.person_type='child' and p.status='active';
  if result is null then raise no_data_found using message='child safety record unavailable'; end if;
  return result;
end $$;

create or replace function app_private.child_safety_request_authorization(
  p_request_id uuid,p_payload jsonb
) returns jsonb language plpgsql security definer set search_path=''
as $$ declare
  actor uuid:=app_private.current_person_id(); request_hash bytea; replay jsonb;
  target_context uuid; target_unit uuid; target_person uuid; target_institution uuid;
  relation_id uuid; requested_relation_code text; relation_detail text; authorization_id uuid;
  authorized_person_id uuid; capabilities text[]; guardian_request boolean;
  administrative_request boolean; platform_request boolean; result jsonb; notification_id uuid;
  starts date; ends date; request_reason text;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null
     or jsonb_typeof(p_payload)<>'object' then
    raise insufficient_privilege using message='child safety request unavailable';
  end if;
  request_hash:=extensions.digest(convert_to(p_payload::text,'utf8'),'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
  replay:=app_private.child_safety_receipt(p_request_id,actor,'request_authorization',request_hash);
  if replay is not null then return replay; end if;
  begin
    target_context:=(p_payload->>'child_context_id')::uuid;
    target_unit:=(p_payload->>'unit_id')::uuid;
    target_person:=(p_payload->>'person_id')::uuid;
    starts:=coalesce(nullif(p_payload->>'valid_from','')::date,current_date);
    ends:=nullif(p_payload->>'valid_until','')::date;
  exception when others then raise invalid_parameter_value using message='invalid authorization request'; end;
  request_reason:=btrim(coalesce(p_payload->>'request_reason',''));
  requested_relation_code:=btrim(coalesce(p_payload->>'relationship_code',''));
  relation_detail:=nullif(btrim(coalesce(p_payload->>'relationship_detail','')),'');
  if jsonb_typeof(coalesce(p_payload->'capability_codes','[]'))<>'array' then
    raise invalid_parameter_value using message='invalid authorization request';
  end if;
  select array_agg(distinct value order by value) into capabilities
  from jsonb_array_elements_text(coalesce(p_payload->'capability_codes','[]')) value;
  if char_length(request_reason) not between 3 and 500
     or (ends is not null and ends<starts) or capabilities is null
     or not capabilities<@array['emergency_contact','pickup','transport']::text[]
     or cardinality(capabilities)=0 then
    raise invalid_parameter_value using message='invalid authorization request';
  end if;
  select c.institution_id into target_institution
  from public.child_contexts c join public.child_unit_links l
    on l.child_context_id=c.id and l.unit_id=target_unit
   and l.status in ('active','awaiting_allocation')
  join public.units u on u.id=target_unit and u.institution_id=c.institution_id
  where c.id=target_context and c.status='active';
  guardian_request:=app_private.guardian_has_capability(target_context,'manage_authorized_people');
  platform_request:=app_private.has_platform_permission('child_safety.manage');
  administrative_request:=app_private.child_safety_can_administer(
    target_institution,target_unit,target_context
  );
  if target_institution is null or not (administrative_request or guardian_request) then
    raise no_data_found using message='child safety record unavailable';
  end if;
  if not exists(select 1 from public.people p where p.id=target_person
    and p.person_type='adult' and p.status='active') then
    raise no_data_found using message='child safety record unavailable';
  end if;
  -- Guardians may only reuse an adult identity they already own in this
  -- institution. Creating/linking a new global identity is an administrative
  -- operation or must go through the separately verified invitation flow.
  if not platform_request and not exists (
    select 1 from public.authorized_people ap
    where ap.institution_id=target_institution and ap.person_id=target_person
      and ap.status='active'
      and (administrative_request or ap.owner_guardian_person_id=actor)
  ) then
    raise no_data_found using message='child safety record unavailable';
  end if;
  select id into relation_id from public.family_relationship_types
    where code=requested_relation_code and status='active';
  if relation_id is null or (lower(requested_relation_code) in ('other','others','outros')
    and relation_detail is null) then
    raise invalid_parameter_value using message='invalid relationship';
  end if;
  perform pg_advisory_xact_lock(
    pg_catalog.hashtextextended(target_institution::text||target_person::text,0)
  );
  select id into authorized_person_id from public.authorized_people
  where institution_id=target_institution and person_id=target_person and status<>'archived'
    and (administrative_request or owner_guardian_person_id=actor)
  order by created_at limit 1 for update;
  if authorized_person_id is null and platform_request then
    insert into public.authorized_people(
      institution_id,person_id,owner_guardian_person_id,display_name,status
    ) select target_institution,target_person,case when guardian_request then actor end,
      p.display_name,'active' from public.people p where p.id=target_person
    returning id into authorized_person_id;
  end if;
  if authorized_person_id is null then
    raise no_data_found using message='child safety record unavailable';
  end if;
  insert into public.authorized_person_authorizations(
    authorized_person_id,institution_id,child_context_id,unit_id,relationship_type_id,
    relationship_detail,created_by_person_id,status,valid_from,valid_until,
    decision_status,request_reason,version
  ) values(
    authorized_person_id,target_institution,target_context,target_unit,relation_id,
    relation_detail,actor,'inactive',starts,ends,'pending',request_reason,1
  ) returning id into authorization_id;
  insert into public.authorized_person_authorization_capabilities(authorization_id,capability_code)
  select authorization_id,unnest(capabilities);
  insert into public.context_notification_events(
    institution_id,unit_id,child_context_id,event_code,object_type,object_id,payload_json,
    created_by_person_id
  ) values(target_institution,target_unit,target_context,
    'child_safety.authorization_requested','authorized_person_authorization',authorization_id,
    jsonb_build_object('authorization_id',authorization_id,'decision_status','pending'),actor)
  returning id into notification_id;
  perform app_private.child_safety_add_unit_review_recipients(
    notification_id,target_institution,target_unit
  );
  insert into audit.audit_logs(
    actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json
  ) values(actor,auth.jwt()->>'aal','child_safety.authorization.request',
    'authorized_person_authorization',authorization_id,target_institution,'success',
    jsonb_build_object('decision_status','pending','lifecycle_status','inactive','unit_id',target_unit));
  result:=jsonb_build_object('authorization_id',authorization_id,'decision_status','pending',
    'lifecycle_status','inactive','version',1);
  return app_private.child_safety_store_receipt(
    p_request_id,actor,'request_authorization',request_hash,authorization_id,result
  );
end $$;
create or replace function public.child_safety_request_authorization(p_request_id uuid,p_payload jsonb)
returns jsonb language sql security invoker set search_path=''
as $$ select app_private.child_safety_request_authorization($1,$2) $$;

create or replace function app_private.child_safety_edit_pending_authorization(
  p_request_id uuid,p_authorization_id uuid,p_expected_version bigint,p_payload jsonb
) returns jsonb language plpgsql security definer set search_path=''
as $$ declare
  actor uuid:=app_private.current_person_id(); request_hash bytea; replay jsonb;
  current_row public.authorized_person_authorizations%rowtype; relation_id uuid;
  relation_code text; relation_detail text; capabilities text[]; starts date;
  ends date; request_reason text; before_state jsonb; result jsonb;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null
    or p_expected_version is null or p_expected_version<1
    or jsonb_typeof(p_payload)<>'object' then
    raise insufficient_privilege using message='child safety record unavailable';
  end if;
  request_hash:=extensions.digest(convert_to(
    jsonb_build_object('authorization_id',p_authorization_id,'version',p_expected_version,
      'payload',p_payload)::text,'utf8'),'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
  replay:=app_private.child_safety_receipt(p_request_id,actor,'edit_pending',request_hash);
  if replay is not null then return replay; end if;
  select a.* into current_row from public.authorized_person_authorizations a
  where a.id=p_authorization_id and a.decision_status='pending'
    and (app_private.child_safety_can_administer(
      a.institution_id,a.unit_id,a.child_context_id
    ) or (a.created_by_person_id=actor and app_private.guardian_has_capability(
      a.child_context_id,'manage_authorized_people'
    )))
  for update;
  if current_row.id is null then raise no_data_found using message='child safety record unavailable'; end if;
  if current_row.version<>p_expected_version then
    raise serialization_failure using message='stale child safety version';
  end if;
  begin
    starts:=coalesce(nullif(p_payload->>'valid_from','')::date,current_row.valid_from);
    ends:=nullif(p_payload->>'valid_until','')::date;
  exception when others then raise invalid_parameter_value using message='invalid authorization request'; end;
  request_reason:=btrim(coalesce(p_payload->>'request_reason',''));
  relation_code:=btrim(coalesce(p_payload->>'relationship_code',''));
  relation_detail:=nullif(btrim(coalesce(p_payload->>'relationship_detail','')),'');
  if jsonb_typeof(coalesce(p_payload->'capability_codes','[]'))<>'array' then
    raise invalid_parameter_value using message='invalid authorization request';
  end if;
  select array_agg(distinct value order by value) into capabilities
  from jsonb_array_elements_text(coalesce(p_payload->'capability_codes','[]')) value;
  select id into relation_id from public.family_relationship_types
    where code=relation_code and status='active';
  if char_length(request_reason) not between 3 and 500
     or (ends is not null and ends<starts) or relation_id is null
     or (lower(relation_code) in ('other','others','outros') and relation_detail is null)
     or capabilities is null
     or not capabilities<@array['emergency_contact','pickup','transport']::text[]
     or cardinality(capabilities)=0 then
    raise invalid_parameter_value using message='invalid authorization request';
  end if;
  before_state:=jsonb_build_object('decision_status',current_row.decision_status,
    'lifecycle_status',current_row.status,'version',current_row.version);
  update public.authorized_person_authorizations set
    relationship_type_id=relation_id,relationship_detail=relation_detail,
    valid_from=starts,valid_until=ends,request_reason=request_reason,
    version=version+1,updated_at=now() where id=current_row.id;
  delete from public.authorized_person_authorization_capabilities
    where authorization_id=current_row.id;
  insert into public.authorized_person_authorization_capabilities(authorization_id,capability_code)
    select current_row.id,unnest(capabilities);
  result:=jsonb_build_object('authorization_id',current_row.id,'decision_status','pending',
    'lifecycle_status','inactive','version',current_row.version+1);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    institution_id,outcome,before_json,after_json)
  values(actor,auth.jwt()->>'aal','child_safety.authorization.edit_pending',
    'authorized_person_authorization',current_row.id,current_row.institution_id,'success',
    before_state,result);
  return app_private.child_safety_store_receipt(
    p_request_id,actor,'edit_pending',request_hash,current_row.id,result
  );
end $$;
create or replace function public.child_safety_edit_pending_authorization(
  p_request_id uuid,p_authorization_id uuid,p_expected_version bigint,p_payload jsonb
) returns jsonb language sql security invoker set search_path=''
as $$ select app_private.child_safety_edit_pending_authorization($1,$2,$3,$4) $$;

create or replace function app_private.child_safety_decide_authorization(
  p_request_id uuid,p_authorization_id uuid,p_expected_version bigint,
  p_decision text,p_reason text
) returns jsonb language plpgsql security definer set search_path=''
as $$ declare
  actor uuid:=app_private.current_person_id(); request_hash bytea; replay jsonb;
  current_row public.authorized_person_authorizations%rowtype; before_state jsonb;
  result jsonb; notification_id uuid;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null
    or p_expected_version is null or p_expected_version<1
    or not app_private.has_mfa_aal2()
    or p_decision not in ('approved','rejected')
    or char_length(btrim(coalesce(p_reason,''))) not between 3 and 500 then
    raise insufficient_privilege using message='child safety decision unavailable';
  end if;
  request_hash:=extensions.digest(convert_to(jsonb_build_object('authorization_id',p_authorization_id,
    'version',p_expected_version,'decision',p_decision,'reason',btrim(p_reason))::text,'utf8'),'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
  replay:=app_private.child_safety_receipt(p_request_id,actor,'decide_authorization',request_hash);
  if replay is not null then return replay; end if;
  select a.* into current_row from public.authorized_person_authorizations a
  where a.id=p_authorization_id and a.decision_status='pending'
    and app_private.child_safety_has_exact_unit_review(a.institution_id,a.unit_id)
  for update;
  if current_row.id is null then raise no_data_found using message='child safety record unavailable'; end if;
  if current_row.version<>p_expected_version then
    raise serialization_failure using message='stale child safety version';
  end if;
  before_state:=jsonb_build_object('decision_status',current_row.decision_status,
    'lifecycle_status',current_row.status,'version',current_row.version);
  update public.authorized_person_authorizations set decision_status=p_decision,
    decision_reason=btrim(p_reason),decided_by_person_id=actor,decided_at=now(),
    status=case when p_decision='approved' then 'active'::public.record_status
      else 'inactive'::public.record_status end,version=version+1,updated_at=now()
  where id=current_row.id;
  result:=jsonb_build_object('authorization_id',current_row.id,'decision_status',p_decision,
    'lifecycle_status',case when p_decision='approved' then 'active' else 'inactive' end,
    'version',current_row.version+1);
  insert into public.context_notification_events(
    institution_id,unit_id,child_context_id,event_code,object_type,object_id,payload_json,
    created_by_person_id
  ) values(current_row.institution_id,current_row.unit_id,current_row.child_context_id,
    'child_safety.authorization_decided','authorized_person_authorization',current_row.id,
    jsonb_build_object('authorization_id',current_row.id,'decision_status',p_decision),actor)
  returning id into notification_id;
  perform app_private.child_safety_add_unit_review_recipients(
    notification_id,current_row.institution_id,current_row.unit_id
  );
  insert into public.context_notification_recipients(event_id,person_id)
    values(notification_id,current_row.created_by_person_id) on conflict do nothing;
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    institution_id,outcome,reason,before_json,after_json)
  values(actor,auth.jwt()->>'aal','child_safety.authorization.decide',
    'authorized_person_authorization',current_row.id,current_row.institution_id,'success',
    btrim(p_reason),before_state,result);
  return app_private.child_safety_store_receipt(
    p_request_id,actor,'decide_authorization',request_hash,current_row.id,result
  );
end $$;
create or replace function public.child_safety_decide_authorization(
  p_request_id uuid,p_authorization_id uuid,p_expected_version bigint,p_decision text,p_reason text
) returns jsonb language sql security invoker set search_path=''
as $$ select app_private.child_safety_decide_authorization($1,$2,$3,$4,$5) $$;

create or replace function app_private.child_safety_change_lifecycle(
  p_request_id uuid,p_authorization_id uuid,p_expected_version bigint,
  p_lifecycle_status text,p_reason text
) returns jsonb language plpgsql security definer set search_path=''
as $$ declare
  actor uuid:=app_private.current_person_id(); request_hash bytea; replay jsonb;
  current_row public.authorized_person_authorizations%rowtype; before_state jsonb; result jsonb;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null
    or p_expected_version is null or p_expected_version<1
    or not app_private.has_mfa_aal2()
    or p_lifecycle_status not in ('active','suspended','archived')
    or char_length(btrim(coalesce(p_reason,''))) not between 3 and 500 then
    raise insufficient_privilege using message='child safety lifecycle unavailable';
  end if;
  request_hash:=extensions.digest(convert_to(jsonb_build_object('authorization_id',p_authorization_id,
    'version',p_expected_version,'status',p_lifecycle_status,'reason',btrim(p_reason))::text,
    'utf8'),'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
  replay:=app_private.child_safety_receipt(p_request_id,actor,'change_lifecycle',request_hash);
  if replay is not null then return replay; end if;
  select a.* into current_row from public.authorized_person_authorizations a
  where a.id=p_authorization_id and a.decision_status='approved'
    and app_private.child_safety_can_administer(a.institution_id,a.unit_id,a.child_context_id)
  for update;
  if current_row.id is null then raise no_data_found using message='child safety record unavailable'; end if;
  if current_row.version<>p_expected_version then
    raise serialization_failure using message='stale child safety version';
  end if;
  if p_lifecycle_status='active' and (current_row.valid_from>current_date
    or current_row.valid_until is not null and current_row.valid_until<current_date) then
    raise check_violation using message='authorization validity prevents activation';
  end if;
  before_state:=jsonb_build_object('decision_status',current_row.decision_status,
    'lifecycle_status',current_row.status,'version',current_row.version);
  update public.authorized_person_authorizations set
    status=p_lifecycle_status::public.record_status,
    suspended_by_person_id=case when p_lifecycle_status='suspended' then actor end,
    suspended_at=case when p_lifecycle_status='suspended' then now() end,
    suspension_reason=case when p_lifecycle_status='suspended' then btrim(p_reason) end,
    revoked_at=case when p_lifecycle_status='archived' then now() end,
    version=version+1,updated_at=now() where id=current_row.id;
  result:=jsonb_build_object('authorization_id',current_row.id,'decision_status','approved',
    'lifecycle_status',p_lifecycle_status,'version',current_row.version+1);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    institution_id,outcome,reason,before_json,after_json)
  values(actor,auth.jwt()->>'aal','child_safety.authorization.lifecycle',
    'authorized_person_authorization',current_row.id,current_row.institution_id,'success',
    btrim(p_reason),before_state,result);
  return app_private.child_safety_store_receipt(
    p_request_id,actor,'change_lifecycle',request_hash,current_row.id,result
  );
end $$;
create or replace function public.child_safety_change_lifecycle(
  p_request_id uuid,p_authorization_id uuid,p_expected_version bigint,
  p_lifecycle_status text,p_reason text
) returns jsonb language sql security invoker set search_path=''
as $$ select app_private.child_safety_change_lifecycle($1,$2,$3,$4,$5) $$;

create or replace function app_private.child_safety_save_restriction(
  p_request_id uuid,p_payload jsonb
) returns jsonb language plpgsql security definer set search_path=''
as $$ declare
  actor uuid:=app_private.current_person_id(); request_hash bytea; replay jsonb;
  target_id uuid; target_context uuid; target_unit uuid; target_institution uuid;
  expected_version bigint; current_row public.child_safety_restrictions%rowtype;
  result jsonb; before_state jsonb; starts timestamptz; ends timestamptz;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null
    or not app_private.has_mfa_aal2()
    or jsonb_typeof(p_payload)<>'object' then
    raise insufficient_privilege using message='child safety restriction unavailable';
  end if;
  request_hash:=extensions.digest(convert_to(p_payload::text,'utf8'),'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
  replay:=app_private.child_safety_receipt(p_request_id,actor,'save_restriction',request_hash);
  if replay is not null then return replay; end if;
  begin
    target_id:=nullif(p_payload->>'restriction_id','')::uuid;
    target_context:=(p_payload->>'child_context_id')::uuid;
    target_unit:=(p_payload->>'unit_id')::uuid;
    expected_version:=coalesce(nullif(p_payload->>'expected_version','')::bigint,1);
    starts:=coalesce(nullif(p_payload->>'valid_from','')::timestamptz,now());
    ends:=nullif(p_payload->>'valid_until','')::timestamptz;
  exception when others then raise invalid_parameter_value using message='invalid restriction'; end;
  select c.institution_id into target_institution from public.child_contexts c
  join public.child_unit_links l on l.child_context_id=c.id and l.unit_id=target_unit
    and l.status in ('active','awaiting_allocation')
  where c.id=target_context and c.status='active';
  if target_institution is null or not app_private.child_safety_can_administer(
    target_institution,target_unit,target_context
  ) then raise no_data_found using message='child safety record unavailable'; end if;
  if btrim(coalesce(p_payload->>'restriction_code','')) !~ '^[a-z][a-z0-9_]{2,63}$'
    or char_length(btrim(coalesce(p_payload->>'title',''))) not between 3 and 120
    or char_length(btrim(coalesce(p_payload->>'description',''))) not between 3 and 1000
    or char_length(btrim(coalesce(p_payload->>'reason',''))) not between 3 and 500
    or coalesce(p_payload->>'severity','') not in ('information','attention','high','critical')
    or (ends is not null and ends<=starts) then
    raise invalid_parameter_value using message='invalid restriction';
  end if;
  if target_id is null then
    insert into public.child_safety_restrictions(
      institution_id,unit_id,child_context_id,restriction_code,title,description,severity,reason,
      valid_from,valid_until,created_by_person_id,updated_by_person_id
    ) values(target_institution,target_unit,target_context,p_payload->>'restriction_code',
      btrim(p_payload->>'title'),btrim(p_payload->>'description'),
      (p_payload->>'severity')::public.child_safety_severity,btrim(p_payload->>'reason'),
      starts,ends,actor,actor) returning id into target_id;
  else
    select r.* into current_row from public.child_safety_restrictions r
    where r.id=target_id and (r.institution_id,r.unit_id,r.child_context_id)=
      (target_institution,target_unit,target_context) for update;
    if current_row.id is null then raise no_data_found using message='child safety record unavailable'; end if;
    if current_row.version<>expected_version then
      raise serialization_failure using message='stale child safety version';
    end if;
    before_state:=jsonb_build_object('status',current_row.status,'severity',current_row.severity,
      'version',current_row.version);
    update public.child_safety_restrictions set restriction_code=p_payload->>'restriction_code',
      title=btrim(p_payload->>'title'),description=btrim(p_payload->>'description'),
      severity=(p_payload->>'severity')::public.child_safety_severity,
      reason=btrim(p_payload->>'reason'),valid_from=starts,valid_until=ends,
      updated_by_person_id=actor,version=version+1,updated_at=now() where id=target_id;
  end if;
  select jsonb_build_object('restriction_id',id,'status',status,'severity',severity,'version',version)
    into result from public.child_safety_restrictions where id=target_id;
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    institution_id,outcome,before_json,after_json)
  values(actor,auth.jwt()->>'aal','child_safety.restriction.save','child_safety_restriction',
    target_id,target_institution,'success',before_state,result);
  return app_private.child_safety_store_receipt(
    p_request_id,actor,'save_restriction',request_hash,target_id,result
  );
end $$;
create or replace function public.child_safety_save_restriction(p_request_id uuid,p_payload jsonb)
returns jsonb language sql security invoker set search_path=''
as $$ select app_private.child_safety_save_restriction($1,$2) $$;

create or replace function app_private.child_safety_acknowledge_alert(
  p_request_id uuid,p_alert_id uuid,p_expected_version bigint,p_status text,p_reason text
) returns jsonb language plpgsql security definer set search_path=''
as $$ declare
  actor uuid:=app_private.current_person_id(); request_hash bytea; replay jsonb;
  current_row public.child_safety_alerts%rowtype; before_state jsonb; result jsonb;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null
    or p_expected_version is null or p_expected_version<1
    or not app_private.has_mfa_aal2()
    or p_status not in ('acknowledged','resolved')
    or char_length(btrim(coalesce(p_reason,''))) not between 3 and 500 then
    raise insufficient_privilege using message='child safety alert unavailable';
  end if;
  request_hash:=extensions.digest(convert_to(jsonb_build_object('alert_id',p_alert_id,
    'version',p_expected_version,'status',p_status,'reason',btrim(p_reason))::text,'utf8'),'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
  replay:=app_private.child_safety_receipt(p_request_id,actor,'acknowledge_alert',request_hash);
  if replay is not null then return replay; end if;
  select a.* into current_row from public.child_safety_alerts a
  where a.id=p_alert_id and app_private.child_safety_can_administer(
    a.institution_id,a.unit_id,a.child_context_id
  ) for update;
  if current_row.id is null then raise no_data_found using message='child safety record unavailable'; end if;
  if current_row.version<>p_expected_version then
    raise serialization_failure using message='stale child safety version';
  end if;
  before_state:=jsonb_build_object('status',current_row.status,'version',current_row.version);
  update public.child_safety_alerts set status=p_status::public.child_safety_alert_status,
    acknowledged_by_person_id=actor,acknowledged_at=coalesce(acknowledged_at,now()),
    resolution_reason=case when p_status='resolved' then btrim(p_reason) else resolution_reason end,
    version=version+1,updated_at=now() where id=current_row.id;
  result:=jsonb_build_object('alert_id',current_row.id,'status',p_status,
    'version',current_row.version+1);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    institution_id,outcome,reason,before_json,after_json)
  values(actor,auth.jwt()->>'aal','child_safety.alert.'||p_status,'child_safety_alert',
    current_row.id,current_row.institution_id,'success',btrim(p_reason),before_state,result);
  return app_private.child_safety_store_receipt(
    p_request_id,actor,'acknowledge_alert',request_hash,current_row.id,result
  );
end $$;
create or replace function public.child_safety_acknowledge_alert(
  p_request_id uuid,p_alert_id uuid,p_expected_version bigint,p_status text,p_reason text
) returns jsonb language sql security invoker set search_path=''
as $$ select app_private.child_safety_acknowledge_alert($1,$2,$3,$4,$5) $$;

create or replace function app_private.child_safety_register_evidence(
  p_request_id uuid,p_payload jsonb
) returns jsonb language plpgsql security definer set search_path=''
as $$ declare
  actor uuid:=app_private.current_person_id(); request_hash bytea; replay jsonb;
  evidence_id uuid:=gen_random_uuid(); target_context uuid; target_unit uuid;
  target_institution uuid; authorization_id uuid; restriction_id uuid; alert_id uuid;
  mime text; extension text; object_path text; result jsonb; supplied_size bigint;
  administrative_request boolean;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null
    or not app_private.has_mfa_aal2()
    or jsonb_typeof(p_payload)<>'object' then
    raise insufficient_privilege using message='child safety evidence unavailable';
  end if;
  request_hash:=extensions.digest(convert_to(p_payload::text,'utf8'),'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
  replay:=app_private.child_safety_receipt(p_request_id,actor,'register_evidence',request_hash);
  if replay is not null then return replay; end if;
  begin
    target_context:=(p_payload->>'child_context_id')::uuid;
    target_unit:=(p_payload->>'unit_id')::uuid;
    authorization_id:=nullif(p_payload->>'authorization_id','')::uuid;
    restriction_id:=nullif(p_payload->>'restriction_id','')::uuid;
    alert_id:=nullif(p_payload->>'alert_id','')::uuid;
    supplied_size:=(p_payload->>'size_bytes')::bigint;
  exception when others then raise invalid_parameter_value using message='invalid evidence'; end;
  mime:=p_payload->>'mime_type';
  extension:=case mime when 'image/jpeg' then 'jpg' when 'image/png' then 'png'
    when 'application/pdf' then 'pdf' end;
  if extension is null or num_nonnulls(authorization_id,restriction_id,alert_id)<>1
    or char_length(btrim(coalesce(p_payload->>'file_name',''))) not between 1 and 180
    or coalesce(p_payload->>'checksum_sha256','') !~ '^[0-9a-f]{64}$'
    or supplied_size not between 1 and 10485760 then
    raise invalid_parameter_value using message='invalid evidence';
  end if;
  select c.institution_id into target_institution from public.child_contexts c
  join public.child_unit_links l on l.child_context_id=c.id and l.unit_id=target_unit
    and l.status in ('active','awaiting_allocation')
  where c.id=target_context and c.status='active';
  administrative_request:=app_private.child_safety_can_administer(
    target_institution,target_unit,target_context
  );
  if target_institution is null or not (
    administrative_request or (
      authorization_id is not null
      and app_private.guardian_has_capability(target_context,'manage_authorized_people')
      and exists(select 1 from public.authorized_person_authorizations a
        where a.id=authorization_id and a.institution_id=target_institution
          and a.unit_id=target_unit and a.child_context_id=target_context
          and a.created_by_person_id=actor)
    )
  ) then raise no_data_found using message='child safety record unavailable'; end if;
  object_path:=format('child-safety/%s/%s/%s/%s.%s',target_institution,target_unit,
    target_context,evidence_id,extension);
  insert into public.child_safety_evidence(
    id,institution_id,unit_id,child_context_id,authorization_id,restriction_id,alert_id,
    object_path,file_name,mime_type,size_bytes,checksum_sha256,status,created_by_person_id
  ) values(evidence_id,target_institution,target_unit,target_context,authorization_id,restriction_id,
    alert_id,object_path,btrim(p_payload->>'file_name'),mime,supplied_size,
    p_payload->>'checksum_sha256','draft',actor);
  result:=jsonb_build_object('evidence_id',evidence_id,'bucket_id','child-safety-evidence',
    'object_path',object_path,'status','draft');
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    institution_id,outcome,after_json)
  values(actor,auth.jwt()->>'aal','child_safety.evidence.register','child_safety_evidence',
    evidence_id,target_institution,'success',
    jsonb_build_object('status','draft','mime_type',mime,'size_bytes',supplied_size));
  return app_private.child_safety_store_receipt(
    p_request_id,actor,'register_evidence',request_hash,evidence_id,result
  );
end $$;
create or replace function public.child_safety_register_evidence(p_request_id uuid,p_payload jsonb)
returns jsonb language sql security invoker set search_path=''
as $$ select app_private.child_safety_register_evidence($1,$2) $$;

create or replace function app_private.child_safety_get_evidence_object(p_evidence_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$ declare e public.child_safety_evidence%rowtype; begin
  if (select auth.uid()) is null or not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message='evidence unavailable';
  end if;
  select * into e from public.child_safety_evidence evidence
  where evidence.id=p_evidence_id and evidence.status='active'
    and (app_private.has_platform_permission('child_safety.read')
      or app_private.has_context_permission(evidence.institution_id,'authorized_people.manage',
        evidence.unit_id,null,null,evidence.child_context_id,false));
  if e.id is null then raise no_data_found using message='evidence unavailable'; end if;
  return jsonb_build_object('evidence_id',e.id,'bucket_id',e.bucket_id,
    'object_path',e.object_path,'expires_in_seconds',60);
end $$;
create or replace function public.child_safety_get_evidence_object(p_evidence_id uuid)
returns jsonb language sql stable security invoker set search_path=''
as $$ select app_private.child_safety_get_evidence_object($1) $$;

-- A trusted server-side scanner supplies detected MIME, size and SHA-256. Draft objects
-- are neither downloadable nor usable until this check succeeds.
create or replace function app_private.child_safety_finalize_evidence(
  p_evidence_id uuid,p_detected_mime text,p_detected_size bigint,p_detected_sha256 text
) returns void language plpgsql security definer set search_path=''
as $$ declare e public.child_safety_evidence%rowtype; begin
  select * into e from public.child_safety_evidence where id=p_evidence_id and status='draft'
    for update;
  if e.id is null then raise no_data_found using message='evidence unavailable'; end if;
  if p_detected_mime<>e.mime_type or p_detected_size<>e.size_bytes
     or p_detected_sha256<>e.checksum_sha256 then
    update public.child_safety_evidence set status='inactive',revoked_at=now() where id=e.id;
    return;
  end if;
  update public.child_safety_evidence set status='active' where id=e.id;
end $$;
revoke all on function app_private.child_safety_finalize_evidence(uuid,text,bigint,text)
  from public,anon,authenticated;
grant execute on function app_private.child_safety_finalize_evidence(uuid,text,bigint,text)
  to service_role;

create or replace function app_private.child_safety_can_access_object(
  p_name text,p_write boolean
) returns boolean language sql stable security definer set search_path=''
as $$ select exists(
  select 1 from public.child_safety_evidence e where e.object_path=p_name
    and (not p_write or e.created_by_person_id=app_private.current_person_id())
    and e.status=case when p_write then 'draft'::public.record_status else 'active'::public.record_status end
    and app_private.has_mfa_aal2()
    and (case when p_write then app_private.child_safety_can_manage(
      e.institution_id,e.unit_id,e.child_context_id
    ) else app_private.has_platform_permission('child_safety.read')
      or app_private.has_context_permission(e.institution_id,'authorized_people.manage',
        e.unit_id,null,null,e.child_context_id,false) end)
) $$;
revoke all on function app_private.child_safety_can_access_object(text,boolean)
  from public,anon,authenticated;
grant execute on function app_private.child_safety_can_access_object(text,boolean) to authenticated;
drop policy if exists child_safety_evidence_insert on storage.objects;
create policy child_safety_evidence_insert on storage.objects for insert to authenticated
with check(bucket_id='child-safety-evidence'
  and app_private.child_safety_can_access_object(name,true)
  and coalesce(metadata->>'mimetype','') in ('image/jpeg','image/png','application/pdf'));
drop policy if exists child_safety_evidence_select on storage.objects;
create policy child_safety_evidence_select on storage.objects for select to authenticated
using(bucket_id='child-safety-evidence' and app_private.child_safety_can_access_object(name,false));

create or replace function app_private.superadmin_request_child_safety_export(
  p_request_id uuid,p_format text,p_filters jsonb
) returns jsonb language plpgsql security definer set search_path=''
as $$ declare
  actor uuid:=app_private.current_person_id(); request_hash bytea; replay jsonb;
  job_id uuid; result jsonb; filter_institutions uuid[]; filter_units uuid[];
  filter_search text; filter_segment text;
begin
  perform app_private.assert_child_safety_platform('child_safety.export');
  if p_request_id is null or p_format not in ('csv','json')
     or jsonb_typeof(coalesce(p_filters,'{}'))<>'object'
     or exists(select 1 from jsonb_object_keys(coalesce(p_filters,'{}')) key
       where key not in ('search','institution_ids','unit_ids','segment')) then
    raise invalid_parameter_value using message='invalid child safety export';
  end if;
  if (p_filters ? 'institution_ids' and jsonb_typeof(p_filters->'institution_ids')<>'array')
     or (p_filters ? 'unit_ids' and jsonb_typeof(p_filters->'unit_ids')<>'array')
     or (p_filters ? 'search' and jsonb_typeof(p_filters->'search')<>'string')
     or (p_filters ? 'segment' and jsonb_typeof(p_filters->'segment')<>'string') then
    raise invalid_parameter_value using message='invalid child safety export';
  end if;
  begin
    select coalesce(array_agg(value::uuid),'{}'::uuid[]) into filter_institutions
      from jsonb_array_elements_text(coalesce(p_filters->'institution_ids','[]'::jsonb)) value;
    select coalesce(array_agg(value::uuid),'{}'::uuid[]) into filter_units
      from jsonb_array_elements_text(coalesce(p_filters->'unit_ids','[]'::jsonb)) value;
  exception when others then
    raise invalid_parameter_value using message='invalid child safety export';
  end;
  filter_search:=btrim(coalesce(p_filters->>'search',''));
  filter_segment:=coalesce(nullif(p_filters->>'segment',''),'all');
  if char_length(filter_search)>120 or filter_segment not in (
    'all','awaiting_approval','attention','authorized','without_authorization'
  ) or exists (
    select 1 from public.units u where u.id=any(filter_units)
      and cardinality(filter_institutions)>0 and not u.institution_id=any(filter_institutions)
  ) then raise invalid_parameter_value using message='invalid child safety hierarchy'; end if;
  request_hash:=extensions.digest(convert_to(jsonb_build_object(
    'format',p_format,'filters',coalesce(p_filters,'{}'))::text,'utf8'),'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
  replay:=app_private.child_safety_receipt(p_request_id,actor,'request_export',request_hash);
  if replay is not null then return replay; end if;
  insert into public.import_jobs(
    target_domain,target_table,source_format,source_locale,target_locale,status,summary,created_by
  ) values('child_safety.export','authorized_person_authorizations',p_format,'pt-BR','pt-BR','draft',
    jsonb_build_object('direction','export','filters',coalesce(p_filters,'{}'),
      'template_version','child-safety-export-v1','csv_formula_policy','escape'),actor)
  returning id into job_id;
  result:=jsonb_build_object('job_id',job_id,'status','draft');
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    outcome,after_json)
  values(actor,auth.jwt()->>'aal','child_safety.export.request','import_job',job_id,'success',
    jsonb_build_object('format',p_format,'status','draft'));
  return app_private.child_safety_store_receipt(
    p_request_id,actor,'request_export',request_hash,job_id,result
  );
end $$;
create or replace function public.superadmin_request_child_safety_export(
  p_request_id uuid,p_format text,p_filters jsonb
) returns jsonb language sql security invoker set search_path=''
as $$ select app_private.superadmin_request_child_safety_export($1,$2,$3) $$;

create or replace function app_private.superadmin_get_child_safety_export(p_job_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$ declare actor uuid:=app_private.current_person_id(); job public.import_jobs%rowtype; begin
  perform app_private.assert_child_safety_platform('child_safety.export');
  select * into job from public.import_jobs
    where id=p_job_id and target_domain='child_safety.export' and created_by=actor;
  if job.id is null then raise no_data_found using message='export job unavailable'; end if;
  return jsonb_build_object('job_id',job.id,'status',job.status,'format',job.source_format,
    'summary',job.summary,'created_at',job.created_at,'updated_at',job.updated_at);
end $$;
create or replace function public.superadmin_get_child_safety_export(p_job_id uuid)
returns jsonb language sql stable security invoker set search_path=''
as $$ select app_private.superadmin_get_child_safety_export($1) $$;

-- Direct browser writes remain impossible; every mutation goes through a checked command.
revoke all on public.authorized_people,public.authorized_person_authorizations,
  public.authorized_person_authorization_capabilities,public.child_safety_restrictions,
  public.child_safety_alerts,public.child_safety_evidence from anon,authenticated;
-- Reads also go through the aggregate RPCs. Granting raw SELECT here would let
-- callers bypass AAL2 and retrieve non-minimized PII columns from authorized_people.

drop policy if exists authorized_people_context_read on public.authorized_people;
create policy authorized_people_context_read on public.authorized_people
for select to authenticated using(exists(
  select 1 from public.authorized_person_authorizations a
  where a.authorized_person_id=authorized_people.id and(
    app_private.has_platform_permission('child_safety.read')
    or app_private.guardian_has_capability(a.child_context_id,'manage_authorized_people')
    or app_private.has_context_permission(a.institution_id,'authorized_people.manage',
      a.unit_id,null,null,a.child_context_id,false))
));
drop policy if exists authorized_person_authorizations_context_read
  on public.authorized_person_authorizations;
create policy authorized_person_authorizations_context_read
on public.authorized_person_authorizations for select to authenticated using(
  app_private.has_platform_permission('child_safety.read')
  or app_private.guardian_has_capability(child_context_id,'manage_authorized_people')
  or app_private.has_context_permission(institution_id,'authorized_people.manage',
    unit_id,null,null,child_context_id,false)
);
drop policy if exists authorized_person_authorization_capabilities_context_read
  on public.authorized_person_authorization_capabilities;
create policy authorized_person_authorization_capabilities_context_read
on public.authorized_person_authorization_capabilities for select to authenticated using(
  exists(select 1 from public.authorized_person_authorizations a
    where a.id=authorization_id and(
      app_private.has_platform_permission('child_safety.read')
      or app_private.guardian_has_capability(a.child_context_id,'manage_authorized_people')
      or app_private.has_context_permission(a.institution_id,'authorized_people.manage',
        a.unit_id,null,null,a.child_context_id,false)))
);
drop policy if exists child_safety_restrictions_context_read on public.child_safety_restrictions;
create policy child_safety_restrictions_context_read on public.child_safety_restrictions
for select to authenticated using(
  app_private.has_platform_permission('child_safety.read')
  or app_private.has_context_permission(institution_id,'authorized_people.manage',
    unit_id,null,null,child_context_id,false)
);
drop policy if exists child_safety_alerts_context_read on public.child_safety_alerts;
create policy child_safety_alerts_context_read on public.child_safety_alerts
for select to authenticated using(
  app_private.has_platform_permission('child_safety.read')
  or app_private.has_context_permission(institution_id,'authorized_people.manage',
    unit_id,null,null,child_context_id,false)
);
drop policy if exists child_safety_evidence_context_read on public.child_safety_evidence;
create policy child_safety_evidence_context_read on public.child_safety_evidence
for select to authenticated using(status='active' and(
  app_private.has_platform_permission('child_safety.read')
  or app_private.has_context_permission(institution_id,'authorized_people.manage',
    unit_id,null,null,child_context_id,false))
);

do $$ declare table_name text; begin
  foreach table_name in array array['authorized_people','authorized_person_authorizations',
    'authorized_person_authorization_capabilities','child_safety_restrictions',
    'child_safety_alerts','child_safety_evidence'] loop
    execute format('drop policy if exists %I on public.%I',table_name||'_deny_insert',table_name);
    execute format('create policy %I on public.%I for insert to authenticated with check(false)',
      table_name||'_deny_insert',table_name);
    execute format('drop policy if exists %I on public.%I',table_name||'_deny_update',table_name);
    execute format('create policy %I on public.%I for update to authenticated using(false) with check(false)',
      table_name||'_deny_update',table_name);
    execute format('drop policy if exists %I on public.%I',table_name||'_deny_delete',table_name);
    execute format('create policy %I on public.%I for delete to authenticated using(false)',
      table_name||'_deny_delete',table_name);
  end loop;
end $$;

-- Necessary grants: a SECURITY INVOKER wrapper cannot call a private function otherwise.
-- app_private is not exposed by the Data API; every granted function checks auth/scope/AAL.
revoke all on function
  app_private.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,jsonb),
  app_private.superadmin_child_safety_search_children(text,integer),
  app_private.superadmin_child_safety_get(uuid),
  app_private.child_safety_request_authorization(uuid,jsonb),
  app_private.child_safety_edit_pending_authorization(uuid,uuid,bigint,jsonb),
  app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text),
  app_private.child_safety_change_lifecycle(uuid,uuid,bigint,text,text),
  app_private.child_safety_save_restriction(uuid,jsonb),
  app_private.child_safety_acknowledge_alert(uuid,uuid,bigint,text,text),
  app_private.child_safety_register_evidence(uuid,jsonb),
  app_private.child_safety_get_evidence_object(uuid),
  app_private.superadmin_request_child_safety_export(uuid,text,jsonb),
  app_private.superadmin_get_child_safety_export(uuid)
from public,anon,authenticated;
grant execute on function
  app_private.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,jsonb),
  app_private.superadmin_child_safety_search_children(text,integer),
  app_private.superadmin_child_safety_get(uuid),
  app_private.child_safety_request_authorization(uuid,jsonb),
  app_private.child_safety_edit_pending_authorization(uuid,uuid,bigint,jsonb),
  app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text),
  app_private.child_safety_change_lifecycle(uuid,uuid,bigint,text,text),
  app_private.child_safety_save_restriction(uuid,jsonb),
  app_private.child_safety_acknowledge_alert(uuid,uuid,bigint,text,text),
  app_private.child_safety_register_evidence(uuid,jsonb),
  app_private.child_safety_get_evidence_object(uuid),
  app_private.superadmin_request_child_safety_export(uuid,text,jsonb),
  app_private.superadmin_get_child_safety_export(uuid)
to authenticated;

revoke all on function
  public.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,jsonb),
  public.superadmin_child_safety_search_children(text,integer),
  public.superadmin_child_safety_get(uuid),
  public.superadmin_child_safety_child_search(text,integer),
  public.superadmin_child_safety_detail(uuid),
  public.child_safety_request_authorization(uuid,jsonb),
  public.child_safety_edit_pending_authorization(uuid,uuid,bigint,jsonb),
  public.child_safety_decide_authorization(uuid,uuid,bigint,text,text),
  public.child_safety_change_lifecycle(uuid,uuid,bigint,text,text),
  public.child_safety_save_restriction(uuid,jsonb),
  public.child_safety_acknowledge_alert(uuid,uuid,bigint,text,text),
  public.child_safety_register_evidence(uuid,jsonb),
  public.child_safety_get_evidence_object(uuid),
  public.superadmin_request_child_safety_export(uuid,text,jsonb),
  public.superadmin_get_child_safety_export(uuid)
from public,anon;
grant execute on function
  public.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,jsonb),
  public.superadmin_child_safety_search_children(text,integer),
  public.superadmin_child_safety_get(uuid),
  public.superadmin_child_safety_child_search(text,integer),
  public.superadmin_child_safety_detail(uuid),
  public.child_safety_request_authorization(uuid,jsonb),
  public.child_safety_edit_pending_authorization(uuid,uuid,bigint,jsonb),
  public.child_safety_decide_authorization(uuid,uuid,bigint,text,text),
  public.child_safety_change_lifecycle(uuid,uuid,bigint,text,text),
  public.child_safety_save_restriction(uuid,jsonb),
  public.child_safety_acknowledge_alert(uuid,uuid,bigint,text,text),
  public.child_safety_register_evidence(uuid,jsonb),
  public.child_safety_get_evidence_object(uuid),
  public.superadmin_request_child_safety_export(uuid,text,jsonb),
  public.superadmin_get_child_safety_export(uuid)
to authenticated;
