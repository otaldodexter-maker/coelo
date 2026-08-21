-- Supabase privado temporário para o composer do Agora. ADR 0026.
create type public.now_publication_status as enum ('draft','scheduled','published','expired');
create type public.now_audience_kind as enum ('families','students','school_staff','guardians_only');
create type public.now_asset_kind as enum ('media','audio','cover');
create type public.now_asset_status as enum ('pending','ready','quarantined','deleted');

create table public.now_publications(
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id),
  unit_id uuid references public.units(id),
  group_id uuid references public.groups(id),
  author_person_id uuid not null references public.people(id),
  author_membership_id uuid not null references public.institution_memberships(id),
  caption text not null default '' check(char_length(caption)<=60),
  overlay_text text not null default '' check(char_length(overlay_text)<=60),
  crop_scale numeric(4,2) not null default 1 check(crop_scale between 1 and 2),
  crop_x numeric(4,3) not null default 0 check(crop_x between -1 and 1),
  crop_y numeric(4,3) not null default 0 check(crop_y between -1 and 1),
  cover_position numeric(4,3) not null default 0 check(cover_position between 0 and 1),
  status public.now_publication_status not null default 'draft',
  publish_at timestamptz,
  published_at timestamptz,
  expires_at timestamptz,
  management_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(unit_id is not null or group_id is null),
  check(status='draft' or publish_at is not null),
  check(expires_at is null or status in('scheduled','published','expired'))
);
create index now_publications_feed_idx on public.now_publications(institution_id,publish_at desc,id) where status in('scheduled','published');
create index now_publications_author_draft_idx on public.now_publications(author_person_id,updated_at desc) where status='draft';
create index now_publications_unit_fk_idx on public.now_publications(unit_id) where unit_id is not null;
create index now_publications_group_fk_idx on public.now_publications(group_id) where group_id is not null;
create index now_publications_membership_fk_idx on public.now_publications(author_membership_id);

create table public.now_publication_audiences(
  publication_id uuid not null references public.now_publications(id) on delete cascade,
  audience_kind public.now_audience_kind not null,
  institution_id uuid not null references public.institutions(id),
  unit_id uuid references public.units(id),
  group_id uuid references public.groups(id),
  primary key(publication_id,audience_kind)
);
create index now_publication_audiences_scope_idx on public.now_publication_audiences(institution_id,unit_id,group_id);

create table public.now_media_assets(
  id uuid primary key default gen_random_uuid(),
  publication_id uuid not null references public.now_publications(id) on delete cascade,
  institution_id uuid not null references public.institutions(id),
  owner_person_id uuid not null references public.people(id),
  kind public.now_asset_kind not null,
  storage_provider text not null default 'supabase_mvp' check(storage_provider in('supabase_mvp','r2')),
  bucket_id text not null default 'coelo-now-mvp',
  object_key text not null unique,
  original_name text not null,
  mime_type text not null check(mime_type in('image/jpeg','image/png','image/webp','video/mp4','audio/mpeg','audio/mp4','audio/wav','audio/aac')),
  byte_size bigint not null check(byte_size>0),
  duration_seconds numeric(7,3),
  rights_confirmed boolean not null default false,
  checksum_sha256 text,
  status public.now_asset_status not null default 'pending',
  created_at timestamptz not null default now(),
  finalized_at timestamptz,
  unique(publication_id,kind),
  check(kind<>'audio' or rights_confirmed)
);
create index now_media_assets_owner_idx on public.now_media_assets(institution_id,owner_person_id,status);

create table app_private.now_publication_audit(
  id bigint generated always as identity primary key,
  publication_id uuid,
  institution_id uuid not null,
  actor_person_id uuid not null,
  event_code text not null,
  request_id uuid,
  response jsonb,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index now_publication_audit_publication_idx on app_private.now_publication_audit(publication_id,created_at desc);
create unique index now_publication_audit_idempotency_idx
  on app_private.now_publication_audit(actor_person_id,event_code,request_id)
  where request_id is not null;

create table app_private.now_media_read_tickets(
  token uuid primary key default gen_random_uuid(),
  media_asset_id uuid not null references public.now_media_assets(id) on delete cascade,
  viewer_person_id uuid not null references public.people(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '2 minutes'),
  created_at timestamptz not null default now()
);
create index now_media_read_tickets_expiry_idx
  on app_private.now_media_read_tickets(expires_at);
revoke all on app_private.now_media_read_tickets from public,anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('coelo-now-mvp','coelo-now-mvp',false,26214400,array['image/jpeg','image/png','image/webp','video/mp4','audio/mpeg','audio/mp4','audio/wav','audio/aac'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

alter table public.now_publications enable row level security;
alter table public.now_publications force row level security;
alter table public.now_publication_audiences enable row level security;
alter table public.now_publication_audiences force row level security;
alter table public.now_media_assets enable row level security;
alter table public.now_media_assets force row level security;
revoke all on public.now_publications,public.now_publication_audiences,public.now_media_assets from anon,authenticated;

insert into public.institution_permissions(
  code,module_code,screen_code,action_code,description,risk_level,
  requires_mfa,status,module_label,screen_label,action_label
)
values
 ('now.publications.create','now','publications','create','Criar e manter rascunhos do Agora no contexto autorizado.','high',false,'active','Agora','Publicações','Criar'),
 ('now.publications.publish','now','publications','publish','Publicar ou agendar no Agora no contexto autorizado.','critical',false,'active','Agora','Publicações','Publicar'),
 ('now.publications.read','now','publications','read','Ler publicações privadas do Agora no contexto autorizado.','normal',false,'active','Agora','Publicações','Ler')
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

create or replace function app_private.now_actor(p_institution_id uuid,p_permission text,p_unit_id uuid,p_group_id uuid)
returns table(person_id uuid,membership_id uuid) language plpgsql stable security definer set search_path='' as $$
begin
  if (select auth.uid()) is null then raise insufficient_privilege using message='authentication_required'; end if;
  if p_unit_id is not null and not exists(
    select 1 from public.units where id=p_unit_id and institution_id=p_institution_id
  ) then raise insufficient_privilege using message='context_not_authorized'; end if;
  if p_group_id is not null and (
    p_unit_id is null or not exists(
      select 1 from public.groups
      where id=p_group_id and institution_id=p_institution_id and unit_id=p_unit_id
    )
  ) then raise insufficient_privilege using message='context_not_authorized'; end if;
  if not app_private.has_institution_permission(p_institution_id,p_permission,p_unit_id,p_group_id,false)
  then raise insufficient_privilege using message='now_permission_denied'; end if;
  return query select link.person_id,membership.id
  from public.person_auth_links link join public.institution_memberships membership on membership.person_id=link.person_id
  where link.auth_user_id=(select auth.uid()) and link.status='active' and membership.institution_id=p_institution_id
    and membership.status='active' and membership.revoked_at is null order by membership.created_at limit 1;
  if not found then raise insufficient_privilege using message='active_membership_required'; end if;
end $$;
revoke all on function app_private.now_actor(uuid,text,uuid,uuid) from public,anon,authenticated;

create or replace function app_private.now_audience_matches_role(
  p_role_code text,
  p_audience public.now_audience_kind
)
returns boolean language sql immutable set search_path='' as $$
  select case
    when lower(coalesce(p_role_code,'')) in ('guardian','responsible','responsavel','parent','family')
      then p_audience in ('families','guardians_only')
    when lower(coalesce(p_role_code,'')) in ('student','aluno')
      then p_audience='students'
    when lower(coalesce(p_role_code,'')) in (
      'professional','institution_admin','unit_admin','teacher','coordinator'
    ) then p_audience='school_staff'
    else false
  end
$$;
revoke all on function app_private.now_audience_matches_role(text,public.now_audience_kind)
  from public,anon,authenticated;

create or replace function app_private.now_viewer_has_context(
  p_person_id uuid,
  p_role_code text,
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid
)
returns boolean language sql stable security definer set search_path='' as $$
  select case
    when lower(coalesce(p_role_code,'')) in ('student','aluno') then exists(
      select 1
      from public.child_contexts child_context
      left join public.child_unit_links unit_link
        on unit_link.child_context_id=child_context.id
       and unit_link.status='active'
       and unit_link.revoked_at is null
      left join public.child_group_links group_link
        on group_link.child_unit_link_id=unit_link.id
       and group_link.status='active'
       and (group_link.starts_at is null or group_link.starts_at<=now())
       and (group_link.ends_at is null or group_link.ends_at>now())
      where child_context.child_person_id=p_person_id
        and child_context.institution_id=p_institution_id
        and child_context.status='active'
        and child_context.archived_at is null
        and (p_unit_id is null or unit_link.unit_id=p_unit_id)
        and (p_group_id is null or group_link.group_id=p_group_id)
    )
    when lower(coalesce(p_role_code,'')) in ('guardian','responsible','responsavel','parent','family') then exists(
      select 1
      from public.guardian_links guardian
      join public.child_contexts child_context
        on child_context.child_person_id=guardian.child_person_id
       and child_context.institution_id=p_institution_id
       and child_context.status='active'
       and child_context.archived_at is null
      join public.guardian_context_permissions guardian_permission
        on guardian_permission.guardian_link_id=guardian.id
       and guardian_permission.child_context_id=child_context.id
       and guardian_permission.can_view
       and guardian_permission.status='active'
       and (guardian_permission.starts_at is null or guardian_permission.starts_at<=now())
       and (guardian_permission.expires_at is null or guardian_permission.expires_at>now())
      left join public.child_unit_links unit_link
        on unit_link.child_context_id=child_context.id
       and unit_link.status='active'
       and unit_link.revoked_at is null
      left join public.child_group_links group_link
        on group_link.child_unit_link_id=unit_link.id
       and group_link.status='active'
       and (group_link.starts_at is null or group_link.starts_at<=now())
       and (group_link.ends_at is null or group_link.ends_at>now())
      where guardian.guardian_person_id=p_person_id
        and guardian.status='active'
        and guardian.revoked_at is null
        and (p_unit_id is null or unit_link.unit_id=p_unit_id)
        and (p_group_id is null or group_link.group_id=p_group_id)
    )
    when lower(coalesce(p_role_code,'')) in (
      'professional','institution_admin','unit_admin','teacher','coordinator'
    ) then true
    else false
  end
$$;
revoke all on function app_private.now_viewer_has_context(uuid,text,uuid,uuid,uuid)
  from public,anon,authenticated;

create or replace function app_private.now_max_video_seconds(p_institution_id uuid)
returns integer language sql stable security definer set search_path='' as $$
  select greatest(30,coalesce((
    select case jsonb_typeof(entitlement.value_json)
      when 'number' then entitlement.value_json#>>'{}'
      else entitlement.value_json->>'value'
    end::integer
    from public.institution_subscriptions subscription
    join public.plan_entitlements entitlement on entitlement.plan_id=subscription.plan_id
    where subscription.institution_id=p_institution_id
      and subscription.status::text in('active','trial')
      and entitlement.entitlement_key='now.max_video_seconds'
      and entitlement.status::text='active'
    order by subscription.created_at desc limit 1
  ),30));
$$;
revoke all on function app_private.now_max_video_seconds(uuid) from public,anon,authenticated;

create or replace function public.load_now_draft(p_institution_id uuid,p_unit_id uuid,p_group_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor record;target public.now_publications%rowtype;
begin
  select * into actor from app_private.now_actor(p_institution_id,'now.publications.create',p_unit_id,p_group_id);
  select * into target from public.now_publications where institution_id=p_institution_id and author_person_id=actor.person_id and status='draft'
    and unit_id is not distinct from p_unit_id and group_id is not distinct from p_group_id order by updated_at desc limit 1;
  if target.id is null then return null; end if;
  return jsonb_build_object('id',target.id,'caption',target.caption,'overlay_text',target.overlay_text,'crop_scale',target.crop_scale,
    'crop_x',target.crop_x,'crop_y',target.crop_y,'cover_position',target.cover_position,'version',target.management_version,
    'publish_at',target.publish_at,'max_video_seconds',app_private.now_max_video_seconds(p_institution_id),
    'audiences',(select coalesce(jsonb_agg(audience_kind order by audience_kind),'[]') from public.now_publication_audiences where publication_id=target.id),
    'media',(select jsonb_build_object('asset_id',id,'name',original_name,'mime_type',mime_type,'duration_seconds',duration_seconds) from public.now_media_assets where publication_id=target.id and kind='media' and status='ready'),
    'audio',(select jsonb_build_object('asset_id',id,'name',original_name,'mime_type',mime_type,'rights_confirmed',rights_confirmed) from public.now_media_assets where publication_id=target.id and kind='audio' and status='ready'));
end $$;

create or replace function public.save_now_draft(p_request_id uuid,p_draft jsonb,p_publication_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor record;target public.now_publications%rowtype;institution uuid:=(p_draft->>'institution_id')::uuid;unit uuid:=nullif(p_draft->>'unit_id','')::uuid;grp uuid:=nullif(p_draft->>'group_id','')::uuid;kind text;result jsonb;
begin
  select * into actor from app_private.now_actor(institution,'now.publications.create',unit,grp);
  select response into result from app_private.now_publication_audit
    where actor_person_id=actor.person_id and event_code='draft_saved' and request_id=p_request_id;
  if result is not null then return result; end if;
  if char_length(coalesce(p_draft->>'caption',''))>60 or char_length(coalesce(p_draft->>'overlay_text',''))>60 then raise check_violation using message='text_too_long';end if;
  if p_publication_id is null then
    insert into public.now_publications(institution_id,unit_id,group_id,author_person_id,author_membership_id,caption,overlay_text,crop_scale,crop_x,crop_y,cover_position,publish_at)
    values(institution,unit,grp,actor.person_id,actor.membership_id,coalesce(p_draft->>'caption',''),coalesce(p_draft->>'overlay_text',''),
      coalesce((p_draft->>'crop_scale')::numeric,1),coalesce((p_draft->>'crop_x')::numeric,0),coalesce((p_draft->>'crop_y')::numeric,0),coalesce((p_draft->>'cover_position')::numeric,0),nullif(p_draft->>'publish_at','')::timestamptz) returning * into target;
  else
    update public.now_publications set caption=coalesce(p_draft->>'caption',''),overlay_text=coalesce(p_draft->>'overlay_text',''),
      crop_scale=coalesce((p_draft->>'crop_scale')::numeric,1),crop_x=coalesce((p_draft->>'crop_x')::numeric,0),crop_y=coalesce((p_draft->>'crop_y')::numeric,0),cover_position=coalesce((p_draft->>'cover_position')::numeric,0),
      publish_at=nullif(p_draft->>'publish_at','')::timestamptz,management_version=management_version+1,updated_at=now()
    where id=p_publication_id and institution_id=institution and author_person_id=actor.person_id and status='draft' and management_version=p_expected_version returning * into target;
    if target.id is null then raise serialization_failure using message='expected_version_conflict';end if;
  end if;
  delete from public.now_publication_audiences where publication_id=target.id;
  for kind in select jsonb_array_elements_text(coalesce(p_draft->'audiences','[]')) loop
    insert into public.now_publication_audiences(publication_id,audience_kind,institution_id,unit_id,group_id) values(target.id,kind::public.now_audience_kind,institution,unit,grp);
  end loop;
  result:=jsonb_build_object('id',target.id,'version',target.management_version,'max_video_seconds',app_private.now_max_video_seconds(institution));
  insert into app_private.now_publication_audit(publication_id,institution_id,actor_person_id,event_code,request_id,response,detail)
    values(target.id,institution,actor.person_id,'draft_saved',p_request_id,result,jsonb_build_object('version',target.management_version));
  return result;
end $$;

create or replace function public.prepare_now_asset_upload(p_institution_id uuid,p_publication_id uuid,p_kind public.now_asset_kind,p_name text,p_mime_type text,p_byte_size bigint,p_duration_seconds numeric,p_rights_confirmed boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor record;asset public.now_media_assets%rowtype;target public.now_publications%rowtype;key text;max_seconds integer;
begin
  select * into target from public.now_publications
    where id=p_publication_id and institution_id=p_institution_id and status='draft';
  if target.id is null then raise insufficient_privilege using message='publication_not_authorized';end if;
  select * into actor from app_private.now_actor(p_institution_id,'now.publications.create',target.unit_id,target.group_id);
  if target.author_person_id<>actor.person_id then raise insufficient_privilege using message='publication_not_authorized';end if;
  if p_byte_size<1 or p_byte_size>26214400 or char_length(p_name)>255 then raise check_violation using message='invalid_asset_metadata';end if;
  if p_kind='media' and p_mime_type not in('image/jpeg','image/png','image/webp','video/mp4') then raise check_violation using message='unsupported_media_type';end if;
  if p_kind='audio' and (p_mime_type not in('audio/mpeg','audio/mp4','audio/wav','audio/aac') or not p_rights_confirmed) then raise check_violation using message='audio_rights_required';end if;
  if p_kind='cover' and p_mime_type not in('image/jpeg','image/png','image/webp') then raise check_violation using message='unsupported_cover_type';end if;
  max_seconds:=app_private.now_max_video_seconds(p_institution_id);
  if p_mime_type='video/mp4' and (p_duration_seconds is null or p_duration_seconds>max_seconds) then raise check_violation using message='video_duration_exceeded';end if;
  key:=p_institution_id::text||'/'||p_publication_id::text||'/'||p_kind::text;
  insert into public.now_media_assets(publication_id,institution_id,owner_person_id,kind,object_key,original_name,mime_type,byte_size,duration_seconds,rights_confirmed)
  values(p_publication_id,p_institution_id,actor.person_id,p_kind,key,p_name,p_mime_type,p_byte_size,p_duration_seconds,p_rights_confirmed)
  on conflict(publication_id,kind) do update set object_key=excluded.object_key,original_name=excluded.original_name,mime_type=excluded.mime_type,byte_size=excluded.byte_size,duration_seconds=excluded.duration_seconds,rights_confirmed=excluded.rights_confirmed,status='pending',finalized_at=null
  returning * into asset;
  return jsonb_build_object('asset_id',asset.id,'bucket_id',asset.bucket_id,'object_key',asset.object_key);
end $$;

create or replace function public.finalize_now_asset_upload(p_asset_id uuid,p_checksum_sha256 text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare asset public.now_media_assets%rowtype;target public.now_publications%rowtype;actor record;
begin
  select * into asset from public.now_media_assets where id=p_asset_id for update;
  if asset.id is null then raise insufficient_privilege using message='asset_not_authorized';end if;
  select * into target from public.now_publications where id=asset.publication_id;
  select * into actor from app_private.now_actor(asset.institution_id,'now.publications.create',target.unit_id,target.group_id);
  if asset.owner_person_id<>actor.person_id or p_checksum_sha256 !~ '^[0-9a-f]{64}$' or not exists(select 1 from storage.objects where bucket_id=asset.bucket_id and name=asset.object_key) then raise insufficient_privilege using message='asset_not_uploaded';end if;
  update public.now_media_assets set checksum_sha256=p_checksum_sha256,status='ready',finalized_at=now() where id=p_asset_id;
  return jsonb_build_object('asset_id',asset.id,'object_key',asset.object_key);
end $$;

create or replace function public.authorize_now_asset_read(p_institution_id uuid,p_asset_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare asset public.now_media_assets%rowtype;target public.now_publications%rowtype;actor record;
begin
  select * into asset from public.now_media_assets where id=p_asset_id and institution_id=p_institution_id and status='ready';
  if asset.id is null then raise insufficient_privilege using message='asset_not_authorized';end if;
  select * into target from public.now_publications where id=asset.publication_id and status='draft';
  if target.id is null then raise insufficient_privilege using message='asset_not_authorized';end if;
  select * into actor from app_private.now_actor(p_institution_id,'now.publications.create',target.unit_id,target.group_id);
  if asset.owner_person_id<>actor.person_id then raise insufficient_privilege using message='asset_not_authorized';end if;
  return jsonb_build_object(
    'bucket_id',asset.bucket_id,
    'object_key',asset.object_key,
    'mime_type',asset.mime_type
  );
end $$;

create or replace function public.publish_now(p_request_id uuid,p_publication_id uuid,p_expected_version bigint,p_publish_at timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target public.now_publications%rowtype;actor record;at timestamptz:=coalesce(p_publish_at,now());next_status public.now_publication_status;result jsonb;
begin
  select * into target from public.now_publications where id=p_publication_id for update;
  if target.id is null then raise insufficient_privilege using message='publication_not_authorized';end if;
  select * into actor from app_private.now_actor(target.institution_id,'now.publications.publish',target.unit_id,target.group_id);
  select response into result from app_private.now_publication_audit
    where actor_person_id=actor.person_id and event_code in('now_scheduled','now_published') and request_id=p_request_id;
  if result is not null then return result; end if;
  if target.author_person_id<>actor.person_id or target.management_version<>p_expected_version then raise serialization_failure using message='expected_version_conflict';end if;
  if not exists(select 1 from public.now_publication_audiences where publication_id=target.id) then raise check_violation using message='audience_required';end if;
  if not exists(select 1 from public.now_media_assets where publication_id=target.id and kind='media' and status='ready') then raise check_violation using message='media_required';end if;
  next_status:=case when at>now() then 'scheduled'::public.now_publication_status else 'published'::public.now_publication_status end;
  update public.now_publications set status=next_status,publish_at=at,published_at=case when next_status='published' then now() end,
    expires_at=case when next_status='published' then now()+interval '24 hours' else at+interval '24 hours' end,management_version=management_version+1,updated_at=now()
    where id=target.id returning * into target;
  result:=jsonb_build_object('id',target.id,'status',target.status,'publish_at',target.publish_at,'expires_at',target.expires_at);
  insert into app_private.now_publication_audit(publication_id,institution_id,actor_person_id,event_code,request_id,response,detail)
    values(target.id,target.institution_id,actor.person_id,case when next_status='scheduled' then 'now_scheduled' else 'now_published' end,p_request_id,result,jsonb_build_object('publish_at',at,'expires_at',target.expires_at));
  return result;
end $$;

create or replace function public.list_visible_now_publications(
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid,
  p_limit integer default 20
)
returns table(
  publication_id uuid,
  author_name text,
  author_initials text,
  context_label text,
  caption text,
  overlay_text text,
  crop_scale numeric,
  crop_x numeric,
  crop_y numeric,
  cover_position numeric,
  published_at timestamptz,
  expires_at timestamptz,
  media jsonb
) language plpgsql security definer set search_path='' as $$
declare
  actor record;
  actor_role text;
  visible_publication record;
  visible_asset record;
  media_items jsonb;
  read_ticket uuid;
begin
  select * into actor
  from app_private.now_actor(
    p_institution_id,
    'now.publications.read',
    p_unit_id,
    p_group_id
  );
  select lower(membership.role_code) into actor_role
  from public.institution_memberships membership
  where membership.id=actor.membership_id
    and membership.institution_id=p_institution_id
    and membership.status='active'
    and membership.revoked_at is null;
  if actor_role is null then
    raise insufficient_privilege using message='active_membership_required';
  end if;
  if not app_private.now_viewer_has_context(
    actor.person_id,actor_role,p_institution_id,p_unit_id,p_group_id
  ) then
    raise insufficient_privilege using message='viewer_context_not_authorized';
  end if;

  delete from app_private.now_media_read_tickets ticket
  where ticket.expires_at<=now();

  for visible_publication in
    select
      publication.id,
      person.display_name,
      coalesce(scoped_group.name,scoped_unit.name,institution.public_name) as resolved_context,
      publication.caption,
      publication.overlay_text,
      publication.crop_scale,
      publication.crop_x,
      publication.crop_y,
      publication.cover_position,
      coalesce(publication.published_at,publication.publish_at) as resolved_published_at,
      publication.expires_at
    from public.now_publications publication
    join public.people person on person.id=publication.author_person_id
    join public.institutions institution on institution.id=publication.institution_id
    left join public.units scoped_unit on scoped_unit.id=publication.unit_id
    left join public.groups scoped_group on scoped_group.id=publication.group_id
    where publication.institution_id=p_institution_id
      and publication.status in('scheduled','published')
      and publication.publish_at<=now()
      and publication.expires_at>now()
      and (publication.unit_id is null or publication.unit_id=p_unit_id)
      and (publication.group_id is null or publication.group_id=p_group_id)
      and exists(
        select 1
        from public.now_publication_audiences audience
        where audience.publication_id=publication.id
          and audience.institution_id=p_institution_id
          and audience.unit_id is not distinct from publication.unit_id
          and audience.group_id is not distinct from publication.group_id
          and app_private.now_audience_matches_role(actor_role,audience.audience_kind)
      )
    order by publication.publish_at desc,publication.id
    limit least(greatest(coalesce(p_limit,20),1),50)
  loop
    media_items:='[]'::jsonb;
    for visible_asset in
      select asset.id,asset.kind,asset.mime_type
      from public.now_media_assets asset
      where asset.publication_id=visible_publication.id
        and asset.institution_id=p_institution_id
        and asset.status='ready'
      order by asset.kind
    loop
      insert into app_private.now_media_read_tickets(media_asset_id,viewer_person_id)
      values(visible_asset.id,actor.person_id)
      returning token into read_ticket;
      media_items:=media_items||jsonb_build_array(jsonb_build_object(
        'read_ticket',read_ticket,
        'kind',visible_asset.kind,
        'mime_type',visible_asset.mime_type
      ));
    end loop;

    publication_id:=visible_publication.id;
    author_name:=visible_publication.display_name;
    author_initials:=upper(left(visible_publication.display_name,1));
    context_label:=visible_publication.resolved_context;
    caption:=visible_publication.caption;
    overlay_text:=visible_publication.overlay_text;
    crop_scale:=visible_publication.crop_scale;
    crop_x:=visible_publication.crop_x;
    crop_y:=visible_publication.crop_y;
    cover_position:=visible_publication.cover_position;
    published_at:=visible_publication.resolved_published_at;
    expires_at:=visible_publication.expires_at;
    media:=media_items;
    return next;
  end loop;
end
$$;

create or replace function public.redeem_now_media_read_ticket(
  p_ticket uuid,
  p_viewer_auth_user_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  redeemed record;
begin
  delete from app_private.now_media_read_tickets ticket
  using public.person_auth_links auth_link,
        public.institution_memberships membership,
        public.now_media_assets asset,
        public.now_publications publication
  where ticket.token=p_ticket
    and ticket.expires_at>now()
    and auth_link.person_id=ticket.viewer_person_id
    and auth_link.auth_user_id=p_viewer_auth_user_id
    and auth_link.status='active'
    and membership.person_id=ticket.viewer_person_id
    and membership.institution_id=asset.institution_id
    and membership.status='active'
    and membership.revoked_at is null
    and asset.id=ticket.media_asset_id
    and asset.status='ready'
    and publication.id=asset.publication_id
    and publication.institution_id=asset.institution_id
    and publication.status in('scheduled','published')
    and publication.publish_at<=now()
    and publication.expires_at>now()
    and app_private.now_viewer_has_context(
      ticket.viewer_person_id,
      lower(membership.role_code),
      publication.institution_id,
      publication.unit_id,
      publication.group_id
    )
    and exists(
      select 1
      from public.now_publication_audiences audience
      where audience.publication_id=publication.id
        and audience.institution_id=publication.institution_id
        and audience.unit_id is not distinct from publication.unit_id
        and audience.group_id is not distinct from publication.group_id
        and app_private.now_audience_matches_role(
          lower(membership.role_code),
          audience.audience_kind
        )
    )
  returning asset.bucket_id,asset.object_key,asset.mime_type into redeemed;
  if redeemed.object_key is null then
    raise insufficient_privilege using message='media_read_ticket_invalid';
  end if;
  return jsonb_build_object(
    'bucket_id',redeemed.bucket_id,
    'object_key',redeemed.object_key,
    'mime_type',redeemed.mime_type
  );
end $$;

revoke all on function public.load_now_draft(uuid,uuid,uuid),public.save_now_draft(uuid,jsonb,uuid,bigint),public.prepare_now_asset_upload(uuid,uuid,public.now_asset_kind,text,text,bigint,numeric,boolean),public.finalize_now_asset_upload(uuid,text),public.authorize_now_asset_read(uuid,uuid),public.publish_now(uuid,uuid,bigint,timestamptz),public.list_visible_now_publications(uuid,uuid,uuid,integer),public.redeem_now_media_read_ticket(uuid,uuid) from public,anon,authenticated;
grant execute on function public.load_now_draft(uuid,uuid,uuid),public.save_now_draft(uuid,jsonb,uuid,bigint),public.prepare_now_asset_upload(uuid,uuid,public.now_asset_kind,text,text,bigint,numeric,boolean),public.finalize_now_asset_upload(uuid,text),public.authorize_now_asset_read(uuid,uuid),public.publish_now(uuid,uuid,bigint,timestamptz),public.list_visible_now_publications(uuid,uuid,uuid,integer) to authenticated;
grant execute on function public.redeem_now_media_read_ticket(uuid,uuid) to service_role;
