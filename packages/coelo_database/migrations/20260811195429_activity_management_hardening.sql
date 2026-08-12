-- Final activity management hardening: deterministic handles and activity-scoped admins.
begin;

create or replace function app_private.activity_slugify(value text)
returns text language sql immutable set search_path=''
as $$
 select trim(both '-' from regexp_replace(
  translate(lower(coalesce(value,'')),
   'áàâãäéèêëíìîïóòôõöúùûüçñ',
   'aaaaaeeeeiiiiooooouuuucn'),
  '[^a-z0-9]+','-','g'))
$$;
revoke all on function app_private.activity_slugify(text) from public,anon,authenticated;

update public.activity_definitions
set handle_stem=coalesce(nullif(left(app_private.activity_slugify(name),48),''),
 'atividade')||'-'||left(id::text,6),
 identity_initials=coalesce(nullif(upper(left(regexp_replace(
  translate(name,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ',
   'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN'),
  '[^[:alnum:]]','','g'),2)),''),'AT');

insert into public.activity_capabilities(code,name,description,status)
values('attendance','Chamada','Ver ou editar chamada da atividade por turma.','active')
on conflict do nothing;
update public.activity_capabilities set name='Chamada',
 description='Ver ou editar chamada da atividade por turma.',
 status='active',updated_at=now() where code='attendance';

alter table public.activity_assignment_capability_actions
 drop constraint if exists activity_assignment_capability_actions_check;

create table public.activity_admin_assignments(
 id uuid primary key default gen_random_uuid(),
 activity_id uuid not null,
 institution_id uuid not null,
 person_id uuid not null references public.people(id) on delete cascade,
 membership_id uuid not null,
 assignment_role text not null default 'activity_admin'
  check(assignment_role='activity_admin'),
 status public.record_status not null default 'active',
 assigned_by_person_id uuid not null references public.people(id) on delete restrict,
 assigned_at timestamptz not null default now(),
 revoked_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint activity_admin_assignments_activity_fkey
  foreign key(activity_id,institution_id)
  references public.activity_definitions(id,institution_id) on delete cascade,
 constraint activity_admin_assignments_membership_fkey
  foreign key(membership_id,institution_id,person_id)
  references public.institution_memberships(id,institution_id,person_id) on delete restrict,
 constraint activity_admin_assignments_revocation_check check(
  (status in ('inactive','suspended','archived') and revoked_at is not null)
  or (status in ('draft','active') and revoked_at is null))
);
create unique index activity_admin_assignments_active_uidx
 on public.activity_admin_assignments(activity_id,person_id)
 where status='active' and revoked_at is null;
create index activity_admin_assignments_person_status_idx
 on public.activity_admin_assignments(person_id,status);
create index activity_admin_assignments_membership_idx
 on public.activity_admin_assignments(membership_id);

alter table public.activity_admin_assignments enable row level security;
alter table public.activity_admin_assignments force row level security;
revoke all on public.activity_admin_assignments from public,anon,authenticated;
grant select on public.activity_admin_assignments to authenticated;
grant all on public.activity_admin_assignments to service_role;
create policy activity_admin_assignments_authorized_read
on public.activity_admin_assignments for select to authenticated
using(person_id=app_private.current_person_id()
 or (select app_private.has_platform_permission('activities.read'))
 or app_private.has_institution_permission(
   institution_id,'activities.read',null,null,true));

create trigger activity_admin_assignments_updated_at
before update on public.activity_admin_assignments
for each row execute function app_private.set_activity_updated_at();
create trigger activity_admin_assignments_audit
after insert or update or delete on public.activity_admin_assignments
for each row execute function app_private.audit_activity_change();

create or replace function app_private.has_activity_identity_upload_intent(object_name text)
returns boolean language sql stable security definer set search_path=''
as $$
 select exists(
  select 1 from app_private.activity_identity_upload_intents intent
  where intent.storage_path=object_name
   and intent.activity_id=app_private.storage_activity_id(object_name)
   and intent.actor_person_id=app_private.current_person_id()
   and intent.expires_at>now() and intent.consumed_at is null)
$$;
revoke all on function app_private.has_activity_identity_upload_intent(text)
 from public,anon,authenticated;
grant execute on function app_private.has_activity_identity_upload_intent(text)
 to authenticated;

drop policy if exists activity_identity_insert on storage.objects;
create policy activity_identity_insert on storage.objects for insert to authenticated
with check(bucket_id='coelo-identities'
 and app_private.has_activity_identity_upload_intent(name));
drop policy if exists activity_identity_update on storage.objects;
create policy activity_identity_update on storage.objects for update to authenticated
using(bucket_id='coelo-identities'
 and app_private.has_activity_identity_upload_intent(name))
with check(bucket_id='coelo-identities'
 and app_private.has_activity_identity_upload_intent(name));

insert into public.schema_tables(
 schema_name,table_name,table_label,table_description,domain,status,version
) values
 ('public','activity_taxonomies','Taxonomia de atividades',
  'Categorias e subtipos globais curados.','activities','active',1),
 ('public','activity_locations','Locais de atividades',
  'Locais físicos pertencentes a uma unidade.','activities','active',1),
 ('public','activity_templates','Modelos de atividades',
  'Modelos globais ou institucionais duplicáveis.','activities','active',1),
 ('public','activity_admin_assignments','Admins de atividades',
  'Profissionais com escopo administrativo na atividade inteira.','activities','active',1)
on conflict(schema_name,table_name,version) do update set
 table_label=excluded.table_label,table_description=excluded.table_description,
 domain=excluded.domain,status='active',updated_at=now();

create or replace function app_private.superadmin_activity_detail(p_activity_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 if (select auth.uid()) is null or
    not app_private.has_platform_permission('activities.read') then
  raise insufficient_privilege using message='activities.read required';
 end if;
 select app_private.activity_management_payload(p_activity_id)||
  jsonb_build_object(
   'participants',coalesce((select jsonb_agg(jsonb_build_object(
     'id',participant.id,'activity_group_link_id',participant.activity_group_link_id,
     'child_group_link_id',participant.child_group_link_id,'status',participant.status)
     order by participant.created_at)
    from public.activity_group_participants participant
    join public.activity_group_links group_link
     on group_link.id=participant.activity_group_link_id
    where group_link.activity_id=p_activity_id),'[]'::jsonb),
   'professional_assignments',coalesce((select jsonb_agg(jsonb_build_object(
     'id',assignment.id,'group_id',group_link.group_id,
     'person_id',assignment.person_id,'membership_id',assignment.membership_id,
     'role',assignment.assignment_role,'display_name',person.display_name,
     'capabilities',coalesce((select jsonb_object_agg(
       capability.code,case when action.can_view and action.can_edit then 'both'
        when action.can_view then 'view' when action.can_edit then 'edit' else 'none' end)
      from public.activity_assignment_capability_actions action
      join public.activity_capabilities capability on capability.id=action.capability_id
      where action.assignment_id=assignment.id),'{}'::jsonb))
      order by person.display_name,group_link.group_id)
    from public.activity_group_assignments assignment
    join public.activity_group_links group_link
     on group_link.id=assignment.activity_group_link_id
    join public.people person on person.id=assignment.person_id
    where group_link.activity_id=p_activity_id
     and assignment.status='active' and assignment.revoked_at is null),'[]'::jsonb),
   'activity_admins',coalesce((select jsonb_agg(jsonb_build_object(
     'id',admin.id,'person_id',admin.person_id,'membership_id',admin.membership_id,
     'role',admin.assignment_role,'display_name',person.display_name)
     order by person.display_name)
    from public.activity_admin_assignments admin
    join public.people person on person.id=admin.person_id
    where admin.activity_id=p_activity_id
     and admin.status='active' and admin.revoked_at is null),'[]'::jsonb)
  ) into result
 from public.activity_definitions activity where activity.id=p_activity_id;
 if result is null then raise no_data_found using message='activity not found'; end if;
 return result;
end $$;

create or replace function public.superadmin_activity_detail(p_activity_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$select app_private.superadmin_activity_detail(p_activity_id)$$;
revoke all on function app_private.superadmin_activity_detail(uuid)
 from public,anon,authenticated,service_role;
revoke all on function public.superadmin_activity_detail(uuid)
 from public,anon,authenticated,service_role;
grant execute on function public.superadmin_activity_detail(uuid) to authenticated;

commit;