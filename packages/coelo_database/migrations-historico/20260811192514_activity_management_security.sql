-- Privileged Superadmin activity management: schema, taxonomy, identity and RLS.
begin;

insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status,updated_at
) values
 ('activities.read','activities','directory','read','Visualizar atividades e relações autorizadas.','normal',false,'active',now()),
 ('activities.create','activities','management','create','Criar atividades de forma auditada.','high',true,'active',now()),
 ('activities.manage','activities','management','manage','Editar e alterar status de atividades.','high',true,'active',now()),
 ('activities.link_units','activities','structure','manage','Vincular atividades a unidades.','high',true,'active',now()),
 ('activities.link_groups','activities','relationships','manage','Vincular atividades a turmas.','high',true,'active',now()),
 ('activities.assign_people','activities','people','manage','Gerenciar alunos e profissionais vinculados.','critical',true,'active',now()),
 ('activities.manage_permissions','activities','permissions','manage','Gerenciar capacidades contextuais.','critical',true,'active',now()),
 ('activities.import','activities','files','import','Importar atividades por job auditado.','critical',true,'active',now()),
 ('activities.export','activities','files','export','Exportar atividades por job auditado.','high',true,'active',now()),
 ('activities.templates.manage','activities','templates','manage','Gerenciar modelos de atividades.','high',true,'active',now()),
 ('activities.taxonomy.manage','activities','taxonomy','manage','Gerenciar categorias e subtipos globais.','high',true,'active',now())
on conflict(code) do update set module_code=excluded.module_code,screen_code=excluded.screen_code,
 action_code=excluded.action_code,description=excluded.description,risk_level=excluded.risk_level,
 requires_mfa=excluded.requires_mfa,status='active',updated_at=now();

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='owner' and permission_record.code like 'activities.%'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='operations'
 and permission_record.code in ('activities.read','activities.taxonomy.manage')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

create table public.activity_taxonomies(
 id uuid primary key default gen_random_uuid(),
 parent_id uuid references public.activity_taxonomies(id) on delete restrict,
 code text not null unique,
 taxonomy_kind text not null check(taxonomy_kind in ('category','subtype')),
 name text not null,
 description text,
 sort_order integer not null default 0,
 status public.record_status not null default 'active',
 created_by_person_id uuid references public.people(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check(btrim(code)<>'' and code=lower(code) and code ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
 check(btrim(name)<>'' and length(name)<=120),
 check((taxonomy_kind='category' and parent_id is null) or
       (taxonomy_kind='subtype' and parent_id is not null))
);
create index activity_taxonomies_parent_status_idx
 on public.activity_taxonomies(parent_id,status,sort_order);

create table public.activity_taxonomy_requests(
 id uuid primary key default gen_random_uuid(),
 institution_id uuid not null references public.institutions(id) on delete cascade,
 requested_name text not null check(btrim(requested_name)<>'' and length(requested_name)<=120),
 requested_description text not null check(btrim(requested_description)<>'' and length(requested_description)<=500),
 status public.record_status not null default 'draft',
 created_by_person_id uuid not null references public.people(id) on delete restrict,
 reviewed_by_person_id uuid references public.people(id) on delete restrict,
 reviewed_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index activity_taxonomy_requests_institution_status_idx
 on public.activity_taxonomy_requests(institution_id,status,created_at desc);

create table public.activity_handle_aliases(
 id uuid primary key default gen_random_uuid(),
 activity_id uuid not null references public.activity_definitions(id) on delete cascade,
 alias text not null check(alias=lower(alias) and alias ~ '^[a-z0-9-]+(?:\.[a-z0-9-]+)+$'),
 created_at timestamptz not null default now()
);
create unique index activity_handle_aliases_alias_uidx
 on public.activity_handle_aliases(lower(alias));
create index activity_handle_aliases_activity_idx on public.activity_handle_aliases(activity_id);

create table public.activity_locations(
 id uuid primary key default gen_random_uuid(),
 institution_id uuid not null references public.institutions(id) on delete cascade,
 unit_id uuid not null,
 name text not null check(btrim(name)<>'' and length(name)<=120),
 description text check(description is null or length(description)<=500),
 status public.record_status not null default 'active',
 management_version bigint not null default 1 check(management_version>0),
 created_by_person_id uuid not null references public.people(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint activity_locations_id_institution_unit_key unique(id,institution_id,unit_id),
 constraint activity_locations_unit_institution_fkey foreign key(unit_id,institution_id)
   references public.units(id,institution_id) on delete cascade
);
create unique index activity_locations_active_name_uidx
 on public.activity_locations(unit_id,lower(name)) where status<>'archived';
create index activity_locations_institution_unit_status_idx
 on public.activity_locations(institution_id,unit_id,status,name);

create table public.activity_templates(
 id uuid primary key default gen_random_uuid(),
 scope_kind text not null check(scope_kind in ('platform','institution')),
 institution_id uuid references public.institutions(id) on delete cascade,
 code text not null check(code=lower(code) and code ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
 name text not null check(btrim(name)<>'' and length(name)<=120),
 description text,
 taxonomy_id uuid not null references public.activity_taxonomies(id) on delete restrict,
 governance_kind text not null default 'optional' check(governance_kind in ('optional','mandatory')),
 template_payload jsonb not null default '{}'::jsonb check(jsonb_typeof(template_payload)='object'),
 status public.record_status not null default 'active',
 created_by_person_id uuid references public.people(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check((scope_kind='platform' and institution_id is null) or
       (scope_kind='institution' and institution_id is not null))
);
create unique index activity_templates_scope_code_uidx on public.activity_templates(
 scope_kind,coalesce(institution_id,'00000000-0000-0000-0000-000000000000'::uuid),code
);
create index activity_templates_taxonomy_status_idx on public.activity_templates(taxonomy_id,status,name);

create table public.activity_assignment_capability_actions(
 id uuid primary key default gen_random_uuid(),
 assignment_id uuid not null references public.activity_group_assignments(id) on delete cascade,
 capability_id uuid not null references public.activity_capabilities(id) on delete restrict,
 can_view boolean not null default true,
 can_edit boolean not null default true,
 changed_by_person_id uuid not null references public.people(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(assignment_id,capability_id)
);
create index activity_assignment_actions_capability_idx
 on public.activity_assignment_capability_actions(capability_id);

create table app_private.activity_management_command_receipts(
 request_id uuid primary key,
 command_kind text not null check(command_kind in (
  'upsert','locations','duplicate','export','import','identity_prepare','identity_finalize'
 )),
 request_hash bytea not null,
 actor_person_id uuid not null references public.people(id) on delete restrict,
 activity_id uuid references public.activity_definitions(id) on delete cascade,
 result_json jsonb not null,
 created_at timestamptz not null default now()
);
revoke all on app_private.activity_management_command_receipts from public,anon,authenticated;

alter table public.activity_definitions
 add column handle_stem text,
 add column canonical_handle text,
 add column management_version bigint not null default 1,
 add column taxonomy_id uuid references public.activity_taxonomies(id) on delete restrict,
 add column taxonomy_other_description text,
 add column template_id uuid references public.activity_templates(id) on delete set null,
 add column identity_mode text not null default 'initials',
 add column identity_storage_bucket text,
 add column identity_storage_path text,
 add column identity_initials text,
 add column identity_color text,
 add column identity_icon text;

create or replace function app_private.activity_slugify(value text)
returns text language sql immutable set search_path=''
as $$
 select trim(both '-' from regexp_replace(lower(coalesce(value,'')),'[^a-z0-9]+','-','g'))
$$;
revoke all on function app_private.activity_slugify(text) from public,anon,authenticated;

update public.activity_definitions
set handle_stem=coalesce(nullif(left(app_private.activity_slugify(name),48),''),
                         'atividade-'||left(id::text,8))||'-'||left(id::text,6),
 identity_initials=upper(left(regexp_replace(name,'[^[:alnum:]]','','g'),2)),
 identity_color='#D63C00';

create or replace function app_private.set_activity_canonical_handle()
returns trigger language plpgsql security definer set search_path=''
as $$
declare source_slug text; institution_slug text;
begin
 new.handle_stem:=lower(btrim(new.handle_stem));
 if new.handle_stem !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    or length(new.handle_stem) not between 3 and 64 then
  raise invalid_parameter_value using message='invalid activity handle stem';
 end if;
 select institution.slug into institution_slug from public.institutions institution
  where institution.id=new.institution_id;
 if institution_slug is null then raise foreign_key_violation using message='institution not found'; end if;
 if new.origin_scope_kind='unit' then
  select unit.slug into source_slug from public.units unit
   where unit.id=new.origin_unit_id and unit.institution_id=new.institution_id;
  if source_slug is null then raise foreign_key_violation using message='unit outside institution'; end if;
  source_slug:=source_slug||'.'||institution_slug;
 else source_slug:=institution_slug;
 end if;
 new.canonical_handle:=new.handle_stem||'.'||lower(source_slug);
 if exists(select 1 from public.activity_handle_aliases alias_record
   where lower(alias_record.alias)=lower(new.canonical_handle)
     and alias_record.activity_id<>new.id) then
  raise unique_violation using message='activity handle reserved by alias';
 end if;
 return new;
end $$;
revoke all on function app_private.set_activity_canonical_handle() from public,anon,authenticated;

create trigger activity_canonical_handle_before
before insert or update of handle_stem,institution_id,origin_scope_kind,origin_unit_id
on public.activity_definitions for each row execute function app_private.set_activity_canonical_handle();

update public.activity_definitions set handle_stem=handle_stem;

alter table public.activity_definitions
 alter column handle_stem set not null,
 alter column canonical_handle set not null,
 add constraint activity_definitions_management_version_check check(management_version>0),
 add constraint activity_definitions_handle_check check(
   handle_stem=lower(handle_stem) and handle_stem ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
 ),
 add constraint activity_definitions_canonical_handle_check check(
   canonical_handle=lower(canonical_handle)
   and canonical_handle ~ '^[a-z0-9-]+(?:\.[a-z0-9-]+)+$'
 ),
 add constraint activity_definitions_taxonomy_other_check check(
   taxonomy_other_description is null or
   (btrim(taxonomy_other_description)<>'' and length(taxonomy_other_description)<=500)
 ),
 add constraint activity_definitions_identity_mode_check check(identity_mode in ('photo','initials','icon')),
 add constraint activity_definitions_identity_storage_check check(
   (identity_storage_bucket is null and identity_storage_path is null)
   or (identity_storage_bucket='coelo-identities'
       and identity_storage_path like 'activities/'||id::text||'/%')
 ),
 add constraint activity_definitions_identity_initials_check check(
   identity_initials is null or length(btrim(identity_initials)) between 1 and 2
 ),
 add constraint activity_definitions_identity_color_check check(
   identity_color is null or identity_color ~ '^#[0-9A-Fa-f]{6}$'
 ),
 add constraint activity_definitions_identity_icon_check check(
   identity_icon is null or identity_icon in (
    'pool','sports_soccer','music_note','palette','menu_book','science',
    'school','fitness_center','eco','restaurant','psychology','sports_martial_arts'
   )
 );
create unique index activity_definitions_canonical_handle_uidx
 on public.activity_definitions(lower(canonical_handle));
create index activity_definitions_taxonomy_status_idx
 on public.activity_definitions(taxonomy_id,status,created_at desc);

create or replace function app_private.capture_activity_handle_alias()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 if old.canonical_handle is distinct from new.canonical_handle then
  insert into public.activity_handle_aliases(activity_id,alias)
  values(new.id,old.canonical_handle) on conflict do nothing;
 end if;
 return new;
end $$;
revoke all on function app_private.capture_activity_handle_alias() from public,anon,authenticated;
create trigger activity_canonical_handle_alias_after
after update of canonical_handle on public.activity_definitions
for each row execute function app_private.capture_activity_handle_alias();

create or replace function app_private.refresh_institution_activity_handles()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 if old.slug is distinct from new.slug then
  update public.activity_definitions set handle_stem=handle_stem,updated_at=now()
   where institution_id=new.id and origin_scope_kind='institution';
 end if;
 return new;
end $$;
create or replace function app_private.refresh_unit_activity_handles()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 if old.slug is distinct from new.slug then
  update public.activity_definitions set handle_stem=handle_stem,updated_at=now()
   where origin_unit_id=new.id and institution_id=new.institution_id;
 end if;
 return new;
end $$;
revoke all on function app_private.refresh_institution_activity_handles() from public,anon,authenticated;
revoke all on function app_private.refresh_unit_activity_handles() from public,anon,authenticated;
create trigger institution_activity_handles_after after update of slug on public.institutions
 for each row execute function app_private.refresh_institution_activity_handles();
create trigger unit_activity_handles_after after update of slug on public.units
 for each row execute function app_private.refresh_unit_activity_handles();

insert into public.activity_taxonomies(code,taxonomy_kind,name,sort_order) values
 ('artes-cultura','category','Artes e cultura',10),
 ('esportes-movimento','category','Esportes e movimento',20),
 ('idiomas-comunicacao','category','Idiomas e comunicação',30),
 ('ciencias-tecnologia','category','Ciências e tecnologia',40),
 ('apoio-pedagogico','category','Apoio pedagógico',50),
 ('saude-bem-estar','category','Saúde e bem-estar',60),
 ('natureza-sustentabilidade','category','Natureza e sustentabilidade',70),
 ('culinaria-vida-pratica','category','Culinária e vida prática',80),
 ('convivencia-socioemocional','category','Convivência e socioemocional',90),
 ('outros','category','Outros',100)
on conflict(code) do update set name=excluded.name,sort_order=excluded.sort_order,status='active',updated_at=now();

insert into public.activity_taxonomies(parent_id,code,taxonomy_kind,name,sort_order)
select category.id,seed.code,'subtype',seed.name,seed.position
from (values
 ('artes-cultura','musica','Música',10),('artes-cultura','teatro','Teatro',20),
 ('artes-cultura','danca-bale','Dança e balé',30),('artes-cultura','artes-visuais','Artes visuais',40),
 ('esportes-movimento','capoeira','Capoeira',10),('esportes-movimento','futsal','Futsal',20),
 ('esportes-movimento','natacao','Natação',30),('esportes-movimento','judo','Judô',40),
 ('idiomas-comunicacao','ingles','Inglês',10),('idiomas-comunicacao','espanhol','Espanhol',20),
 ('ciencias-tecnologia','robotica','Robótica',10),('ciencias-tecnologia','programacao','Programação',20),
 ('ciencias-tecnologia','ciencias-experimentais','Ciências experimentais',30),
 ('apoio-pedagogico','reforco-matematica','Reforço de matemática',10),
 ('apoio-pedagogico','leitura-producao-textual','Leitura e produção textual',20),
 ('saude-bem-estar','psicomotricidade','Psicomotricidade',10),
 ('saude-bem-estar','yoga-relaxamento','Yoga e relaxamento',20),
 ('natureza-sustentabilidade','horta-educacao-ambiental','Horta e educação ambiental',10),
 ('culinaria-vida-pratica','culinaria','Culinária',10),
 ('convivencia-socioemocional','xadrez','Xadrez',10),
 ('convivencia-socioemocional','oficina-socioemocional','Oficina socioemocional',20)
) seed(category_code,code,name,position)
join public.activity_taxonomies category on category.code=seed.category_code
on conflict(code) do update set parent_id=excluded.parent_id,name=excluded.name,
 sort_order=excluded.sort_order,status='active',updated_at=now();

insert into public.activity_templates(
 scope_kind,code,name,description,taxonomy_id,governance_kind,template_payload
)
select 'platform',taxonomy.code,taxonomy.name,
 'Modelo inicial editável de '||lower(taxonomy.name)||'.',taxonomy.id,'optional',
 jsonb_build_object('taxonomy_code',taxonomy.code,'governance_kind','optional')
from public.activity_taxonomies taxonomy where taxonomy.taxonomy_kind='subtype'
on conflict do nothing;

insert into public.activity_capabilities(code,name,description) values
 ('chat','Chat','Ver ou editar chat da atividade por turma.'),
 ('now','Now','Ver ou editar Now da atividade por turma.'),
 ('happens','Happens','Ver ou editar Happens da atividade por turma.'),
 ('moments','Moments','Ver ou editar Moments da atividade por turma.')
on conflict do nothing;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('coelo-identities','coelo-identities',false,2097152,
 array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,
 allowed_mime_types=excluded.allowed_mime_types;

create or replace function app_private.storage_activity_id(object_name text)
returns uuid language plpgsql immutable set search_path=''
as $$
begin
 if object_name !~ '^activities/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$' then return null; end if;
 return split_part(object_name,'/',2)::uuid;
exception when others then return null;
end $$;
revoke all on function app_private.storage_activity_id(text) from public,anon,authenticated;

drop policy if exists activity_identity_select on storage.objects;
create policy activity_identity_select on storage.objects for select to authenticated
using(bucket_id='coelo-identities' and exists(
 select 1 from public.activity_definitions activity
 where activity.id=app_private.storage_activity_id(name)
 and ((select app_private.has_platform_permission('activities.read'))
   or app_private.has_activity_context_access(activity.id,null,null))
));
drop policy if exists activity_identity_insert on storage.objects;
create policy activity_identity_insert on storage.objects for insert to authenticated
with check(bucket_id='coelo-identities' and exists(
 select 1 from public.activity_definitions activity
 where activity.id=app_private.storage_activity_id(name)
 and (select app_private.has_platform_permission('activities.manage'))
));
drop policy if exists activity_identity_update on storage.objects;
create policy activity_identity_update on storage.objects for update to authenticated
using(bucket_id='coelo-identities' and exists(
 select 1 from public.activity_definitions activity
 where activity.id=app_private.storage_activity_id(name)
 and (select app_private.has_platform_permission('activities.manage'))
))
with check(bucket_id='coelo-identities' and exists(
 select 1 from public.activity_definitions activity
 where activity.id=app_private.storage_activity_id(name)
 and (select app_private.has_platform_permission('activities.manage'))
));
drop policy if exists activity_identity_delete on storage.objects;
create policy activity_identity_delete on storage.objects for delete to authenticated
using(bucket_id='coelo-identities' and exists(
 select 1 from public.activity_definitions activity
 where activity.id=app_private.storage_activity_id(name)
 and (select app_private.has_platform_permission('activities.manage'))
));

do $$
declare table_name text;
begin
 foreach table_name in array array[
  'activity_taxonomies','activity_taxonomy_requests','activity_handle_aliases',
  'activity_locations','activity_templates','activity_assignment_capability_actions'
 ] loop
  execute format('alter table public.%I enable row level security',table_name);
  execute format('alter table public.%I force row level security',table_name);
  execute format('revoke all on table public.%I from public,anon,authenticated',table_name);
  execute format('grant select on table public.%I to authenticated',table_name);
  execute format('grant all on table public.%I to service_role',table_name);
 end loop;
end $$;
revoke insert,update,delete on public.activity_definitions from anon,authenticated;
revoke insert,update,delete on public.activity_unit_links from anon,authenticated;
revoke insert,update,delete on public.activity_group_links from anon,authenticated;
revoke insert,update,delete on public.activity_group_assignments from anon,authenticated;
revoke insert,update,delete on public.activity_group_participants from anon,authenticated;
revoke insert,update,delete on public.activity_assignment_permission_overrides from anon,authenticated;

create policy activity_taxonomies_authorized_read on public.activity_taxonomies for select to authenticated
using((select app_private.has_platform_permission('activities.read'))
 or exists(select 1 from public.institution_memberships membership
   where membership.person_id=app_private.current_person_id()
    and membership.status='active' and membership.revoked_at is null));
create policy activity_taxonomy_requests_authorized_read on public.activity_taxonomy_requests for select to authenticated
using((select app_private.has_platform_permission('activities.taxonomy.manage'))
 or app_private.has_institution_permission(institution_id,'activities.manage',null,null,true));
create policy activity_handle_aliases_authorized_read on public.activity_handle_aliases for select to authenticated
using(exists(select 1 from public.activity_definitions activity where activity.id=activity_id));
create policy activity_locations_authorized_read on public.activity_locations for select to authenticated
using((select app_private.has_platform_permission('activities.read'))
 or app_private.has_institution_permission(institution_id,'activities.read',unit_id,null,false));
create policy activity_templates_authorized_read on public.activity_templates for select to authenticated
using((select app_private.has_platform_permission('activities.read'))
 or (institution_id is not null and
   app_private.has_institution_permission(institution_id,'activities.read',null,null,true)));
create policy activity_assignment_actions_authorized_read
on public.activity_assignment_capability_actions for select to authenticated
using(exists(select 1 from public.activity_group_assignments assignment
 join public.activity_group_links group_link on group_link.id=assignment.activity_group_link_id
 where assignment.id=assignment_id and (
   assignment.person_id=app_private.current_person_id()
   or (select app_private.has_platform_permission('activities.read'))
   or app_private.has_institution_permission(
    assignment.institution_id,'activities.read',group_link.unit_id,group_link.group_id,false)
 )));

drop policy if exists activity_definitions_context_read on public.activity_definitions;
create policy activity_definitions_context_read on public.activity_definitions for select to authenticated
using((select app_private.has_platform_permission('activities.read'))
 or app_private.has_activity_context_access(id,null,null)
 or exists(select 1 from public.activity_unit_links unit_link
   where unit_link.activity_id=activity_definitions.id and unit_link.status='active'
    and app_private.has_institution_permission(
     activity_definitions.institution_id,'activities.read',unit_link.unit_id,null,false)));

drop policy if exists activity_unit_links_context_read on public.activity_unit_links;
create policy activity_unit_links_context_read on public.activity_unit_links for select to authenticated
using((select app_private.has_platform_permission('activities.read'))
 or app_private.has_activity_context_access(activity_id,unit_id,null)
 or app_private.has_institution_permission(institution_id,'activities.read',unit_id,null,false));

drop policy if exists activity_group_links_context_read on public.activity_group_links;
create policy activity_group_links_context_read on public.activity_group_links for select to authenticated
using((select app_private.has_platform_permission('activities.read'))
 or app_private.has_activity_context_access(activity_id,unit_id,group_id)
 or app_private.has_institution_permission(
  institution_id,'activities.read',unit_id,group_id,false));

drop policy if exists activity_group_assignments_context_read on public.activity_group_assignments;
create policy activity_group_assignments_context_read on public.activity_group_assignments for select to authenticated
using((select app_private.has_platform_permission('activities.read'))
 or person_id=app_private.current_person_id()
 or exists(select 1 from public.activity_group_links group_link
  where group_link.id=activity_group_assignments.activity_group_link_id
   and app_private.has_institution_permission(
    activity_group_assignments.institution_id,'activities.read',
    group_link.unit_id,group_link.group_id,false)));

drop policy if exists activity_permission_profiles_context_read on public.activity_permission_profiles;
create policy activity_permission_profiles_context_read on public.activity_permission_profiles for select to authenticated
using((select app_private.has_platform_permission('activities.read'))
 or app_private.has_institution_permission(
  institution_id,'activities.read',unit_id,null,scope_kind='institution')
 or exists(select 1 from public.activity_group_links group_link
   where group_link.permission_profile_id=activity_permission_profiles.id
    and app_private.has_activity_context_access(
     group_link.activity_id,group_link.unit_id,group_link.group_id)));

drop policy if exists activity_suggestions_context_read on public.activity_suggestions;
create policy activity_suggestions_context_read on public.activity_suggestions for select to authenticated
using((select app_private.has_platform_permission('activities.read'))
 or app_private.has_institution_permission(
  institution_id,'activities.read',unit_id,null,scope_kind='institution'));

commit;
