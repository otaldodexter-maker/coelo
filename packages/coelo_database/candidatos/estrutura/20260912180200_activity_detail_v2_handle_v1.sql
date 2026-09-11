-- R06 estrutura: activity_detail_v2_handle_v1
-- superadmin_activity_detail_v2 (180060) passa a devolver handle_stem,
-- canonical_handle e handle_last_changed_at no objeto `activity`, para o
-- campo "@ da atividade" abrir preenchido na edicao (Decisao 16). Chave
-- aditiva: o parser do cliente tolera chaves novas desde 01a8c3e27 (R05).
-- Sem mudar assinatura, grants ou regra.
-- Reversao: reaplicar o corpo de 20260910180060.

do $guard$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'must run as postgres';
  end if;
  if to_regprocedure('public.superadmin_activity_detail_v2(uuid,text[])') is null
    or not exists (select 1 from information_schema.columns where table_schema='public' and table_name='activity_definitions' and column_name='handle_last_changed_at') then
    raise feature_not_supported using message = 'activity detail v2 (180060) and structure_handles_v1 (20260911180000) are required';
  end if;
end
$guard$;

create or replace function public.superadmin_activity_detail_v2(p_activity_id uuid,p_sections text[] default '{}')
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; a public.activity_definitions%rowtype; correlation uuid:=gen_random_uuid();
 result jsonb; section text; code text;
begin begin
 select * into strict ctx from app_private.activity_v2_require_context('activities.read',null);
 if p_activity_id is null or p_sections is null then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id
   and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id);
 if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.read',a.institution_id);
 if coalesce(array_length(p_sections,1),0)<>(select count(distinct x) from unnest(p_sections) x)
    or exists(select 1 from unnest(p_sections) x where x not in('participants','professionals','permissions')) then
  raise invalid_parameter_value using message='unknown or duplicate section',detail='ACTIVITY_INVALID_INPUT'; end if;
 foreach section in array p_sections loop
  if section in('participants','professionals') then perform app_private.activity_v2_require_context('activities.assign_people',a.institution_id);
  else perform app_private.activity_v2_require_context('activities.manage_permissions',a.institution_id); end if;
 end loop;
 result:=pg_catalog.jsonb_build_object('activity',pg_catalog.jsonb_build_object(
  'activity_id',a.id,'institution_id',a.institution_id,'name',a.name,'description',a.description,
  'handle_stem',a.handle_stem,'canonical_handle',a.canonical_handle,'handle_last_changed_at',a.handle_last_changed_at,
  'taxonomy_id',a.taxonomy_id,'taxonomy_name',(select t.name from public.activity_taxonomies t where t.id=a.taxonomy_id),
  'status',a.status,'management_version',a.management_version,'icon_key',a.identity_icon,'initials',a.identity_initials,
  'created_at',a.created_at,'updated_at',a.updated_at),
  'units',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('unit_id',u.id,'name',u.name,'status',l.status) order by u.name) from public.activity_unit_links l join public.units u on u.id=l.unit_id where l.activity_id=a.id and l.status='active'),'[]'::jsonb),
  'groups',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('group_id',g.id,'unit_id',g.unit_id,'name',g.name,'status',l.status,'participation_mode',l.participation_mode) order by g.name) from public.activity_group_links l join public.groups g on g.id=l.group_id where l.activity_id=a.id and l.status='active'),'[]'::jsonb),
  'counts',pg_catalog.jsonb_build_object('units',(select count(*) from public.activity_unit_links l where l.activity_id=a.id and l.status='active'),'groups',(select count(*) from public.activity_group_links l where l.activity_id=a.id and l.status='active'),'participants',(select count(*) from public.activity_group_participants p join public.activity_group_links l on l.id=p.activity_group_link_id where l.activity_id=a.id and p.status='active' and p.removed_at is null),'instructors',(select count(*) from public.activity_group_assignments p join public.activity_group_links l on l.id=p.activity_group_link_id where l.activity_id=a.id and p.status='active' and p.assignment_role='instructor'),'activity_admins',(select count(*) from public.activity_admin_assignments p where p.activity_id=a.id and p.status='active')));
 if 'participants'=any(p_sections) then result:=result||pg_catalog.jsonb_build_object('participants',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('child_group_link_id',p.child_group_link_id,'group_id',gl.group_id,'display_name',person.display_name,'status',p.status)) from public.activity_group_participants p join public.activity_group_links gl on gl.id=p.activity_group_link_id join public.child_group_links cgl on cgl.id=p.child_group_link_id and cgl.group_id=gl.group_id and cgl.status='active' join public.child_unit_links cul on cul.id=cgl.child_unit_link_id and cul.unit_id=gl.unit_id and cul.status='active' join public.child_contexts cc on cc.id=cul.child_context_id and cc.institution_id=a.institution_id and cc.status='active' join public.people person on person.id=cc.child_person_id and person.person_type='child' and person.status='active' where gl.activity_id=a.id and gl.status='active' and p.status='active' and p.removed_at is null),'[]'::jsonb)); end if;
 if 'professionals'=any(p_sections) then result:=result||pg_catalog.jsonb_build_object('professionals',coalesce((select jsonb_agg(item) from(
  select pg_catalog.jsonb_build_object('membership_id',x.membership_id,'role','instructor','group_id',gl.group_id,'display_name',p.display_name,'status',x.status) item from public.activity_group_assignments x join public.activity_group_links gl on gl.id=x.activity_group_link_id and gl.institution_id=a.institution_id and gl.status='active' join public.groups g on g.id=gl.group_id and g.institution_id=a.institution_id and g.unit_id=gl.unit_id and g.status='active' join public.institution_memberships m on m.id=x.membership_id and m.person_id=x.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null join public.people p on p.id=x.person_id and p.person_type='adult' and p.status='active' where gl.activity_id=a.id and x.institution_id=a.institution_id and x.status='active' and x.revoked_at is null and x.assignment_role='instructor'
  union all select pg_catalog.jsonb_build_object('membership_id',x.membership_id,'role','activity_admin','group_id',null,'display_name',p.display_name,'status',x.status) from public.activity_admin_assignments x join public.institution_memberships m on m.id=x.membership_id and m.person_id=x.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null join public.people p on p.id=x.person_id and p.person_type='adult' and p.status='active' where x.activity_id=a.id and x.institution_id=a.institution_id and x.status='active' and x.revoked_at is null) q),'[]'::jsonb)); end if;
 if 'permissions'=any(p_sections) then result:=result||pg_catalog.jsonb_build_object('permissions',pg_catalog.jsonb_build_object(
  'policies',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('code',c.code,'mode',p.policy_mode)) from public.activity_capability_policies p join public.activity_capabilities c on c.id=p.capability_id where p.activity_id=a.id),'[]'::jsonb),
  'group_settings',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('group_id',gl.group_id,'code',c.code,'enabled',s.is_enabled)) from public.activity_group_capability_settings s join public.activity_group_links gl on gl.id=s.activity_group_link_id join public.activity_capabilities c on c.id=s.capability_id where gl.activity_id=a.id),'[]'::jsonb),
  'professional_actions',coalesce((select jsonb_agg(item order by role,membership_id,group_id nulls first) from(
    select ga.membership_id,'instructor'::text role,gl.group_id,
      pg_catalog.jsonb_build_object('membership_id',ga.membership_id,'role','instructor','group_id',gl.group_id,
        'actions',coalesce((select jsonb_object_agg(c.code,case when action.can_view and action.can_edit then 'both' when action.can_edit then 'edit' when action.can_view then 'view' else 'none' end order by c.code)
          from public.activity_assignment_capability_actions action join public.activity_capabilities c on c.id=action.capability_id
          where action.assignment_id=ga.id and c.code in('chat','now','happens','moments','attendance')),'{}'::jsonb)) item
    from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id and gl.institution_id=a.institution_id and gl.status='active'
    join public.groups g on g.id=gl.group_id and g.institution_id=a.institution_id and g.unit_id=gl.unit_id and g.status='active'
    join public.institution_memberships m on m.id=ga.membership_id and m.person_id=ga.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null
    join public.people person on person.id=ga.person_id and person.person_type='adult' and person.status='active'
    where gl.activity_id=a.id and ga.institution_id=a.institution_id and ga.status='active' and ga.revoked_at is null and ga.assignment_role='instructor'
    union all
    select aa.membership_id,'activity_admin'::text role,null::uuid group_id,
      pg_catalog.jsonb_build_object('membership_id',aa.membership_id,'role','activity_admin','group_id',null,
        'actions',coalesce((select jsonb_object_agg(c.code,case when action.can_view and action.can_edit then 'both' when action.can_edit then 'edit' when action.can_view then 'view' else 'none' end order by c.code)
          from public.activity_admin_capability_actions action join public.activity_capabilities c on c.id=action.capability_id
          where action.activity_admin_assignment_id=aa.id and c.code in('chat','now','happens','moments','attendance')),'{}'::jsonb)) item
    from public.activity_admin_assignments aa
    join public.institution_memberships m on m.id=aa.membership_id and m.person_id=aa.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null
    join public.people person on person.id=aa.person_id and person.person_type='adult' and person.status='active'
    where aa.activity_id=a.id and aa.institution_id=a.institution_id and aa.status='active' and aa.revoked_at is null
  ) actions),'[]'::jsonb))); end if;
  return app_private.activity_v2_success_envelope(result);
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.read','activity.detail',code,correlation,case when a.id is null then null else a.institution_id end); end $$;
