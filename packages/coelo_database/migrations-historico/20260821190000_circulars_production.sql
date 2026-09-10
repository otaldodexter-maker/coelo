-- Private, versioned institutional Circulars. Media lives in private Supabase Storage.
create type public.circular_status as enum ('draft','scheduled','published','closed','archived');
create type public.circular_revision_status as enum ('working','published','superseded');
create type public.circular_block_kind as enum ('text','media','question');
create type public.circular_question_kind as enum ('single_choice','multiple_choice');
create type public.circular_response_policy as enum ('per_person','per_child_any_guardian','per_child_each_guardian','per_staff_member');
create type public.circular_response_status as enum ('partial','submitted');
create type public.circular_audience_kind as enum ('families','students','school_staff','guardians_only');
create type public.circular_scope_kind as enum ('institution','unit','group','activity');
create type public.circular_media_status as enum ('pending','ready','orphaned','deleted');

create table public.circulars (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id),
  unit_id uuid references public.units(id),
  group_id uuid references public.groups(id),
  activity_id uuid references public.activity_definitions(id),
  author_person_id uuid not null references public.people(id),
  author_membership_id uuid not null references public.institution_memberships(id),
  status public.circular_status not null default 'draft',
  response_policy public.circular_response_policy not null default 'per_person',
  current_revision_id uuid,
  working_revision_id uuid,
  publish_at timestamptz,
  published_at timestamptz,
  revised_at timestamptz,
  responses_close_at timestamptz,
  responses_closed_at timestamptz,
  responses_closed_by uuid references public.people(id),
  management_version bigint not null default 1 check (management_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (unit_id is not null or group_id is null),
  check (status = 'draft' or publish_at is not null)
);

create table public.circular_revisions (
  id uuid primary key default gen_random_uuid(),
  circular_id uuid not null references public.circulars(id) on delete cascade,
  institution_id uuid not null references public.institutions(id),
  revision_number integer not null check (revision_number > 0),
  status public.circular_revision_status not null default 'working',
  title text not null,
  body_text text not null default '',
  created_by_person_id uuid not null references public.people(id),
  created_at timestamptz not null default now(),
  published_at timestamptz,
  constraint circular_revisions_title_length_check check (char_length(btrim(title)) between 1 and 120),
  constraint circular_revisions_body_length_check check (char_length(body_text) <= 10000),
  unique (circular_id, revision_number),
  unique (id, circular_id)
);
alter table public.circulars
  add constraint circulars_current_revision_fk foreign key (current_revision_id, id)
    references public.circular_revisions(id, circular_id) deferrable initially deferred,
  add constraint circulars_working_revision_fk foreign key (working_revision_id, id)
    references public.circular_revisions(id, circular_id) deferrable initially deferred;

create table public.circular_blocks (
  id uuid primary key,
  revision_id uuid not null references public.circular_revisions(id) on delete cascade,
  block_kind public.circular_block_kind not null,
  display_order smallint not null check (display_order between 0 and 63),
  text_content text,
  created_at timestamptz not null default now(),
  check ((block_kind = 'text' and text_content is not null) or (block_kind <> 'text' and text_content is null)),
  unique (revision_id, display_order),
  unique (id, revision_id)
);

create table public.circular_questions (
  id uuid primary key,
  revision_id uuid not null references public.circular_revisions(id) on delete cascade,
  block_id uuid not null unique,
  question_kind public.circular_question_kind not null,
  prompt text not null check (char_length(btrim(prompt)) between 1 and 240),
  required boolean not null default false,
  foreign key (block_id, revision_id) references public.circular_blocks(id, revision_id) on delete cascade,
  unique (id, revision_id)
);

create table public.circular_question_options (
  id uuid primary key,
  question_id uuid not null references public.circular_questions(id) on delete cascade,
  label text not null check (char_length(btrim(label)) between 1 and 120),
  display_order smallint not null check (display_order between 0 and 9),
  unique (question_id, display_order),
  unique (id, question_id)
);

create table public.circular_audience_rules (
  id uuid primary key default gen_random_uuid(),
  circular_id uuid not null references public.circulars(id) on delete cascade,
  institution_id uuid not null references public.institutions(id),
  audience_kind public.circular_audience_kind not null,
  scope_kind public.circular_scope_kind not null,
  unit_id uuid references public.units(id),
  group_id uuid references public.groups(id),
  activity_id uuid references public.activity_definitions(id),
  check (
    (scope_kind = 'institution' and unit_id is null and group_id is null and activity_id is null) or
    (scope_kind = 'unit' and unit_id is not null and group_id is null and activity_id is null) or
    (scope_kind = 'group' and unit_id is not null and group_id is not null and activity_id is null) or
    (scope_kind = 'activity' and unit_id is null and group_id is null and activity_id is not null)
  ),
  unique (circular_id, audience_kind, scope_kind, unit_id, group_id, activity_id)
);

create table public.circular_media_assets (
  id uuid primary key default gen_random_uuid(),
  circular_id uuid not null references public.circulars(id) on delete cascade,
  institution_id uuid not null references public.institutions(id),
  owner_person_id uuid not null references public.people(id),
  upload_request_id uuid not null,
  storage_provider text not null default 'supabase' check (storage_provider = 'supabase'),
  bucket_id text not null default 'coelo-circulars-private',
  object_key text not null unique,
  original_name text not null check (char_length(btrim(original_name)) between 1 and 240),
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp','video/mp4','application/pdf')),
  byte_size bigint not null check (
    (mime_type in ('image/jpeg','image/png','image/webp') and byte_size between 1 and 10485760) or
    (mime_type = 'video/mp4' and byte_size between 1 and 26214400) or
    (mime_type = 'application/pdf' and byte_size between 1 and 5242880)
  ),
  checksum_sha256 text,
  etag text,
  status public.circular_media_status not null default 'pending',
  finalize_ticket uuid,
  finalize_ticket_expires_at timestamptz,
  created_at timestamptz not null default now(),
  finalized_at timestamptz,
  cleanup_attempted_at timestamptz,
  unique (circular_id, upload_request_id)
);

create table public.circular_media_links (
  revision_id uuid not null references public.circular_revisions(id) on delete cascade,
  block_id uuid not null,
  media_asset_id uuid not null references public.circular_media_assets(id) on delete restrict,
  display_order smallint not null check (display_order between 0 and 3),
  foreign key (block_id, revision_id) references public.circular_blocks(id, revision_id) on delete cascade,
  primary key (revision_id, media_asset_id),
  unique (revision_id, display_order)
);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'coelo-circulars-private','coelo-circulars-private',false,26214400,
  array['image/jpeg','image/png','image/webp','video/mp4','application/pdf']
)
on conflict(id) do update set
  public=false,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

create table public.circular_response_sessions (
  id uuid primary key default gen_random_uuid(),
  circular_id uuid not null references public.circulars(id) on delete restrict,
  revision_id uuid not null references public.circular_revisions(id) on delete restrict,
  institution_id uuid not null references public.institutions(id),
  response_unit_key text not null check (char_length(response_unit_key) between 3 and 160),
  response_person_id uuid references public.people(id),
  child_context_id uuid references public.child_contexts(id),
  last_actor_person_id uuid not null references public.people(id),
  status public.circular_response_status not null default 'partial',
  response_version bigint not null default 1 check (response_version > 0),
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (revision_id, response_unit_key)
);

create table public.circular_response_revisions (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.circular_response_sessions(id) on delete cascade,
  response_version bigint not null,
  actor_person_id uuid not null references public.people(id),
  status public.circular_response_status not null,
  snapshot jsonb not null,
  created_at timestamptz not null default now(),
  unique (session_id, response_version)
);

create table public.circular_answers (
  session_id uuid not null references public.circular_response_sessions(id) on delete cascade,
  question_id uuid not null references public.circular_questions(id) on delete restrict,
  updated_at timestamptz not null default now(),
  primary key (session_id, question_id)
);

create table public.circular_answer_options (
  session_id uuid not null,
  question_id uuid not null,
  option_id uuid not null,
  foreign key (session_id, question_id) references public.circular_answers(session_id, question_id) on delete cascade,
  foreign key (option_id, question_id) references public.circular_question_options(id, question_id) on delete restrict,
  primary key (session_id, question_id, option_id)
);

create table app_private.circular_command_receipts (
  id uuid primary key default gen_random_uuid(),
  actor_person_id uuid not null,
  command_name text not null,
  request_id uuid not null,
  request_fingerprint text not null,
  response jsonb not null,
  created_at timestamptz not null default now(),
  unique (actor_person_id, command_name, request_id)
);

create table app_private.circular_audit (
  id bigint generated always as identity primary key,
  circular_id uuid not null,
  revision_id uuid,
  institution_id uuid not null,
  actor_person_id uuid not null,
  event_code text not null,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index circulars_feed_idx on public.circulars(institution_id, publish_at desc, id) where status in ('scheduled','published','closed') and deleted_at is null;
create index circulars_author_idx on public.circulars(author_person_id, updated_at desc) where deleted_at is null;
create index circular_revisions_circular_idx on public.circular_revisions(circular_id, revision_number desc);
create index circular_blocks_revision_idx on public.circular_blocks(revision_id, display_order);
create index circular_questions_revision_idx on public.circular_questions(revision_id);
create index circular_audience_scope_idx on public.circular_audience_rules(institution_id, unit_id, group_id, activity_id);
create index circular_media_owner_idx on public.circular_media_assets(institution_id, owner_person_id, status);
create index circular_response_revision_idx on public.circular_response_sessions(revision_id, status);
create index circular_response_child_idx on public.circular_response_sessions(child_context_id) where child_context_id is not null;
create index circular_audit_subject_idx on app_private.circular_audit(circular_id, created_at desc);

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'circulars','circular_revisions','circular_blocks','circular_questions',
    'circular_question_options','circular_audience_rules','circular_media_assets',
    'circular_media_links','circular_response_sessions','circular_response_revisions',
    'circular_answers','circular_answer_options'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
    execute format('revoke all on public.%I from anon, authenticated', table_name);
  end loop;
end $$;
revoke all on app_private.circular_command_receipts, app_private.circular_audit from public, anon, authenticated;

insert into public.institution_permissions(
  code,module_code,screen_code,action_code,description,status,module_label,screen_label,action_label
) values
 ('circulars.circulars.create','circulars','circulars','create','Criar e revisar rascunhos de Circulares.','active','Circulares','Circulares','Criar'),
 ('circulars.circulars.publish','circulars','circulars','publish','Publicar ou agendar Circulares.','active','Circulares','Circulares','Publicar'),
 ('circulars.circulars.read','circulars','circulars','read','Ler Circulares privadas autorizadas.','active','Circulares','Circulares','Ler'),
 ('circulars.circulars.respond','circulars','circulars','respond','Responder perguntas de Circulares.','active','Circulares','Circulares','Responder'),
 ('circulars.circulars.manage','circulars','circulars','manage','Revisar, encerrar e arquivar Circulares.','active','Circulares','Circulares','Gerenciar')
on conflict(code) do update set description=excluded.description,status='active',module_label=excluded.module_label,screen_label=excluded.screen_label,action_label=excluded.action_label;

create or replace function app_private.circular_actor(
  p_institution_id uuid,p_permission text,p_unit_id uuid,p_group_id uuid
) returns table(person_id uuid,membership_id uuid,role_code text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise insufficient_privilege using message='authentication_required'; end if;
  if not app_private.has_institution_permission(p_institution_id,p_permission,p_unit_id,p_group_id,false)
  then raise insufficient_privilege using message='circular_permission_denied'; end if;
  return query
  select link.person_id,membership.id,membership.role_code
  from public.person_auth_links link
  join public.institution_memberships membership on membership.person_id=link.person_id
  where link.auth_user_id=(select auth.uid()) and link.status='active'
    and membership.institution_id=p_institution_id and membership.status='active'
    and membership.revoked_at is null
  order by membership.created_at limit 1;
  if not found then raise insufficient_privilege using message='active_membership_required'; end if;
end $$;

create or replace function app_private.circular_audience_matches_role(p_role text,p_audience public.circular_audience_kind)
returns boolean language sql immutable set search_path='' as $$
  select case
    when lower(coalesce(p_role,'')) in ('guardian','responsible','responsavel','parent','family') then p_audience in ('families','guardians_only')
    when lower(coalesce(p_role,'')) in ('student','aluno') then p_audience='students'
    when lower(coalesce(p_role,'')) in ('professional','institution_admin','unit_admin','teacher','coordinator') then p_audience='school_staff'
    else false
  end
$$;

create or replace function app_private.circular_child_scope_matches(
  p_child_context_id uuid,p_audience public.circular_audience_rules
) returns boolean language sql stable security definer set search_path='' as $$
  select exists (
    select 1
    from public.child_contexts child
    where child.id=p_child_context_id
      and child.institution_id=p_audience.institution_id
      and child.status='active'
      and case p_audience.scope_kind
        when 'institution' then true
        when 'unit' then exists (
          select 1 from public.child_unit_links child_unit
          where child_unit.child_context_id=child.id
            and child_unit.unit_id=p_audience.unit_id
            and child_unit.status='active' and child_unit.revoked_at is null
        )
        when 'group' then exists (
          select 1 from public.child_unit_links child_unit
          join public.child_group_links child_group on child_group.child_unit_link_id=child_unit.id
          where child_unit.child_context_id=child.id
            and child_unit.unit_id=p_audience.unit_id
            and child_unit.status='active' and child_unit.revoked_at is null
            and child_group.group_id=p_audience.group_id and child_group.status='active'
            and (child_group.starts_at is null or child_group.starts_at<=now())
            and (child_group.ends_at is null or child_group.ends_at>now())
        )
        when 'activity' then exists (
          select 1
          from public.child_unit_links child_unit
          join public.child_group_links child_group on child_group.child_unit_link_id=child_unit.id
          join public.activity_group_links activity_group on activity_group.group_id=child_group.group_id
          where child_unit.child_context_id=child.id
            and child_unit.status='active' and child_unit.revoked_at is null
            and child_group.status='active'
            and (child_group.starts_at is null or child_group.starts_at<=now())
            and (child_group.ends_at is null or child_group.ends_at>now())
            and activity_group.activity_id=p_audience.activity_id
            and activity_group.institution_id=p_audience.institution_id
            and activity_group.status='active'
            and activity_group.starts_at<=now()
            and (activity_group.ends_at is null or activity_group.ends_at>now())
            and (
              activity_group.participation_mode='all'
              or exists (
                select 1 from public.activity_group_participants participant
                where participant.activity_group_link_id=activity_group.id
                  and participant.child_group_link_id=child_group.id
                  and participant.status='active' and participant.removed_at is null
              )
            )
        )
      end
  )
$$;

create or replace function app_private.circular_person_matches_scope(
  p_person_id uuid,p_role text,p_audience public.circular_audience_rules
) returns boolean language sql stable security definer set search_path='' as $$
  select case
    when lower(coalesce(p_role,'')) in ('guardian','responsible','responsavel','parent','family') then exists (
      select 1
      from public.guardian_links guardian
      join public.guardian_context_permissions permission on permission.guardian_link_id=guardian.id
      where guardian.guardian_person_id=p_person_id
        and guardian.status='active' and guardian.revoked_at is null
        and permission.status='active' and permission.can_view
        and (permission.starts_at is null or permission.starts_at<=now())
        and (permission.expires_at is null or permission.expires_at>now())
        and app_private.circular_child_scope_matches(permission.child_context_id,p_audience)
    )
    when lower(coalesce(p_role,'')) in ('student','aluno') then exists (
      select 1 from public.child_contexts child
      where child.child_person_id=p_person_id
        and app_private.circular_child_scope_matches(child.id,p_audience)
    )
    when lower(coalesce(p_role,'')) in ('professional','institution_admin','unit_admin','teacher','coordinator') then true
    else false
  end
$$;

create or replace function app_private.circular_audience_visible(
  p_circular public.circulars,p_person_id uuid,p_role text,p_unit_id uuid,p_group_id uuid,p_activity_id uuid
) returns boolean language sql stable security definer set search_path='' as $$
  select p_circular.deleted_at is null
    and p_circular.status in ('scheduled','published','closed')
    and exists (
      select 1 from public.circular_audience_rules audience
      where audience.circular_id=p_circular.id
        and app_private.circular_audience_matches_role(p_role,audience.audience_kind)
        and app_private.circular_person_matches_scope(p_person_id,p_role,audience)
        and case audience.scope_kind
          when 'institution' then true
          when 'unit' then audience.unit_id=p_unit_id
          when 'group' then audience.unit_id=p_unit_id and audience.group_id=p_group_id
          when 'activity' then audience.activity_id=p_activity_id
        end
    )
$$;

create or replace function app_private.circular_visible(
  p_circular public.circulars,p_person_id uuid,p_role text,p_unit_id uuid,p_group_id uuid,p_activity_id uuid
) returns boolean language sql stable security definer set search_path='' as $$
  select p_circular.publish_at<=now()
    and app_private.circular_audience_visible(p_circular,p_person_id,p_role,p_unit_id,p_group_id,p_activity_id)
$$;

create or replace function app_private.circular_validate_scope(
  p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_activity_id uuid
) returns void language plpgsql stable security definer set search_path='' as $$
begin
  if p_unit_id is not null and not exists(select 1 from public.units u where u.id=p_unit_id and u.institution_id=p_institution_id)
  then raise insufficient_privilege using message='unit_scope_invalid'; end if;
  if p_group_id is not null and not exists(select 1 from public.groups g where g.id=p_group_id and g.institution_id=p_institution_id and g.unit_id=p_unit_id)
  then raise insufficient_privilege using message='group_scope_invalid'; end if;
  if p_activity_id is not null and not exists(select 1 from public.activity_definitions a where a.id=p_activity_id and a.institution_id=p_institution_id)
  then raise insufficient_privilege using message='activity_scope_invalid'; end if;
end $$;

create or replace function public.load_circular_draft(
  p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_activity_id uuid
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor record; target public.circulars%rowtype; revision public.circular_revisions%rowtype;
begin
  perform app_private.circular_validate_scope(p_institution_id,p_unit_id,p_group_id,p_activity_id);
  select * into actor from app_private.circular_actor(p_institution_id,'circulars.circulars.create',p_unit_id,p_group_id);
  select * into target from public.circulars c
  where c.institution_id=p_institution_id and c.author_person_id=actor.person_id and c.deleted_at is null
    and c.working_revision_id is not null and c.unit_id is not distinct from p_unit_id
    and c.group_id is not distinct from p_group_id and c.activity_id is not distinct from p_activity_id
  order by c.updated_at desc limit 1;
  if target.id is null then return null; end if;
  select * into revision from public.circular_revisions r where r.id=target.working_revision_id;
  return jsonb_build_object(
    'id',target.id,'version',target.management_version,'revision_id',revision.id,'title',revision.title,
    'status',target.status,'response_policy',target.response_policy,'publish_at',target.publish_at,
    'responses_close_at',target.responses_close_at,
    'blocks',(select coalesce(jsonb_agg(
      case block.block_kind
        when 'text' then jsonb_build_object('id',block.id,'kind','text','text',block.text_content,'order',block.display_order)
        when 'media' then jsonb_build_object('id',block.id,'kind','media','order',block.display_order,'asset_ids',(
          select coalesce(jsonb_agg(link.media_asset_id order by link.display_order),'[]') from public.circular_media_links link where link.block_id=block.id))
        else jsonb_build_object('id',block.id,'kind','question','order',block.display_order,'question',(
          select jsonb_build_object('id',q.id,'prompt',q.prompt,'kind',q.question_kind,'required',q.required,'options',(
            select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'label',o.label,'order',o.display_order) order by o.display_order),'[]') from public.circular_question_options o where o.question_id=q.id))
          from public.circular_questions q where q.block_id=block.id))
      end order by block.display_order),'[]') from public.circular_blocks block where block.revision_id=revision.id),
    'audiences',(select coalesce(jsonb_agg(jsonb_build_object('kind',a.audience_kind,'scope',a.scope_kind,'unit_id',a.unit_id,'group_id',a.group_id,'activity_id',a.activity_id)),'[]') from public.circular_audience_rules a where a.circular_id=target.id)
  );
end $$;

create or replace function public.save_circular_draft(
  p_request_id uuid,p_draft jsonb,p_circular_id uuid,p_expected_version bigint
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  actor record; target public.circulars%rowtype; revision public.circular_revisions%rowtype;
  institution uuid:=(p_draft->>'institution_id')::uuid; unit uuid:=nullif(p_draft->>'unit_id','')::uuid;
  grp uuid:=nullif(p_draft->>'group_id','')::uuid; activity uuid:=nullif(p_draft->>'activity_id','')::uuid;
  block jsonb; question jsonb; option jsonb; audience jsonb; asset_id uuid;
  block_count int:=0; option_count int:=0; question_count int:=0; media_count int:=0; body text:=''; response jsonb; fingerprint text; prior_fingerprint text;
begin
  perform app_private.circular_validate_scope(institution,unit,grp,activity);
  select * into actor from app_private.circular_actor(institution,'circulars.circulars.create',unit,grp);
  fingerprint:=pg_catalog.encode(extensions.digest(pg_catalog.convert_to(coalesce(p_draft,'{}'::jsonb)::text,'UTF8'),'sha256'),'hex');
  select receipt.response,receipt.request_fingerprint into response,prior_fingerprint from app_private.circular_command_receipts receipt
  where receipt.actor_person_id=actor.person_id and receipt.command_name='save_draft' and receipt.request_id=p_request_id;
  if response is not null then
    if prior_fingerprint<>fingerprint then raise unique_violation using message='request_id_conflict'; end if;
    return response;
  end if;
  if char_length(btrim(coalesce(p_draft->>'title',''))) not between 1 and 120 then raise check_violation using message='circular_title_invalid'; end if;
  if jsonb_array_length(coalesce(p_draft->'blocks','[]'))>64 then raise check_violation using message='circular_blocks_invalid'; end if;
  for block in select value from jsonb_array_elements(coalesce(p_draft->'blocks','[]')) loop
    if block->>'kind'='text' then body:=body||coalesce(block->>'text',''); end if;
    if block->>'kind'='media' then media_count:=media_count+jsonb_array_length(coalesce(block->'asset_ids','[]')); end if;
    if block->>'kind'='question' then question_count:=question_count+1; end if;
  end loop;
  if char_length(body)>10000 then raise check_violation using message='circular_body_too_long'; end if;
  if media_count>4 then raise check_violation using message='circular_media_limit'; end if;
  if question_count>10 then raise check_violation using message='circular_question_limit'; end if;

  if p_circular_id is null then
    insert into public.circulars(institution_id,unit_id,group_id,activity_id,author_person_id,author_membership_id,response_policy,publish_at,responses_close_at)
    values(institution,unit,grp,activity,actor.person_id,actor.membership_id,(p_draft->>'response_policy')::public.circular_response_policy,nullif(p_draft->>'publish_at','')::timestamptz,nullif(p_draft->>'responses_close_at','')::timestamptz)
    returning * into target;
    insert into public.circular_revisions(circular_id,institution_id,revision_number,title,body_text,created_by_person_id)
    values(target.id,institution,1,btrim(p_draft->>'title'),body,actor.person_id) returning * into revision;
  else
    select * into target from public.circulars c where c.id=p_circular_id and c.institution_id=institution and c.deleted_at is null for update;
    if target.id is null or target.management_version<>p_expected_version then raise serialization_failure using message='expected_version_conflict'; end if;
    if target.author_person_id<>actor.person_id and not app_private.has_institution_permission(institution,'circulars.circulars.manage',unit,grp,false)
    then raise insufficient_privilege using message='circular_manage_denied'; end if;
    if target.working_revision_id is null then
      insert into public.circular_revisions(circular_id,institution_id,revision_number,title,body_text,created_by_person_id)
      values(target.id,institution,(select coalesce(max(r.revision_number),0)+1 from public.circular_revisions r where r.circular_id=target.id),btrim(p_draft->>'title'),body,actor.person_id)
      returning * into revision;
    else
      select * into revision from public.circular_revisions r where r.id=target.working_revision_id and r.status='working';
      if revision.id is null then raise check_violation using message='published_revision_immutable'; end if;
      update public.circular_revisions set title=btrim(p_draft->>'title'),body_text=body where id=revision.id;
      delete from public.circular_blocks where revision_id=revision.id;
    end if;
    update public.circulars set response_policy=(p_draft->>'response_policy')::public.circular_response_policy,
      publish_at=nullif(p_draft->>'publish_at','')::timestamptz,responses_close_at=nullif(p_draft->>'responses_close_at','')::timestamptz,
      management_version=management_version+1,updated_at=now() where id=target.id returning * into target;
    delete from public.circular_audience_rules where circular_id=target.id;
  end if;
  update public.circulars set working_revision_id=revision.id where id=target.id;

  for block in select value from jsonb_array_elements(coalesce(p_draft->'blocks','[]')) loop
    block_count:=block_count+1;
    if block->>'kind' not in ('text','media','question') then raise check_violation using message='circular_block_kind_invalid'; end if;
    insert into public.circular_blocks(id,revision_id,block_kind,display_order,text_content)
    values((block->>'id')::uuid,revision.id,(block->>'kind')::public.circular_block_kind,block_count-1,case when block->>'kind'='text' then coalesce(block->>'text','') end);
    if block->>'kind'='media' then
      for asset_id in select value::uuid from jsonb_array_elements_text(coalesce(block->'asset_ids','[]')) loop
        insert into public.circular_media_links(revision_id,block_id,media_asset_id,display_order)
        select revision.id,(block->>'id')::uuid,asset.id,(select count(*)::smallint from public.circular_media_links link where link.revision_id=revision.id)
        from public.circular_media_assets asset
        where asset.id=asset_id and asset.circular_id=target.id and asset.owner_person_id=actor.person_id and asset.status<>'deleted';
        if not found then raise insufficient_privilege using message='media_asset_scope_invalid'; end if;
      end loop;
    elsif block->>'kind'='question' then
      question:=block->'question';
      if char_length(btrim(coalesce(question->>'prompt',''))) not between 1 and 240 then raise check_violation using message='circular_question_invalid'; end if;
      if jsonb_array_length(coalesce(question->'options','[]')) not between 2 and 10 then raise check_violation using message='circular_option_count_invalid'; end if;
      insert into public.circular_questions(id,revision_id,block_id,question_kind,prompt,required)
      values((question->>'id')::uuid,revision.id,(block->>'id')::uuid,(question->>'kind')::public.circular_question_kind,btrim(question->>'prompt'),coalesce((question->>'required')::boolean,false));
      option_count:=0;
      for option in select value from jsonb_array_elements(question->'options') loop
        option_count:=option_count+1;
        insert into public.circular_question_options(id,question_id,label,display_order)
        values((option->>'id')::uuid,(question->>'id')::uuid,btrim(option->>'label'),option_count-1);
      end loop;
    end if;
  end loop;
  for audience in select value from jsonb_array_elements(coalesce(p_draft->'audiences','[]')) loop
    perform app_private.circular_validate_scope(
      institution,
      nullif(audience->>'unit_id','')::uuid,
      nullif(audience->>'group_id','')::uuid,
      nullif(audience->>'activity_id','')::uuid
    );
    insert into public.circular_audience_rules(circular_id,institution_id,audience_kind,scope_kind,unit_id,group_id,activity_id)
    values(target.id,institution,(audience->>'kind')::public.circular_audience_kind,(audience->>'scope')::public.circular_scope_kind,
      nullif(audience->>'unit_id','')::uuid,nullif(audience->>'group_id','')::uuid,nullif(audience->>'activity_id','')::uuid);
  end loop;
  response:=jsonb_build_object('id',target.id,'revision_id',revision.id,'version',target.management_version,'status',target.status);
  insert into app_private.circular_command_receipts(actor_person_id,command_name,request_id,request_fingerprint,response)
  values(actor.person_id,'save_draft',p_request_id,fingerprint,response);
  insert into app_private.circular_audit(circular_id,revision_id,institution_id,actor_person_id,event_code,detail)
  values(target.id,revision.id,institution,actor.person_id,'draft_saved',jsonb_build_object('version',target.management_version));
  return response;
end $$;

create or replace function public.prepare_circular_media_upload(
  p_request_id uuid,p_institution_id uuid,p_circular_id uuid,p_name text,p_mime_type text,p_byte_size bigint
) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor record; target public.circulars%rowtype; asset public.circular_media_assets%rowtype; max_bytes bigint;
begin
  select * into target from public.circulars c where c.id=p_circular_id and c.institution_id=p_institution_id and c.working_revision_id is not null and c.deleted_at is null;
  if target.id is null then raise insufficient_privilege using message='circular_not_authorized'; end if;
  select * into actor from app_private.circular_actor(p_institution_id,'circulars.circulars.create',target.unit_id,target.group_id);
  if target.author_person_id<>actor.person_id then raise insufficient_privilege using message='circular_not_authorized'; end if;
  max_bytes:=case when p_mime_type in ('image/jpeg','image/png','image/webp') then 10485760 when p_mime_type='video/mp4' then 26214400 when p_mime_type='application/pdf' then 5242880 end;
  if max_bytes is null or p_byte_size not between 1 and max_bytes then raise check_violation using message='circular_media_invalid'; end if;
  select * into asset from public.circular_media_assets m where m.circular_id=target.id and m.upload_request_id=p_request_id;
  if asset.id is null then
    if (select count(*) from public.circular_media_assets m where m.circular_id=target.id and m.status<>'deleted')>=4 then raise check_violation using message='circular_media_limit'; end if;
    insert into public.circular_media_assets(circular_id,institution_id,owner_person_id,upload_request_id,object_key,original_name,mime_type,byte_size)
    values(target.id,p_institution_id,actor.person_id,p_request_id,p_institution_id::text||'/circulars/'||target.id::text||'/'||gen_random_uuid()::text,p_name,p_mime_type,p_byte_size)
    returning * into asset;
  elsif asset.owner_person_id<>actor.person_id or asset.mime_type<>p_mime_type or asset.byte_size<>p_byte_size then
    raise insufficient_privilege using message='upload_request_conflict';
  end if;
  return jsonb_build_object('asset_id',asset.id,'bucket_id',asset.bucket_id,'object_key',asset.object_key,'expected_mime_type',asset.mime_type,'expected_byte_size',asset.byte_size,'status',asset.status);
end $$;

create or replace function public.authorize_circular_media_finalize(p_asset_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare asset public.circular_media_assets%rowtype; target public.circulars%rowtype; actor record; ticket uuid:=gen_random_uuid();
begin
  select * into asset from public.circular_media_assets m where m.id=p_asset_id and m.status in ('pending','ready') for update;
  select * into target from public.circulars c where c.id=asset.circular_id and c.working_revision_id is not null;
  select * into actor from app_private.circular_actor(asset.institution_id,'circulars.circulars.create',target.unit_id,target.group_id);
  if asset.id is null or asset.owner_person_id<>actor.person_id or target.author_person_id<>actor.person_id then raise insufficient_privilege using message='media_finalize_denied'; end if;
  if asset.status='ready' then return jsonb_build_object('already_finalized',true); end if;
  update public.circular_media_assets set finalize_ticket=ticket,finalize_ticket_expires_at=now()+interval '2 minutes' where id=asset.id;
  return jsonb_build_object('finalize_ticket',ticket);
end $$;

create or replace function public.finalize_circular_media_upload(
  p_asset_id uuid,p_finalize_ticket uuid,p_expected_byte_size bigint,p_expected_mime_type text,p_checksum_sha256 text,p_etag text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare asset public.circular_media_assets%rowtype;
begin
  select * into asset from public.circular_media_assets m where m.id=p_asset_id for update;
  if asset.status='ready' and asset.byte_size=p_expected_byte_size and asset.mime_type=p_expected_mime_type then
    return jsonb_build_object('asset_id',asset.id,'bucket_id',asset.bucket_id,'object_key',asset.object_key,'status',asset.status);
  end if;
  if asset.id is null or asset.status<>'pending' or asset.finalize_ticket<>p_finalize_ticket or asset.finalize_ticket_expires_at<=now()
    or asset.byte_size<>p_expected_byte_size or asset.mime_type<>p_expected_mime_type
  then raise insufficient_privilege using message='media_finalize_denied'; end if;
  update public.circular_media_assets set status='ready',checksum_sha256=p_checksum_sha256,etag=p_etag,finalized_at=now(),finalize_ticket=null,finalize_ticket_expires_at=null where id=asset.id returning * into asset;
  return jsonb_build_object('asset_id',asset.id,'bucket_id',asset.bucket_id,'object_key',asset.object_key,'status',asset.status);
end $$;

create or replace function public.remove_circular_media(p_asset_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare asset public.circular_media_assets%rowtype; target public.circulars%rowtype; actor record;
begin
  select * into asset from public.circular_media_assets m where m.id=p_asset_id for update;
  select * into target from public.circulars c where c.id=asset.circular_id;
  select * into actor from app_private.circular_actor(asset.institution_id,'circulars.circulars.create',target.unit_id,target.group_id);
  if asset.id is null or asset.owner_person_id<>actor.person_id or target.working_revision_id is null then raise insufficient_privilege using message='media_remove_denied'; end if;
  if exists(select 1 from public.circular_media_links l join public.circular_revisions r on r.id=l.revision_id where l.media_asset_id=asset.id and r.status<>'working')
  then raise check_violation using message='published_media_immutable'; end if;
  delete from public.circular_media_links l using public.circular_revisions r where l.media_asset_id=asset.id and r.id=l.revision_id and r.status='working';
  update public.circular_media_assets set status='orphaned' where id=asset.id;
  return jsonb_build_object('asset_id',asset.id,'bucket_id',asset.bucket_id,'object_key',asset.object_key);
end $$;

create or replace function public.publish_circular(
  p_request_id uuid,p_circular_id uuid,p_expected_version bigint,p_publish_at timestamptz
) returns jsonb language plpgsql security definer set search_path='' as $$
declare target public.circulars%rowtype; revision public.circular_revisions%rowtype; actor record; at timestamptz:=coalesce(p_publish_at,now()); next_status public.circular_status; response jsonb; fingerprint text; prior_fingerprint text;
begin
  select * into target from public.circulars c where c.id=p_circular_id and c.deleted_at is null for update;
  select * into actor from app_private.circular_actor(target.institution_id,'circulars.circulars.publish',target.unit_id,target.group_id);
  fingerprint:=pg_catalog.encode(extensions.digest(pg_catalog.convert_to(p_circular_id::text||p_expected_version::text||coalesce(p_publish_at::text,'immediate'),'UTF8'),'sha256'),'hex');
  select receipt.response,receipt.request_fingerprint into response,prior_fingerprint from app_private.circular_command_receipts receipt where receipt.actor_person_id=actor.person_id and receipt.command_name='publish' and receipt.request_id=p_request_id;
  if response is not null then
    if prior_fingerprint<>fingerprint then raise unique_violation using message='request_id_conflict'; end if;
    return response;
  end if;
  if target.management_version<>p_expected_version or target.working_revision_id is null then raise serialization_failure using message='expected_version_conflict'; end if;
  select * into revision from public.circular_revisions r where r.id=target.working_revision_id and r.status='working';
  if revision.id is null or not exists(select 1 from public.circular_audience_rules a where a.circular_id=target.id) then raise check_violation using message='circular_incomplete'; end if;
  if exists(select 1 from public.circular_questions q where q.revision_id=revision.id and (select count(*) from public.circular_question_options o where o.question_id=q.id) not between 2 and 10)
  then raise check_violation using message='circular_question_invalid'; end if;
  if exists(select 1 from public.circular_media_links l join public.circular_media_assets m on m.id=l.media_asset_id where l.revision_id=revision.id and m.status<>'ready')
  then raise check_violation using message='circular_media_not_ready'; end if;
  update public.circular_revisions set status='superseded' where circular_id=target.id and status='published';
  update public.circular_revisions set status='published',published_at=now() where id=revision.id;
  next_status:=case when at>now() then 'scheduled'::public.circular_status else 'published'::public.circular_status end;
  update public.circulars set status=next_status,current_revision_id=revision.id,working_revision_id=null,publish_at=case when published_at is null then at else publish_at end,
    published_at=coalesce(published_at,case when at<=now() then now() end),revised_at=case when published_at is not null then now() end,
    management_version=management_version+1,updated_at=now() where id=target.id returning * into target;
  response:=jsonb_build_object('id',target.id,'revision_id',revision.id,'version',target.management_version,'status',target.status,'publish_at',target.publish_at);
  insert into app_private.circular_command_receipts(actor_person_id,command_name,request_id,request_fingerprint,response)
  values(actor.person_id,'publish',p_request_id,fingerprint,response);
  insert into app_private.circular_audit(circular_id,revision_id,institution_id,actor_person_id,event_code,detail)
  values(target.id,revision.id,target.institution_id,actor.person_id,case when next_status='scheduled' then 'circular_scheduled' else 'circular_published' end,jsonb_build_object('publish_at',at));
  return response;
end $$;

create or replace function public.close_circular_responses(p_request_id uuid,p_circular_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target public.circulars%rowtype; actor record;
begin
  select * into target from public.circulars c where c.id=p_circular_id and c.deleted_at is null for update;
  select * into actor from app_private.circular_actor(target.institution_id,'circulars.circulars.manage',target.unit_id,target.group_id);
  if target.management_version<>p_expected_version or target.current_revision_id is null then raise serialization_failure using message='expected_version_conflict'; end if;
  update public.circulars set status='closed',responses_closed_at=now(),responses_closed_by=actor.person_id,management_version=management_version+1,updated_at=now() where id=target.id returning * into target;
  insert into app_private.circular_audit(circular_id,revision_id,institution_id,actor_person_id,event_code,detail) values(target.id,target.current_revision_id,target.institution_id,actor.person_id,'responses_closed',jsonb_build_object('request_id',p_request_id));
  return jsonb_build_object('id',target.id,'status',target.status,'version',target.management_version);
end $$;

create or replace function public.delete_circular(p_request_id uuid,p_circular_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target public.circulars%rowtype; actor record; response jsonb; fingerprint text; prior_fingerprint text;
begin
  select * into target from public.circulars c where c.id=p_circular_id for update;
  if target.id is null then raise insufficient_privilege using message='circular_not_found'; end if;
  select * into actor from app_private.circular_actor(target.institution_id,'circulars.circulars.create',target.unit_id,target.group_id);
  if target.author_person_id<>actor.person_id and not app_private.has_institution_permission(target.institution_id,'circulars.circulars.manage',target.unit_id,target.group_id,false)
  then raise insufficient_privilege using message='circular_manage_denied'; end if;
  fingerprint:=pg_catalog.encode(extensions.digest(pg_catalog.convert_to(p_circular_id::text||p_expected_version::text,'UTF8'),'sha256'),'hex');
  select receipt.response,receipt.request_fingerprint into response,prior_fingerprint
  from app_private.circular_command_receipts receipt
  where receipt.actor_person_id=actor.person_id and receipt.command_name='delete' and receipt.request_id=p_request_id;
  if response is not null then
    if prior_fingerprint<>fingerprint then raise unique_violation using message='request_id_conflict'; end if;
    return response;
  end if;
  if target.deleted_at is not null or target.management_version<>p_expected_version then raise serialization_failure using message='expected_version_conflict'; end if;
  if target.current_revision_id is null and not exists(select 1 from public.circular_response_sessions session where session.circular_id=target.id) then
    update public.circular_media_assets set status='orphaned' where circular_id=target.id and status in ('pending','ready');
  end if;
  update public.circulars set status='archived',deleted_at=now(),management_version=management_version+1,updated_at=now()
  where id=target.id returning * into target;
  response:=jsonb_build_object('id',target.id,'version',target.management_version,'status',target.status,'deleted',true);
  insert into app_private.circular_command_receipts(actor_person_id,command_name,request_id,request_fingerprint,response)
  values(actor.person_id,'delete',p_request_id,fingerprint,response);
  insert into app_private.circular_audit(circular_id,revision_id,institution_id,actor_person_id,event_code,detail)
  values(target.id,target.current_revision_id,target.institution_id,actor.person_id,'circular_deleted',jsonb_build_object('logical',true));
  return response;
end $$;

create or replace function app_private.circular_response_unit(p_revision_id uuid,p_person_id uuid,p_payload jsonb)
returns table(unit_key text,response_person_id uuid,child_context_id uuid) language plpgsql stable security definer set search_path='' as $$
declare target public.circulars%rowtype; child uuid:=nullif(p_payload->>'child_context_id','')::uuid;
begin
  select c.* into target from public.circulars c join public.circular_revisions r on r.circular_id=c.id where r.id=p_revision_id;
  if target.response_policy in ('per_person','per_staff_member') then
    return query select 'person:'||p_person_id::text,p_person_id,null::uuid; return;
  end if;
  if child is null or not exists(
    select 1 from public.child_contexts cc join public.guardian_links gl on gl.child_person_id=cc.child_person_id
    join public.guardian_context_permissions gp on gp.child_context_id=cc.id and gp.guardian_link_id=gl.id
    where cc.id=child and cc.institution_id=target.institution_id and cc.status='active' and gl.guardian_person_id=p_person_id
      and gl.status='active' and gl.revoked_at is null and gp.status='active' and gp.can_view
      and (gp.starts_at is null or gp.starts_at<=now()) and (gp.expires_at is null or gp.expires_at>now())
  ) then raise insufficient_privilege using message='child_response_scope_denied'; end if;
  if target.response_policy='per_child_any_guardian' then return query select 'child:'||child::text,null::uuid,child;
  else return query select 'child_guardian:'||child::text||':'||p_person_id::text,p_person_id,child; end if;
end $$;

create or replace function public.save_circular_response_draft(
  p_request_id uuid,p_revision_id uuid,p_answers jsonb,p_expected_version bigint
) returns jsonb language plpgsql security definer set search_path='' as $$
declare target public.circulars%rowtype; actor record; unit record; session public.circular_response_sessions%rowtype; answer jsonb; option_id uuid; selected_count integer;
begin
  select c.* into target from public.circulars c join public.circular_revisions r on r.circular_id=c.id where r.id=p_revision_id and r.status='published';
  if target.id is null or target.responses_closed_at is not null or (target.responses_close_at is not null and target.responses_close_at<=now()) then raise check_violation using message='circular_responses_closed'; end if;
  select * into actor from app_private.circular_actor(target.institution_id,'circulars.circulars.respond',target.unit_id,target.group_id);
  if not app_private.circular_visible(target,actor.person_id,actor.role_code,target.unit_id,target.group_id,target.activity_id) then raise insufficient_privilege using message='circular_response_denied'; end if;
  select * into unit from app_private.circular_response_unit(p_revision_id,actor.person_id,p_answers);
  select * into session from public.circular_response_sessions s where s.revision_id=p_revision_id and s.response_unit_key=unit.unit_key for update;
  if session.id is null then
    if p_expected_version not in (0,1) then raise serialization_failure using message='expected_version_conflict'; end if;
    insert into public.circular_response_sessions(circular_id,revision_id,institution_id,response_unit_key,response_person_id,child_context_id,last_actor_person_id)
    values(target.id,p_revision_id,target.institution_id,unit.unit_key,unit.response_person_id,unit.child_context_id,actor.person_id) returning * into session;
  else
    if session.response_version<>p_expected_version then raise serialization_failure using message='expected_version_conflict'; end if;
    update public.circular_response_sessions set response_version=response_version+1,last_actor_person_id=actor.person_id,status='partial',updated_at=now() where id=session.id returning * into session;
    delete from public.circular_answers where session_id=session.id;
  end if;
  for answer in select value from jsonb_array_elements(coalesce(p_answers->'answers','[]')) loop
    if not exists(select 1 from public.circular_questions q where q.id=(answer->>'question_id')::uuid and q.revision_id=p_revision_id) then raise insufficient_privilege using message='question_scope_invalid'; end if;
    selected_count:=jsonb_array_length(coalesce(answer->'option_ids','[]'));
    if selected_count<1 or selected_count>10 then raise check_violation using message='answer_option_count_invalid'; end if;
    if (select q.question_kind from public.circular_questions q where q.id=(answer->>'question_id')::uuid)='single_choice' and selected_count<>1
    then raise check_violation using message='single_choice_invalid'; end if;
    insert into public.circular_answers(session_id,question_id) values(session.id,(answer->>'question_id')::uuid);
    for option_id in select value::uuid from jsonb_array_elements_text(coalesce(answer->'option_ids','[]')) loop
      insert into public.circular_answer_options(session_id,question_id,option_id) values(session.id,(answer->>'question_id')::uuid,option_id);
    end loop;
  end loop;
  insert into public.circular_response_revisions(session_id,response_version,actor_person_id,status,snapshot) values(session.id,session.response_version,actor.person_id,'partial',p_answers);
  return jsonb_build_object('session_id',session.id,'version',session.response_version,'status',session.status,'request_id',p_request_id);
end $$;

create or replace function public.submit_circular_response(p_request_id uuid,p_session_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare session public.circular_response_sessions%rowtype; target public.circulars%rowtype; actor record; response_unit record;
begin
  select * into session from public.circular_response_sessions s where s.id=p_session_id for update;
  select * into target from public.circulars c where c.id=session.circular_id;
  select * into actor from app_private.circular_actor(target.institution_id,'circulars.circulars.respond',target.unit_id,target.group_id);
  if session.id is null or session.response_version<>p_expected_version or target.responses_closed_at is not null or (target.responses_close_at is not null and target.responses_close_at<=now())
  then raise serialization_failure using message='expected_version_conflict'; end if;
  select * into response_unit from app_private.circular_response_unit(
    session.revision_id,actor.person_id,jsonb_build_object('child_context_id',session.child_context_id)
  );
  if response_unit.unit_key is distinct from session.response_unit_key then raise insufficient_privilege using message='response_unit_denied'; end if;
  if exists(select 1 from public.circular_questions q where q.revision_id=session.revision_id and q.required and not exists(select 1 from public.circular_answers a where a.session_id=session.id and a.question_id=q.id))
  then raise check_violation using message='required_question_missing'; end if;
  update public.circular_response_sessions set status='submitted',submitted_at=now(),response_version=response_version+1,last_actor_person_id=actor.person_id,updated_at=now() where id=session.id returning * into session;
  insert into public.circular_response_revisions(session_id,response_version,actor_person_id,status,snapshot)
  values(session.id,session.response_version,actor.person_id,'submitted',jsonb_build_object('request_id',p_request_id,'submitted_at',session.submitted_at));
  return jsonb_build_object('session_id',session.id,'version',session.response_version,'status',session.status,'submitted_at',session.submitted_at);
end $$;

create or replace function public.list_visible_profile_circulars(
  p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_activity_id uuid,p_before_at timestamptz,p_before_id uuid,p_limit integer default 20
) returns table(item_id uuid,title text,excerpt text,author_name text,context_label text,effective_published_at timestamptz,revised_at timestamptz,attachment_count bigint,question_count bigint,response_state text)
language plpgsql security definer set search_path='' as $$
declare actor record;
begin
  select * into actor from app_private.circular_actor(p_institution_id,'circulars.circulars.read',p_unit_id,p_group_id);
  return query select c.id,r.title,left(r.body_text,320),p.display_name,coalesce(g.name,u.name,i.public_name),c.publish_at,c.revised_at,
    (select count(*) from public.circular_media_links ml where ml.revision_id=r.id),
    (select count(*) from public.circular_questions q where q.revision_id=r.id),
    case when exists(select 1 from public.circular_response_sessions s where s.revision_id=r.id and s.last_actor_person_id=actor.person_id and s.status='submitted') then 'answered'
      when exists(select 1 from public.circular_response_sessions s where s.revision_id=r.id and s.last_actor_person_id=actor.person_id) then 'partial' else 'unanswered' end
  from public.circulars c join public.circular_revisions r on r.id=c.current_revision_id join public.people p on p.id=c.author_person_id
  join public.institutions i on i.id=c.institution_id left join public.units u on u.id=c.unit_id left join public.groups g on g.id=c.group_id
  where c.institution_id=p_institution_id and app_private.circular_visible(c,actor.person_id,actor.role_code,p_unit_id,p_group_id,p_activity_id)
    and (p_before_at is null or (c.publish_at,c.id)<(p_before_at,p_before_id))
  order by c.publish_at desc,c.id desc limit least(greatest(coalesce(p_limit,20),1),50);
end $$;

create or replace function public.get_visible_circular(p_circular_id uuid,p_child_context_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target public.circulars%rowtype; revision public.circular_revisions%rowtype; actor record; response_unit record; response_session public.circular_response_sessions%rowtype;
begin
  select * into target from public.circulars c where c.id=p_circular_id and c.deleted_at is null;
  if target.id is null then raise insufficient_privilege using message='circular_not_found'; end if;
  select * into actor from app_private.circular_actor(target.institution_id,'circulars.circulars.read',target.unit_id,target.group_id);
  if not app_private.circular_audience_visible(target,actor.person_id,actor.role_code,target.unit_id,target.group_id,target.activity_id) then raise insufficient_privilege using message='circular_not_found'; end if;
  if target.publish_at>now() then raise check_violation using message='circular_not_available'; end if;
  select * into revision from public.circular_revisions r where r.id=target.current_revision_id;
  if target.response_policy in ('per_person','per_staff_member') or p_child_context_id is not null then
    select * into response_unit from app_private.circular_response_unit(
      revision.id,actor.person_id,jsonb_build_object('child_context_id',p_child_context_id)
    );
    select * into response_session from public.circular_response_sessions s
    where s.revision_id=revision.id and s.response_unit_key=response_unit.unit_key;
  end if;
  return jsonb_build_object('id',target.id,'revision_id',revision.id,'title',revision.title,'body_text',revision.body_text,'published_at',target.publish_at,'revised_at',target.revised_at,
    'author_name',(select p.display_name from public.people p where p.id=target.author_person_id),
    'context_label',coalesce((select g.name from public.groups g where g.id=target.group_id),(select u.name from public.units u where u.id=target.unit_id),(select i.public_name from public.institutions i where i.id=target.institution_id)),
    'response_state',case when response_session.status='submitted' then 'answered' when response_session.id is not null then 'partial' else 'unanswered' end,
    'response_session_id',response_session.id,'response_version',coalesce(response_session.response_version,0),
    'response_context_required',target.response_policy in ('per_child_any_guardian','per_child_each_guardian') and p_child_context_id is null,
    'answers',case when response_session.id is null then '{}'::jsonb else (select coalesce(jsonb_object_agg(answer.question_id::text,(
      select coalesce(jsonb_agg(selected.option_id::text order by selected.option_id),'[]'::jsonb)
      from public.circular_answer_options selected where selected.session_id=answer.session_id and selected.question_id=answer.question_id
    )),'{}'::jsonb) from public.circular_answers answer where answer.session_id=response_session.id) end,
    'status',target.status,'response_policy',target.response_policy,'responses_close_at',target.responses_close_at,'responses_closed_at',target.responses_closed_at,
    'blocks',(select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'kind',b.block_kind,'text',b.text_content,'order',b.display_order,'media',(
      select coalesce(jsonb_agg(jsonb_build_object('asset_id',m.id,'mime_type',m.mime_type,'name',m.original_name,'order',l.display_order) order by l.display_order),'[]') from public.circular_media_links l join public.circular_media_assets m on m.id=l.media_asset_id where l.block_id=b.id and m.status='ready'),
      'question',(select jsonb_build_object('id',q.id,'prompt',q.prompt,'kind',q.question_kind,'required',q.required,'options',(
        select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'label',o.label,'order',o.display_order) order by o.display_order),'[]') from public.circular_question_options o where o.question_id=q.id)) from public.circular_questions q where q.block_id=b.id)) order by b.display_order),'[]') from public.circular_blocks b where b.revision_id=revision.id));
end $$;

create or replace function public.authorize_circular_media_read(p_asset_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare asset public.circular_media_assets%rowtype; target public.circulars%rowtype; actor record;
begin
  select * into asset from public.circular_media_assets m where m.id=p_asset_id and m.status='ready';
  select * into target from public.circulars c where c.id=asset.circular_id;
  select * into actor from app_private.circular_actor(target.institution_id,'circulars.circulars.read',target.unit_id,target.group_id);
  if asset.id is null or not app_private.circular_visible(target,actor.person_id,actor.role_code,target.unit_id,target.group_id,target.activity_id) then raise insufficient_privilege using message='media_read_denied'; end if;
  return jsonb_build_object('bucket_id',asset.bucket_id,'object_key',asset.object_key,'mime_type',asset.mime_type,'byte_size',asset.byte_size);
end $$;

create or replace function app_private.circular_feed_post_media(p_post_id uuid,p_viewer_person_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare item record; ticket uuid; result jsonb:='[]'::jsonb;
begin
  for item in
    select asset.id,asset.mime_type,link.display_order
    from public.media_links link
    join public.media_assets asset on asset.id=link.media_asset_id
    where link.post_id=p_post_id and asset.status='ready'
    order by link.display_order
  loop
    insert into app_private.happens_media_read_tickets(media_asset_id,viewer_person_id)
    values(item.id,p_viewer_person_id) returning token into ticket;
    result:=result||jsonb_build_array(jsonb_build_object(
      'read_ticket',ticket,'mime_type',item.mime_type,'display_order',item.display_order
    ));
  end loop;
  return result;
end $$;

create or replace function app_private.circular_feed_post_visible(
  p_post public.posts,p_person_id uuid,p_role text,p_unit_id uuid,p_group_id uuid
) returns boolean language sql stable security definer set search_path='' as $$
  select p_post.status in ('scheduled','published') and p_post.publish_at<=now()
    and (p_post.unit_id is null or p_post.unit_id=p_unit_id)
    and (p_post.group_id is null or p_post.group_id=p_group_id)
    and exists (
      select 1 from public.post_audiences audience
      where audience.post_id=p_post.id and audience.institution_id=p_post.institution_id
        and audience.unit_id is not distinct from p_post.unit_id
        and audience.group_id is not distinct from p_post.group_id
        and case
          when lower(coalesce(p_role,'')) in ('guardian','responsible','responsavel','parent','family') then
            audience.audience_kind in ('families','guardians_only') and exists (
              select 1
              from public.guardian_links guardian
              join public.guardian_context_permissions permission on permission.guardian_link_id=guardian.id
              join public.child_contexts child on child.id=permission.child_context_id
              where guardian.guardian_person_id=p_person_id
                and guardian.status='active' and guardian.revoked_at is null
                and permission.status='active' and permission.can_view
                and (permission.starts_at is null or permission.starts_at<=now())
                and (permission.expires_at is null or permission.expires_at>now())
                and child.institution_id=p_post.institution_id and child.status='active'
                and (p_post.unit_id is null or exists (
                  select 1 from public.child_unit_links child_unit
                  where child_unit.child_context_id=child.id and child_unit.unit_id=p_post.unit_id
                    and child_unit.status='active' and child_unit.revoked_at is null
                    and (p_post.group_id is null or exists (
                      select 1 from public.child_group_links child_group
                      where child_group.child_unit_link_id=child_unit.id and child_group.group_id=p_post.group_id
                        and child_group.status='active'
                        and (child_group.starts_at is null or child_group.starts_at<=now())
                        and (child_group.ends_at is null or child_group.ends_at>now())
                    ))
                ))
            )
          when lower(coalesce(p_role,'')) in ('student','aluno') then
            audience.audience_kind='students' and exists (
              select 1 from public.child_contexts child
              where child.child_person_id=p_person_id and child.institution_id=p_post.institution_id and child.status='active'
                and (p_post.unit_id is null or exists (
                  select 1 from public.child_unit_links child_unit
                  where child_unit.child_context_id=child.id and child_unit.unit_id=p_post.unit_id
                    and child_unit.status='active' and child_unit.revoked_at is null
                    and (p_post.group_id is null or exists (
                      select 1 from public.child_group_links child_group
                      where child_group.child_unit_link_id=child_unit.id and child_group.group_id=p_post.group_id
                        and child_group.status='active'
                        and (child_group.starts_at is null or child_group.starts_at<=now())
                        and (child_group.ends_at is null or child_group.ends_at>now())
                    ))
                ))
            )
          when lower(coalesce(p_role,'')) in ('professional','institution_admin','unit_admin','teacher','coordinator') then
            audience.audience_kind='school_staff'
          else false
        end
    )
$$;

create or replace function public.list_visible_happens_feed(
  p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_activity_id uuid,p_before_at timestamptz,p_before_type text,p_before_id uuid,p_limit integer default 20
) returns table(item_type text,item_id uuid,effective_published_at timestamptz,payload jsonb)
language plpgsql security definer set search_path='' as $$
declare actor record; actor_role text;
begin
  select * into actor from app_private.happens_actor(p_institution_id,'happens.posts.read',p_unit_id,p_group_id);
  select lower(m.role_code) into actor_role from public.institution_memberships m where m.id=actor.membership_id;
  delete from app_private.happens_media_read_tickets ticket where ticket.expires_at<=now();
  return query
  with authorized_items as (
    select 'post'::text as kind,post.id,coalesce(post.published_at,post.publish_at) as at,
      jsonb_build_object('author_name',person.display_name,'author_initials',upper(left(person.display_name,1)),'context_label',coalesce(g.name,u.name,i.public_name),'caption',post.caption,'media',app_private.circular_feed_post_media(post.id,actor.person_id)) as body
    from public.posts post join public.people person on person.id=post.author_person_id join public.institutions i on i.id=post.institution_id
    left join public.units u on u.id=post.unit_id left join public.groups g on g.id=post.group_id
    where post.institution_id=p_institution_id
      and app_private.circular_feed_post_visible(post,actor.person_id,actor_role,p_unit_id,p_group_id)
    union all
    select 'circular',c.id,c.publish_at,jsonb_build_object('author_name',person.display_name,'author_initials',upper(left(person.display_name,1)),'context_label',coalesce(g.name,u.name,i.public_name),
      'title',r.title,'excerpt',left(r.body_text,420),'revised_at',c.revised_at,'attachment_count',(select count(*) from public.circular_media_links ml where ml.revision_id=r.id),
      'question_count',(select count(*) from public.circular_questions q where q.revision_id=r.id),'response_state',case when exists(select 1 from public.circular_response_sessions s where s.revision_id=r.id and s.last_actor_person_id=actor.person_id and s.status='submitted') then 'answered' when exists(select 1 from public.circular_response_sessions s where s.revision_id=r.id and s.last_actor_person_id=actor.person_id) then 'partial' else 'unanswered' end)
    from public.circulars c join public.circular_revisions r on r.id=c.current_revision_id join public.people person on person.id=c.author_person_id join public.institutions i on i.id=c.institution_id
    left join public.units u on u.id=c.unit_id left join public.groups g on g.id=c.group_id
    where c.institution_id=p_institution_id
      and app_private.has_institution_permission(c.institution_id,'circulars.circulars.read',c.unit_id,c.group_id,false)
      and app_private.circular_visible(c,actor.person_id,actor_role,p_unit_id,p_group_id,p_activity_id)
  )
  select source.kind,source.id,source.at,source.body from authorized_items source
  where p_before_at is null or (source.at,source.kind,source.id)<(p_before_at,coalesce(p_before_type,'zz'),p_before_id)
  order by source.at desc,source.kind desc,source.id desc limit least(greatest(coalesce(p_limit,20),1),50);
end $$;

create or replace function app_private.claim_stale_circular_media(p_limit integer default 50)
returns table(asset_id uuid,object_key text) language plpgsql security definer set search_path='' as $$
begin
  return query with claimed as (
    select m.id from public.circular_media_assets m where m.status in ('pending','orphaned') and m.created_at<now()-interval '30 minutes'
      and (m.cleanup_attempted_at is null or m.cleanup_attempted_at<now()-interval '10 minutes') order by m.created_at for update skip locked limit least(greatest(coalesce(p_limit,50),1),200)
  ) update public.circular_media_assets m set status='orphaned',cleanup_attempted_at=now() from claimed where m.id=claimed.id returning m.id,m.object_key;
end $$;
create or replace function app_private.mark_circular_media_deleted(p_asset_id uuid) returns void language sql security definer set search_path='' as $$
  update public.circular_media_assets set status='deleted' where id=p_asset_id and status='orphaned'
$$;

create or replace function public.claim_stale_circular_media(p_limit integer default 50)
returns table(asset_id uuid,object_key text) language sql security definer set search_path='' as $$
  select * from app_private.claim_stale_circular_media(p_limit)
$$;
create or replace function public.mark_circular_media_deleted(p_asset_id uuid)
returns void language sql security definer set search_path='' as $$
  select app_private.mark_circular_media_deleted(p_asset_id)
$$;

revoke all on function app_private.circular_actor(uuid,text,uuid,uuid),app_private.circular_audience_matches_role(text,public.circular_audience_kind),
  app_private.circular_child_scope_matches(uuid,public.circular_audience_rules),
  app_private.circular_person_matches_scope(uuid,text,public.circular_audience_rules),
  app_private.circular_feed_post_media(uuid,uuid),
  app_private.circular_feed_post_visible(public.posts,uuid,text,uuid,uuid),
  app_private.circular_audience_visible(public.circulars,uuid,text,uuid,uuid,uuid),
  app_private.circular_visible(public.circulars,uuid,text,uuid,uuid,uuid),app_private.circular_validate_scope(uuid,uuid,uuid,uuid),
  app_private.circular_response_unit(uuid,uuid,jsonb),app_private.claim_stale_circular_media(integer),app_private.mark_circular_media_deleted(uuid)
from public,anon,authenticated,service_role;
revoke all on function public.load_circular_draft(uuid,uuid,uuid,uuid),public.save_circular_draft(uuid,jsonb,uuid,bigint),
  public.prepare_circular_media_upload(uuid,uuid,uuid,text,text,bigint),public.authorize_circular_media_finalize(uuid),
  public.finalize_circular_media_upload(uuid,uuid,bigint,text,text,text),public.remove_circular_media(uuid),
  public.publish_circular(uuid,uuid,bigint,timestamptz),public.close_circular_responses(uuid,uuid,bigint),public.delete_circular(uuid,uuid,bigint),
  public.save_circular_response_draft(uuid,uuid,jsonb,bigint),public.submit_circular_response(uuid,uuid,bigint),
  public.list_visible_profile_circulars(uuid,uuid,uuid,uuid,timestamptz,uuid,integer),public.get_visible_circular(uuid,uuid),
  public.authorize_circular_media_read(uuid),public.list_visible_happens_feed(uuid,uuid,uuid,uuid,timestamptz,text,uuid,integer)
  ,public.claim_stale_circular_media(integer),public.mark_circular_media_deleted(uuid)
from public,anon,authenticated,service_role;
grant execute on function public.load_circular_draft(uuid,uuid,uuid,uuid),public.save_circular_draft(uuid,jsonb,uuid,bigint),
  public.prepare_circular_media_upload(uuid,uuid,uuid,text,text,bigint),public.authorize_circular_media_finalize(uuid),public.remove_circular_media(uuid),
  public.publish_circular(uuid,uuid,bigint,timestamptz),public.close_circular_responses(uuid,uuid,bigint),public.delete_circular(uuid,uuid,bigint),
  public.save_circular_response_draft(uuid,uuid,jsonb,bigint),public.submit_circular_response(uuid,uuid,bigint),
  public.list_visible_profile_circulars(uuid,uuid,uuid,uuid,timestamptz,uuid,integer),public.get_visible_circular(uuid,uuid),
  public.authorize_circular_media_read(uuid),public.list_visible_happens_feed(uuid,uuid,uuid,uuid,timestamptz,text,uuid,integer)
to authenticated;
grant execute on function public.finalize_circular_media_upload(uuid,uuid,bigint,text,text,text),app_private.claim_stale_circular_media(integer),app_private.mark_circular_media_deleted(uuid) to service_role;
grant execute on function public.claim_stale_circular_media(integer),public.mark_circular_media_deleted(uuid) to service_role;
