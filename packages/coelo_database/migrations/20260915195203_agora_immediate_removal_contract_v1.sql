-- R14 Bloco E / ADR 0040 / action_id agora.remove.
-- Remocao imediata e logica de uma publicacao do Agora. O catalogo e a
-- auditoria permanecem; tickets sao invalidados na mesma transacao e o
-- objeto fisico e apagado por now-media usando uma fila privada server-only.
-- Nenhuma URL, credencial ou objeto privado atravessa esta migration.

alter table public.now_publications
  drop constraint now_publications_check2,
  add column removed_at timestamptz,
  add column removed_by_person_id uuid references public.people(id),
  add column removal_reason text,
  add constraint now_publications_check2 check (
    expires_at is null or status in ('scheduled','published','expired','removed')
  ),
  add constraint now_publications_removal_shape_ck check (
    (status='removed' and removed_at is not null and removed_by_person_id is not null)
    or status<>'removed'
  ),
  add constraint now_publications_removal_reason_ck check (
    removal_reason is null or char_length(removal_reason)<=280
  );

create index now_publications_removed_idx
  on public.now_publications(institution_id,removed_at desc)
  where status='removed';

insert into public.institution_permissions(
  code,module_code,screen_code,action_code,description,risk_level,
  requires_mfa,status,module_label,screen_label,action_label
)
values (
  'now.publications.remove','now','publications','remove',
  'Remover imediatamente uma publicacao do Agora no contexto autorizado.',
  'critical',false,'active','Agora','Publicacoes','Remover'
)
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

create table app_private.now_media_purge_jobs(
  id bigint generated always as identity primary key,
  request_id uuid not null,
  publication_id uuid not null references public.now_publications(id),
  media_asset_id uuid not null references public.now_media_assets(id),
  institution_id uuid not null references public.institutions(id),
  storage_provider text not null check(storage_provider in('r2','supabase_mvp')),
  bucket_id text not null,
  object_key text not null,
  status text not null default 'pending' check(status in('pending','processing','purged','error')),
  attempts integer not null default 0 check(attempts>=0 and attempts<=20),
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  locked_by text,
  last_error text,
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(publication_id,media_asset_id)
);
create index now_media_purge_jobs_claim_idx
  on app_private.now_media_purge_jobs(status,available_at,requested_at)
  where status in('pending','error');
alter table app_private.now_media_purge_jobs enable row level security;
alter table app_private.now_media_purge_jobs force row level security;
revoke all on table app_private.now_media_purge_jobs from public,anon,authenticated,service_role;

create or replace function public.remove_now_publication(
  p_request_id uuid,
  p_publication_id uuid,
  p_expected_version bigint,
  p_reason text
)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  target public.now_publications%rowtype;
  asset public.now_media_assets%rowtype;
  actor record;
  cached jsonb;
  normalized_reason text;
  purge_jobs integer:=0;
  purge_status text;
  result jsonb;
begin
  if p_request_id is null or p_publication_id is null then
    raise invalid_parameter_value using message='invalid_request';
  end if;
  select * into target from public.now_publications where id=p_publication_id for update;
  if not found then
    raise insufficient_privilege using message='now_remove_denied';
  end if;
  -- A autorizacao ocorre antes de qualquer resposta dependente do recurso.
  -- O ator deve ter a capacidade no mesmo tenant/contexto; a politica permite
  -- autor ou papel institucional explicitamente autorizado.
  select * into actor from app_private.now_actor(
    target.institution_id,'now.publications.remove',target.unit_id,target.group_id);
  select response into cached from app_private.now_publication_audit
    where actor_person_id=actor.person_id and event_code='publication_removed'
      and request_id=p_request_id;
  if cached is not null then return cached; end if;
  if p_expected_version is null or target.management_version is distinct from p_expected_version then
    raise serialization_failure using message='expected_version_conflict';
  end if;
  if target.status not in ('scheduled','published') then
    raise check_violation using message='publication_not_removable';
  end if;
  normalized_reason:=nullif(btrim(coalesce(p_reason,'')),'');
  if normalized_reason is not null and char_length(normalized_reason)>280 then
    raise check_violation using message='reason_too_long';
  end if;
  update public.now_publications
  set status='removed',removed_at=now(),removed_by_person_id=actor.person_id,
      removal_reason=normalized_reason,management_version=management_version+1,updated_at=now()
  where id=target.id returning * into target;

  -- Negacao logica imediata, inclusive para tickets ja emitidos. O catalogo
  -- de assets nao e apagado para preservar ownership e auditoria.
  delete from app_private.now_media_read_tickets
    where media_asset_id in (select id from public.now_media_assets where publication_id=target.id);
  for asset in
    select * from public.now_media_assets where publication_id=target.id and status<>'deleted' for update
  loop
    update public.now_media_assets set status='deleted' where id=asset.id;
    if asset.storage_provider in ('r2','supabase_mvp') then
      insert into app_private.now_media_purge_jobs(
        request_id,publication_id,media_asset_id,institution_id,storage_provider,bucket_id,object_key)
      values(p_request_id,target.id,asset.id,target.institution_id,asset.storage_provider,asset.bucket_id,asset.object_key)
      on conflict(publication_id,media_asset_id) do nothing;
      purge_jobs:=purge_jobs+1;
    end if;
  end loop;
  purge_status:=case when purge_jobs=0 then 'not_applicable' else 'queued' end;
  result:=jsonb_build_object(
    'id',target.id,'status',target.status,'removed_at',target.removed_at,
    'management_version',target.management_version,'purge_status',purge_status,
    'purge_job_count',purge_jobs);
  insert into app_private.now_publication_audit(
    publication_id,institution_id,actor_person_id,event_code,request_id,response,detail)
  values(target.id,target.institution_id,actor.person_id,'publication_removed',p_request_id,result,
    jsonb_build_object('action_id','agora.remove','outcome','success','request_id',p_request_id,
      'previous_version',p_expected_version,'management_version',target.management_version,
      'removal_reason',normalized_reason,'purge_status',purge_status,
      'purge_job_count',purge_jobs,'stream_status','not_applicable'));
  return result;
end $$;

-- O gateway chama estes wrappers com service_role. Eles nunca sao
-- executaveis por anon/authenticated e devolvem descritores privados apenas
-- dentro do limite server-side da Edge Function.
create function public.claim_now_media_purge_jobs(p_worker text,p_limit integer default 20)
returns table(job_id bigint,publication_id uuid,media_asset_id uuid,storage_provider text,bucket_id text,object_key text)
language plpgsql volatile security definer set search_path='' as $$
begin
  if auth.role() is distinct from 'service_role'
    or length(trim(coalesce(p_worker,''))) not between 1 and 120
    or p_limit not between 1 and 100 then
    raise insufficient_privilege using message='not_authorized';
  end if;
  update app_private.now_media_purge_jobs
  set status='error',available_at=now(),locked_at=null,locked_by=null,last_error='lease_expired'
  where status='processing' and locked_at<now()-interval '5 minutes' and attempts<20;
  return query
  with candidates as (
    select id from app_private.now_media_purge_jobs
    where status in('pending','error') and available_at<=now() and attempts<20
    order by available_at,requested_at,id for update skip locked limit p_limit
  ), claimed as (
    update app_private.now_media_purge_jobs job
    set status='processing',attempts=job.attempts+1,locked_at=now(),locked_by=trim(p_worker),last_error=null
    from candidates where job.id=candidates.id returning job.*
  )
  select claimed.id,claimed.publication_id,claimed.media_asset_id,claimed.storage_provider,
    claimed.bucket_id,claimed.object_key from claimed;
end $$;

create function public.record_now_media_purge_result(p_job_id bigint,p_success boolean,p_error text default null)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare job app_private.now_media_purge_jobs%rowtype; safe_error text;
begin
  if auth.role() is distinct from 'service_role' or p_job_id is null then
    raise insufficient_privilege using message='not_authorized';
  end if;
  select * into job from app_private.now_media_purge_jobs where id=p_job_id for update;
  if not found then raise undefined_object using message='purge_job_not_found'; end if;
  safe_error:=nullif(left(btrim(coalesce(p_error,'')),160),'');
  if p_success then
    update app_private.now_media_purge_jobs
    set status='purged',completed_at=now(),locked_at=null,locked_by=null,last_error=null where id=job.id;
  else
    update app_private.now_media_purge_jobs
    set status='error',available_at=now()+interval '1 minute',locked_at=null,locked_by=null,last_error=safe_error
    where id=job.id;
  end if;
  update app_private.now_publication_audit audit
  set detail=audit.detail || jsonb_build_object('purge_results',
    coalesce(audit.detail->'purge_results','{}'::jsonb) || jsonb_build_object(job.id::text,
      jsonb_build_object('status',case when p_success then 'purged' else 'error' end,'error',safe_error)))
  where audit.publication_id=job.publication_id and audit.event_code='publication_removed'
    and audit.request_id=job.request_id;
  return jsonb_build_object('job_id',job.id,'status',case when p_success then 'purged' else 'error' end);
end $$;

alter function public.remove_now_publication(uuid,uuid,bigint,text) owner to postgres;
alter function public.claim_now_media_purge_jobs(text,integer) owner to postgres;
alter function public.record_now_media_purge_result(bigint,boolean,text) owner to postgres;
revoke all on function public.remove_now_publication(uuid,uuid,bigint,text) from public,anon,authenticated,service_role;
revoke all on function public.claim_now_media_purge_jobs(text,integer) from public,anon,authenticated,service_role;
revoke all on function public.record_now_media_purge_result(bigint,boolean,text) from public,anon,authenticated,service_role;
grant execute on function public.remove_now_publication(uuid,uuid,bigint,text) to authenticated;
grant execute on function public.claim_now_media_purge_jobs(text,integer) to service_role;
grant execute on function public.record_now_media_purge_result(bigint,boolean,text) to service_role;
