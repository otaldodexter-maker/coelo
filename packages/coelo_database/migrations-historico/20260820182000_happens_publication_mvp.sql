-- Temporary Supabase-backed Acontece MVP. ADR 0026 requires migration to R2
-- before pilot or production use.
create type public.happens_post_status as enum ('draft','scheduled','published');
create type public.happens_audience_kind as enum ('families','students','school_staff','guardians_only');
create type public.happens_media_status as enum ('pending','ready','quarantined','deleted');

create table public.posts(
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id),
  unit_id uuid references public.units(id),
  group_id uuid references public.groups(id),
  author_person_id uuid not null references public.people(id),
  author_membership_id uuid not null references public.institution_memberships(id),
  caption text not null default '' check(char_length(caption)<=2200),
  status public.happens_post_status not null default 'draft',
  publish_at timestamptz,
  published_at timestamptz,
  management_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(status='draft' or publish_at is not null),
  check(unit_id is not null or group_id is null)
);
create index posts_visible_feed_idx on public.posts(institution_id,publish_at desc,id) where status in('scheduled','published');
create index posts_author_draft_idx on public.posts(author_person_id,updated_at desc) where status='draft';
create index posts_unit_fk_idx on public.posts(unit_id) where unit_id is not null;
create index posts_group_fk_idx on public.posts(group_id) where group_id is not null;
create index posts_membership_fk_idx on public.posts(author_membership_id);

create table public.post_audiences(
  post_id uuid not null references public.posts(id) on delete cascade,
  audience_kind public.happens_audience_kind not null,
  institution_id uuid not null references public.institutions(id),
  unit_id uuid references public.units(id),
  group_id uuid references public.groups(id),
  primary key(post_id,audience_kind)
);
create index post_audiences_scope_idx on public.post_audiences(institution_id,unit_id,group_id);

create table public.media_assets(
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id),
  post_id uuid not null references public.posts(id) on delete cascade,
  owner_person_id uuid not null references public.people(id),
  upload_request_id text not null check(char_length(upload_request_id) between 1 and 240),
  storage_provider text not null default 'supabase_mvp' check(storage_provider in('supabase_mvp','r2')),
  bucket_id text not null default 'coelo-happens-mvp',
  object_key text not null unique,
  original_name text not null,
  mime_type text not null check(mime_type in('image/jpeg','image/png','image/webp','video/mp4')),
  byte_size bigint not null check(byte_size>0),
  checksum_sha256 text,
  status public.happens_media_status not null default 'pending',
  created_at timestamptz not null default now(),
  finalized_at timestamptz,
  unique(post_id,upload_request_id)
);
create index media_assets_owner_idx on public.media_assets(institution_id,owner_person_id,status);

create table public.media_links(
  post_id uuid not null references public.posts(id) on delete cascade,
  media_asset_id uuid not null references public.media_assets(id) on delete restrict,
  display_order smallint not null check(display_order between 0 and 5),
  primary key(post_id,media_asset_id),
  unique(post_id,display_order)
);
create index media_links_asset_fk_idx on public.media_links(media_asset_id);

create table app_private.happens_publication_audit(
  id bigint generated always as identity primary key,
  post_id uuid,
  institution_id uuid not null,
  actor_person_id uuid not null,
  event_code text not null,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index happens_publication_audit_post_idx on app_private.happens_publication_audit(post_id,created_at desc);

create table app_private.happens_media_read_tickets(
  token uuid primary key default gen_random_uuid(),
  media_asset_id uuid not null references public.media_assets(id) on delete cascade,
  viewer_person_id uuid not null references public.people(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '2 minutes'),
  created_at timestamptz not null default now()
);
create index happens_media_read_tickets_expiry_idx
  on app_private.happens_media_read_tickets(expires_at);
revoke all on app_private.happens_media_read_tickets from public,anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('coelo-happens-mvp','coelo-happens-mvp',false,10485760,array['image/jpeg','image/png','image/webp','video/mp4'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

alter table public.posts enable row level security; alter table public.posts force row level security;
alter table public.post_audiences enable row level security; alter table public.post_audiences force row level security;
alter table public.media_assets enable row level security; alter table public.media_assets force row level security;
alter table public.media_links enable row level security; alter table public.media_links force row level security;
revoke all on public.posts,public.post_audiences,public.media_assets,public.media_links from anon,authenticated;

insert into public.institution_permissions(
  code,module_code,screen_code,action_code,description,status,
  module_label,screen_label,action_label
)
values
 ('happens.posts.create','happens','posts','create','Criar e manter rascunhos no contexto autorizado.','active','Acontece','Publicações','Criar'),
 ('happens.posts.publish','happens','posts','publish','Publicar ou agendar no contexto autorizado.','active','Acontece','Publicações','Publicar'),
 ('happens.posts.read','happens','posts','read','Ler o feed privado no contexto autorizado.','active','Acontece','Publicações','Ler')
on conflict(code) do update set
  module_code=excluded.module_code,
  screen_code=excluded.screen_code,
  action_code=excluded.action_code,
  description=excluded.description,
  status='active',
  module_label=excluded.module_label,
  screen_label=excluded.screen_label,
  action_label=excluded.action_label;

create or replace function app_private.happens_actor(p_institution_id uuid,p_permission text,p_unit_id uuid,p_group_id uuid)
returns table(person_id uuid,membership_id uuid) language plpgsql stable security definer set search_path='' as $$
begin
  if (select auth.uid()) is null then raise insufficient_privilege using message='authentication_required'; end if;
  if not app_private.has_institution_permission(p_institution_id,p_permission,p_unit_id,p_group_id,false)
  then raise insufficient_privilege using message='happens_permission_denied'; end if;
  return query select link.person_id,membership.id
  from public.person_auth_links link join public.institution_memberships membership on membership.person_id=link.person_id
  where link.auth_user_id=(select auth.uid()) and link.status='active' and membership.institution_id=p_institution_id
    and membership.status='active' and membership.revoked_at is null order by membership.created_at limit 1;
  if not found then raise insufficient_privilege using message='active_membership_required'; end if;
end $$;
revoke all on function app_private.happens_actor(uuid,text,uuid,uuid) from public,anon,authenticated;

create or replace function app_private.happens_audience_matches_role(
  p_role_code text,
  p_audience public.happens_audience_kind
)
returns boolean language sql immutable set search_path='' as $$
  select case
    when lower(coalesce(p_role_code,'')) in ('guardian','responsible','responsavel','parent','family')
      then p_audience in ('families','guardians_only')
    when lower(coalesce(p_role_code,'')) in ('student','aluno')
      then p_audience='students'
    else p_audience='school_staff'
  end
$$;
revoke all on function app_private.happens_audience_matches_role(text,public.happens_audience_kind)
  from public,anon,authenticated;

create or replace function public.load_happens_draft(p_institution_id uuid,p_unit_id uuid,p_group_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor record; target public.posts%rowtype;
begin
  select * into actor from app_private.happens_actor(p_institution_id,'happens.posts.create',p_unit_id,p_group_id);
  select * into target from public.posts where institution_id=p_institution_id and author_person_id=actor.person_id
    and status='draft' and unit_id is not distinct from p_unit_id and group_id is not distinct from p_group_id
    order by updated_at desc limit 1;
  if target.id is null then return null; end if;
  return jsonb_build_object('id',target.id,'caption',target.caption,'version',target.management_version,'publish_at',target.publish_at,
    'audiences',(select coalesce(jsonb_agg(audience_kind order by audience_kind),'[]') from public.post_audiences where post_id=target.id),
    'media',(select coalesce(jsonb_agg(jsonb_build_object('asset_id',asset.id,'name',asset.original_name,'mime_type',asset.mime_type,'object_key',asset.object_key) order by link.display_order),'[]') from public.media_links link join public.media_assets asset on asset.id=link.media_asset_id where link.post_id=target.id and asset.status='ready'));
end $$;

create or replace function public.save_happens_draft(p_request_id uuid,p_draft jsonb,p_post_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor record;target public.posts%rowtype;institution uuid:=(p_draft->>'institution_id')::uuid;unit uuid:=nullif(p_draft->>'unit_id','')::uuid;grp uuid:=nullif(p_draft->>'group_id','')::uuid;kind text;
begin
  if unit is not null and not exists(select 1 from public.units scoped_unit where scoped_unit.id=unit and scoped_unit.institution_id=institution) then raise insufficient_privilege using message='unit_scope_invalid';end if;
  if grp is not null and not exists(select 1 from public.groups scoped_group where scoped_group.id=grp and scoped_group.institution_id=institution and scoped_group.unit_id=unit) then raise insufficient_privilege using message='group_scope_invalid';end if;
  select * into actor from app_private.happens_actor(institution,'happens.posts.create',unit,grp);
  if char_length(coalesce(p_draft->>'caption',''))>2200 then raise check_violation using message='caption_too_long';end if;
  if p_post_id is null then
    insert into public.posts(institution_id,unit_id,group_id,author_person_id,author_membership_id,caption,publish_at)
    values(institution,unit,grp,actor.person_id,actor.membership_id,coalesce(p_draft->>'caption',''),nullif(p_draft->>'publish_at','')::timestamptz) returning * into target;
  else
    update public.posts set caption=coalesce(p_draft->>'caption',''),publish_at=nullif(p_draft->>'publish_at','')::timestamptz,
      management_version=management_version+1,updated_at=now()
    where id=p_post_id and institution_id=institution and author_person_id=actor.person_id and status='draft' and management_version=p_expected_version returning * into target;
    if target.id is null then raise serialization_failure using message='expected_version_conflict';end if;
  end if;
  delete from public.post_audiences where post_id=target.id;
  for kind in select jsonb_array_elements_text(coalesce(p_draft->'audiences','[]')) loop
    insert into public.post_audiences(post_id,audience_kind,institution_id,unit_id,group_id) values(target.id,kind::public.happens_audience_kind,institution,unit,grp);
  end loop;
  insert into app_private.happens_publication_audit(post_id,institution_id,actor_person_id,event_code,detail) values(target.id,institution,actor.person_id,'draft_saved',jsonb_build_object('request_id',p_request_id,'version',target.management_version));
  return jsonb_build_object('id',target.id,'version',target.management_version);
end $$;

create or replace function public.prepare_happens_media_upload(p_request_id text,p_institution_id uuid,p_post_id uuid,p_name text,p_mime_type text,p_byte_size bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor record;asset public.media_assets%rowtype;target public.posts%rowtype;key text;
begin
  select * into target from public.posts where id=p_post_id and institution_id=p_institution_id and status='draft';
  if target.id is null then raise insufficient_privilege using message='post_not_authorized';end if;
  select * into actor from app_private.happens_actor(p_institution_id,'happens.posts.create',target.unit_id,target.group_id);
  if target.author_person_id<>actor.person_id then raise insufficient_privilege using message='post_not_authorized';end if;
  if p_mime_type not in('image/jpeg','image/png','image/webp','video/mp4') then raise check_violation using message='unsupported_media_type';end if;
  select * into asset from public.media_assets where post_id=p_post_id and upload_request_id=p_request_id;
  if asset.id is not null then
    if asset.owner_person_id<>actor.person_id or asset.mime_type<>p_mime_type or asset.byte_size<>p_byte_size then raise insufficient_privilege using message='upload_request_conflict';end if;
    return jsonb_build_object('asset_id',asset.id,'bucket_id',asset.bucket_id,'object_key',asset.object_key);
  end if;
  key:=p_institution_id::text||'/'||p_post_id::text||'/'||gen_random_uuid()::text;
  insert into public.media_assets(institution_id,post_id,owner_person_id,upload_request_id,object_key,original_name,mime_type,byte_size) values(p_institution_id,p_post_id,actor.person_id,p_request_id,key,p_name,p_mime_type,p_byte_size) returning * into asset;
  return jsonb_build_object('asset_id',asset.id,'bucket_id',asset.bucket_id,'object_key',asset.object_key);
end $$;

create or replace function public.finalize_happens_media_upload(p_asset_id uuid,p_post_id uuid,p_checksum_sha256 text,p_display_order bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare asset public.media_assets%rowtype;actor record;target public.posts%rowtype;
begin
  select * into asset from public.media_assets where id=p_asset_id for update;
  if asset.id is null then raise insufficient_privilege using message='asset_not_authorized';end if;
  select * into target from public.posts where id=p_post_id and institution_id=asset.institution_id and status='draft';
  if target.id is null then raise insufficient_privilege using message='media_not_uploaded';end if;
  select * into actor from app_private.happens_actor(asset.institution_id,'happens.posts.create',target.unit_id,target.group_id);
  if asset.owner_person_id<>actor.person_id or target.author_person_id<>actor.person_id or not exists(select 1 from storage.objects where bucket_id=asset.bucket_id and name=asset.object_key) then raise insufficient_privilege using message='media_not_uploaded';end if;
  update public.media_assets set checksum_sha256=p_checksum_sha256,status='ready',finalized_at=now() where id=p_asset_id;
  insert into public.media_links(post_id,media_asset_id,display_order) values(p_post_id,p_asset_id,p_display_order::smallint);
  return jsonb_build_object('asset_id',p_asset_id,'object_key',asset.object_key);
end $$;

create or replace function public.remove_happens_media(p_asset_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare asset public.media_assets%rowtype;actor record;
begin
  select * into asset from public.media_assets where id=p_asset_id for update;
  if asset.id is null then raise insufficient_privilege using message='asset_not_authorized';end if;
  select * into actor from app_private.happens_actor(asset.institution_id,'happens.posts.create',null,null);
  if asset.owner_person_id<>actor.person_id then raise insufficient_privilege using message='asset_not_authorized';end if;
  if exists(
    select 1 from public.media_links link
    join public.posts post on post.id=link.post_id
    where link.media_asset_id=asset.id and post.status<>'draft'
  ) then raise check_violation using message='published_media_immutable';end if;
  delete from public.media_links link using public.posts post where link.media_asset_id=asset.id and post.id=link.post_id and post.status='draft' and post.author_person_id=actor.person_id;
  update public.media_assets set status='deleted' where id=asset.id;
  insert into app_private.happens_publication_audit(post_id,institution_id,actor_person_id,event_code,detail) values(null,asset.institution_id,actor.person_id,'media_removed',jsonb_build_object('asset_id',asset.id,'object_key',asset.object_key));
  return jsonb_build_object('bucket_id',asset.bucket_id,'object_key',asset.object_key);
end $$;

create or replace function public.publish_happens_post(p_request_id uuid,p_post_id uuid,p_expected_version bigint,p_publish_at timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target public.posts%rowtype;actor record;at timestamptz:=coalesce(p_publish_at,now());next_status public.happens_post_status;
begin
  select * into target from public.posts where id=p_post_id for update;
  select * into actor from app_private.happens_actor(target.institution_id,'happens.posts.publish',target.unit_id,target.group_id);
  if target.author_person_id<>actor.person_id or target.management_version<>p_expected_version then raise serialization_failure using message='expected_version_conflict';end if;
  if not exists(select 1 from public.post_audiences where post_id=target.id) then raise check_violation using message='audience_required';end if;
  if target.caption='' and not exists(select 1 from public.media_links where post_id=target.id) then raise check_violation using message='content_required';end if;
  next_status:=case when at>now() then 'scheduled'::public.happens_post_status else 'published'::public.happens_post_status end;
  update public.posts set status=next_status,publish_at=at,published_at=case when next_status='published' then now() end,management_version=management_version+1,updated_at=now() where id=target.id returning * into target;
  insert into app_private.happens_publication_audit(post_id,institution_id,actor_person_id,event_code,detail) values(target.id,target.institution_id,actor.person_id,case when next_status='scheduled' then 'post_scheduled' else 'post_published' end,jsonb_build_object('request_id',p_request_id,'publish_at',at));
  return jsonb_build_object('id',target.id,'status',target.status,'publish_at',target.publish_at);
end $$;

create or replace function public.list_visible_happens_posts(p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_limit integer default 20)
returns table(
  author_name text,
  author_initials text,
  context_label text,
  caption text,
  published_at timestamptz,
  media jsonb
) language plpgsql security definer set search_path='' as $$
declare
  actor record;
  actor_role text;
  visible_post record;
  visible_media record;
  media_items jsonb;
  read_ticket uuid;
begin
  select * into actor from app_private.happens_actor(p_institution_id,'happens.posts.read',p_unit_id,p_group_id);
  select lower(membership.role_code) into actor_role
  from public.institution_memberships membership
  where membership.id=actor.membership_id;

  delete from app_private.happens_media_read_tickets ticket
  where ticket.expires_at<=now();

  for visible_post in
    select
      post.id,
      person.display_name,
      coalesce(scoped_group.name,scoped_unit.name,institution.public_name) as resolved_context,
      post.caption,
      coalesce(post.published_at,post.publish_at) as resolved_published_at
    from public.posts post
    join public.people person on person.id=post.author_person_id
    join public.institutions institution on institution.id=post.institution_id
    left join public.units scoped_unit on scoped_unit.id=post.unit_id
    left join public.groups scoped_group on scoped_group.id=post.group_id
    where post.institution_id=p_institution_id
      and post.status in('scheduled','published')
      and post.publish_at<=now()
      and (post.unit_id is null or post.unit_id=p_unit_id)
      and (post.group_id is null or post.group_id=p_group_id)
      and exists(
        select 1
        from public.post_audiences audience
        where audience.post_id=post.id
          and audience.institution_id=p_institution_id
          and audience.unit_id is not distinct from post.unit_id
          and audience.group_id is not distinct from post.group_id
          and app_private.happens_audience_matches_role(actor_role,audience.audience_kind)
      )
    order by post.publish_at desc,post.id
    limit least(greatest(coalesce(p_limit,20),1),50)
  loop
    media_items:='[]'::jsonb;
    for visible_media in
      select asset.id,asset.mime_type,link.display_order
      from public.media_links link
      join public.media_assets asset on asset.id=link.media_asset_id
      where link.post_id=visible_post.id and asset.status='ready'
      order by link.display_order
    loop
      insert into app_private.happens_media_read_tickets(media_asset_id,viewer_person_id)
      values(visible_media.id,actor.person_id)
      returning token into read_ticket;
      media_items:=media_items||jsonb_build_array(jsonb_build_object(
        'read_ticket',read_ticket,
        'mime_type',visible_media.mime_type,
        'display_order',visible_media.display_order
      ));
    end loop;

    author_name:=visible_post.display_name;
    author_initials:=upper(left(visible_post.display_name,1));
    context_label:=visible_post.resolved_context;
    caption:=visible_post.caption;
    published_at:=visible_post.resolved_published_at;
    media:=media_items;
    return next;
  end loop;
end
$$;

create or replace function public.redeem_happens_media_read_ticket(
  p_ticket uuid,
  p_viewer_auth_user_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  redeemed record;
begin
  delete from app_private.happens_media_read_tickets ticket
  using public.person_auth_links auth_link,public.media_assets asset
  where ticket.token=p_ticket
    and ticket.expires_at>now()
    and auth_link.person_id=ticket.viewer_person_id
    and auth_link.auth_user_id=p_viewer_auth_user_id
    and auth_link.status='active'
    and asset.id=ticket.media_asset_id
    and asset.status='ready'
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

revoke all on function public.load_happens_draft(uuid,uuid,uuid),public.save_happens_draft(uuid,jsonb,uuid,bigint),public.prepare_happens_media_upload(text,uuid,uuid,text,text,bigint),public.finalize_happens_media_upload(uuid,uuid,text,bigint),public.remove_happens_media(uuid),public.publish_happens_post(uuid,uuid,bigint,timestamptz),public.list_visible_happens_posts(uuid,uuid,uuid,integer),public.redeem_happens_media_read_ticket(uuid,uuid) from public,anon,authenticated;
grant execute on function public.load_happens_draft(uuid,uuid,uuid),public.save_happens_draft(uuid,jsonb,uuid,bigint),public.prepare_happens_media_upload(text,uuid,uuid,text,text,bigint),public.finalize_happens_media_upload(uuid,uuid,text,bigint),public.remove_happens_media(uuid),public.publish_happens_post(uuid,uuid,bigint,timestamptz),public.list_visible_happens_posts(uuid,uuid,uuid,integer) to authenticated;
grant execute on function public.redeem_happens_media_read_ticket(uuid,uuid) to service_role;
