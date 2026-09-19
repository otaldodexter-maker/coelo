-- Lote 88 — expiração dos rascunhos de entity_image_assets direto no Postgres.
-- No desenho da entity-media o objeto só vai ao R2 imediatamente antes do finalize (e é apagado se o
-- finalize falhar), então um rascunho expirado nunca tem objeto órfão: o pg_cron chama a função local
-- e não precisa de Edge, Vault nem segredo (o dispatch do lote 87 sai).
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create or replace function app_private.entity_image_expire_drafts_v1(p_limit integer default 200)
returns integer language plpgsql volatile security definer set search_path = '' as $$
declare expired_count integer;
begin
  with candidates as (
    select id from public.entity_image_assets
    where status = 'draft' and expires_at < now()
    order by expires_at limit greatest(1, least(coalesce(p_limit, 200), 1000))
    for update skip locked
  ), expired as (
    update public.entity_image_assets a set status = 'inactive', revoked_at = now()
    from candidates c where a.id = c.id
    returning a.id
  )
  select count(*) into expired_count from expired;
  return expired_count;
end
$$;
alter function app_private.entity_image_expire_drafts_v1(integer) owner to postgres;
revoke all on function app_private.entity_image_expire_drafts_v1(integer) from public, anon, authenticated, service_role;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'coelo-entity-media-expire') then
    perform cron.unschedule('coelo-entity-media-expire');
  end if;
  perform cron.schedule('coelo-entity-media-expire', '*/10 * * * *',
    'select app_private.entity_image_expire_drafts_v1(200);');
end
$$;

drop function if exists app_private.entity_media_dispatch_expire_worker();
commit;
