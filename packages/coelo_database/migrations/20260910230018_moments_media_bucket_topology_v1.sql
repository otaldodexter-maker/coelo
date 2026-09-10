-- Momentos: alinha o bucket padrao dos ativos de midia a topologia da ADR 0032.
--
-- A fundacao 20260821112822 (recarimbada 20260910230017 ao entrar em producao)
-- nasceu com bucket_id default 'coelo-moments-private', bucket que nunca existiu
-- na conta Cloudflare. A topologia aprovada tem tres buckets privados; imagens
-- e masters de video de Momentos ficam em 'coelo-media-prod'. Forward-only:
-- so o default e a guarda mudam; nenhuma linha existe ainda em producao.
begin;

alter table public.moments_media_assets
  alter column bucket_id set default 'coelo-media-prod';

alter table public.moments_media_assets
  add constraint moments_media_assets_bucket_topology_check
  check (bucket_id = 'coelo-media-prod') not valid;

alter table public.moments_media_assets
  validate constraint moments_media_assets_bucket_topology_check;

commit;
