-- ACTIVITY-LINK-END-CLOCK-V1. End freshly-created links strictly after starts_at,
-- including when an aggregate swap runs inside the transaction that created them.
begin;

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using
      message='ACTIVITY-LINK-END-CLOCK-V1 must be applied as postgres';
  end if;
  if pg_catalog.to_regprocedure(
      'public.superadmin_activity_set_units_v2(uuid,uuid,bigint,uuid[])') is null
    or pg_catalog.to_regprocedure(
      'public.superadmin_activity_set_groups_v2(uuid,uuid,bigint,uuid[],jsonb)') is null then
    raise object_not_in_prerequisite_state using
      message='ACTIVITY-LINK-END-CLOCK-V1 requires the canonical Activities v2 gateways';
  end if;
end
$preflight$;

create or replace function public.superadmin_activity_set_units_v2(p_request_id uuid,p_activity_id uuid,p_expected_version bigint,p_unit_ids uuid[])
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text;
begin begin select * into strict ctx from app_private.activity_v2_require_context('activities.link_units',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 or p_unit_ids is null then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.link_units',a.institution_id);
 if coalesce(cardinality(p_unit_ids),0) not between 1 and 100 or cardinality(p_unit_ids)<>(select count(distinct x) from unnest(p_unit_ids)x) then raise invalid_parameter_value using message='duplicate unit',detail='ACTIVITY_INVALID_INPUT'; end if;
 h:=app_private.activity_v2_command_request_hash('activity.set_units',a.institution_id,a.id,p_expected_version,to_jsonb(p_unit_ids)); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.set_units',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
 perform 1 from public.units u where u.id=any(p_unit_ids) order by u.id for share;
 perform 1 from public.activity_unit_links ul where ul.activity_id=a.id order by ul.id for update;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for share;
 if exists(select 1 from public.activity_group_links gl join public.activity_unit_links ul on ul.activity_id=gl.activity_id and ul.unit_id=gl.unit_id where gl.activity_id=a.id and gl.status='active' and not(gl.unit_id=any(p_unit_ids))) then raise integrity_constraint_violation using detail='ACTIVITY_DEPENDENCIES_ACTIVE'; end if;
 if (select count(*) from public.units u where u.id=any(p_unit_ids) and u.institution_id=a.institution_id and u.status='active')<>cardinality(p_unit_ids) then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.link_units','link_units',correlation); update public.activity_unit_links l set status='inactive',ends_at=greatest(pg_catalog.clock_timestamp(),l.starts_at+interval '1 microsecond'),updated_at=now() where l.activity_id=a.id and l.status='active' and not(l.unit_id=any(p_unit_ids));
 insert into public.activity_unit_links(activity_id,institution_id,unit_id,linked_by_person_id,status,ends_at) select a.id,a.institution_id,x,null,'active',null from unnest(p_unit_ids)x on conflict(activity_id,unit_id) do update set status='active',ends_at=null,updated_at=now();
 update public.activity_definitions x set management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.link_units','activity.set_units',pg_catalog.jsonb_build_object('units',cardinality(p_unit_ids))); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.set_units',h,a.management_version,a.status::text,correlation,pg_catalog.jsonb_build_object('units',cardinality(p_unit_ids)));
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.link_units','activity.set_units',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

create or replace function public.superadmin_activity_set_groups_v2(p_request_id uuid,p_activity_id uuid,p_expected_version bigint,p_group_ids uuid[],p_group_participation jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text;
begin begin select * into strict ctx from app_private.activity_v2_require_context('activities.link_groups',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 or p_group_ids is null or jsonb_typeof(p_group_participation) is distinct from 'object' then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.link_groups',a.institution_id);
 if coalesce(cardinality(p_group_ids),0)>200 or jsonb_typeof(p_group_participation)<>'object' or cardinality(p_group_ids)<>(select count(distinct x) from unnest(p_group_ids)x) or (select coalesce(array_agg(k order by k),'{}') from jsonb_object_keys(p_group_participation)k)<>(select coalesce(array_agg(x::text order by x::text),'{}') from unnest(p_group_ids)x) or exists(select 1 from jsonb_each_text(p_group_participation)x where value not in('all','selected')) then raise invalid_parameter_value using message='duplicate group',detail='ACTIVITY_INVALID_INPUT'; end if;
 h:=app_private.activity_v2_command_request_hash('activity.set_groups',a.institution_id,a.id,p_expected_version,pg_catalog.jsonb_build_object('group_ids',p_group_ids,'participation',p_group_participation)); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.set_groups',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
 perform 1 from public.groups g where g.id=any(p_group_ids) order by g.id for share;
 perform 1 from public.activity_unit_links ul where ul.activity_id=a.id order by ul.id for share;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for update;
 perform 1 from public.activity_group_participants participant where participant.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by participant.id for share;
 perform 1 from public.activity_group_assignments assignment where assignment.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by assignment.id for share;
 perform 1 from public.activity_group_capability_settings setting where setting.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by setting.id for share;
 if exists(select 1 from public.activity_group_links gl where gl.activity_id=a.id and gl.status='active' and not(gl.group_id=any(p_group_ids)) and (exists(select 1 from public.activity_group_participants p where p.activity_group_link_id=gl.id and p.status='active') or exists(select 1 from public.activity_group_assignments p where p.activity_group_link_id=gl.id and p.status='active') or exists(select 1 from public.activity_group_capability_settings p where p.activity_group_link_id=gl.id))) then raise integrity_constraint_violation using detail='ACTIVITY_DEPENDENCIES_ACTIVE'; end if;
 if exists(select 1 from unnest(p_group_ids)x left join public.groups g on g.id=x and g.institution_id=a.institution_id and g.status='active' left join public.activity_unit_links ul on ul.activity_id=a.id and ul.unit_id=g.unit_id and ul.status='active' where g.id is null or ul.id is null) then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 if exists(select 1 from public.activity_group_links gl join public.activity_group_participants p on p.activity_group_link_id=gl.id and p.status='active' where gl.activity_id=a.id and gl.group_id=any(p_group_ids) and gl.participation_mode='selected' and p_group_participation->>gl.group_id::text='all') then raise integrity_constraint_violation using detail='ACTIVITY_DEPENDENCIES_ACTIVE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.link_groups','link_groups',correlation); update public.activity_group_links gl set status='inactive',ends_at=greatest(pg_catalog.clock_timestamp(),gl.starts_at+interval '1 microsecond'),updated_at=now() where gl.activity_id=a.id and gl.status='active' and not(gl.group_id=any(p_group_ids));
 insert into public.activity_group_links(activity_id,institution_id,unit_id,group_id,linked_by_person_id,status,ends_at,participation_mode) select a.id,a.institution_id,g.unit_id,g.id,null,'active',null,p_group_participation->>g.id::text from public.groups g where g.id=any(p_group_ids) on conflict(activity_id,group_id) do update set status='active',ends_at=null,participation_mode=excluded.participation_mode,updated_at=now();
 update public.activity_definitions x set management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.link_groups','activity.set_groups',pg_catalog.jsonb_build_object('groups',cardinality(p_group_ids))); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.set_groups',h,a.management_version,a.status::text,correlation,pg_catalog.jsonb_build_object('groups',cardinality(p_group_ids)));
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.link_groups','activity.set_groups',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

commit;
