-- E2 R02 L02 - Avisos: metricas restritas a geracao de publicacao corrente.
--
-- A spec de Avisos exige que cada geracao de audiencia pertenca ao
-- publication_job_id mais a versao congelada, e que republicar preserve o
-- historico "sem misturar destinatarios/metricas". Hoje
-- app_private.superadmin_notice_json conta public.notice_receipts filtrando
-- apenas por notice_id, entao republicar soma recibos de geracoes diferentes no
-- mesmo numero.
--
-- O esquema ja tem tudo o que falta usar: 20260820220500 acrescentou
-- notice_receipts.publication_job_id e notice_version, e
-- platform_notices.current_publication_job_id.
--
-- ESCOPO DELIBERADAMENTE ESTREITO. Esta migration NAO altera a semantica de
-- publicacao. `superadmin_notice_publish_v2` continua nao enfileirando job e
-- continua decidindo scheduled/active como antes. Aquela mudanca e acoplada ao
-- worker (`app_private.run_notice_publication_job` exige status='scheduled' e e
-- ele quem promove a active), e fazer a ativacao depender de um worker cuja
-- execucao no destino nao foi confirmada transformaria "publica na hora" em
-- "nunca publica". Ver propostas/L02-notices-publish-materializacao.md.
--
-- SEM REGRESSAO POR CONSTRUCAO: quando current_publication_job_id e nulo -- que
-- e o estado de todo aviso hoje, ja que nada cria job -- a contagem cai no
-- comportamento atual, sobre todos os recibos do aviso. O escopo por geracao so
-- passa a valer quando existir geracao, e ai ele e a leitura correta.
--
-- Forward-only. Substitui uma unica funcao; nao toca tabela, policy ou grant.

begin;

do $$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='notice metrics migration must run as postgres';
  end if;
  if to_regprocedure('app_private.superadmin_notice_json(public.platform_notices)') is null then
    raise exception using errcode='55000',
      message='superadmin notices v2 baseline is unavailable';
  end if;
  if not exists(
    select 1 from pg_catalog.pg_attribute
    where attrelid='public.notice_receipts'::regclass
      and attname='publication_job_id' and not attisdropped
  ) then
    raise exception using errcode='55000',
      message='notice receipts are not versioned by publication job';
  end if;
  if not exists(
    select 1 from pg_catalog.pg_attribute
    where attrelid='public.platform_notices'::regclass
      and attname='current_publication_job_id' and not attisdropped
  ) then
    raise exception using errcode='55000',
      message='platform notices do not track the current publication job';
  end if;
end
$$;

create or replace function app_private.superadmin_notice_json(
  p_notice public.platform_notices
) returns jsonb language sql stable security definer set search_path = '' as $$
  select pg_catalog.jsonb_build_object(
    'id', p_notice.id,
    'type', p_notice.notice_type::text,
    'title', p_notice.title,
    'body', p_notice.body_text,
    'priority', p_notice.priority_code,
    'status', case p_notice.status::text
      when 'published' then 'active' when 'archived' then 'inactive'
      else p_notice.status::text end,
    'starts_at', p_notice.starts_at,
    'ends_at', p_notice.ends_at,
    'audience', p_notice.audience_json,
    'audience_label', p_notice.audience_label,
    'behavior', p_notice.behavior,
    'target_device', p_notice.target_device,
    'content_format', p_notice.content_format,
    'background_color', p_notice.background_color,
    'text_color', p_notice.text_color,
    'button_color', p_notice.button_color,
    'popup_size', p_notice.popup_size,
    'has_outer_inset', p_notice.has_outer_inset,
    'button_label', p_notice.cta_label,
    'link_label', p_notice.silencing_policy ->> 'link_label',
    'recurrence', p_notice.recurrence,
    'interval_days', p_notice.recurrence_config -> 'interval_days',
    'weekly_days', coalesce(p_notice.recurrence_config -> 'weekly_days', '[]'::jsonb),
    'day_of_month', p_notice.recurrence_config -> 'day_of_month',
    'recurrence_until', p_notice.recurrence_config ->> 'until',
    'image_orientation', p_notice.image_orientation,
    'management_version', p_notice.management_version,
    'updated_at', p_notice.updated_at,
    -- A geracao corrente e a autoridade quando existe. Sem geracao, a contagem
    -- permanece a de antes, para nao zerar metricas de avisos ja publicados.
    'publication_generation_id', p_notice.current_publication_job_id,
    'reach', (select count(*) from public.notice_receipts receipt
      where receipt.notice_id = p_notice.id
        and (p_notice.current_publication_job_id is null
          or receipt.publication_job_id = p_notice.current_publication_job_id)),
    'delivered_count', (select count(*) from public.notice_receipts receipt
      where receipt.notice_id = p_notice.id and receipt.delivered_at is not null
        and (p_notice.current_publication_job_id is null
          or receipt.publication_job_id = p_notice.current_publication_job_id)),
    'viewed_count', (select count(*) from public.notice_receipts receipt
      where receipt.notice_id = p_notice.id and receipt.opened_at is not null
        and (p_notice.current_publication_job_id is null
          or receipt.publication_job_id = p_notice.current_publication_job_id)),
    'accepted_count', (select count(*) from public.notice_receipts receipt
      where receipt.notice_id = p_notice.id and receipt.acted_at is not null
        and (p_notice.current_publication_job_id is null
          or receipt.publication_job_id = p_notice.current_publication_job_id)))
$$;

do $$declare p regprocedure; begin
  p := 'app_private.superadmin_notice_json(public.platform_notices)'::regprocedure;
  execute format('alter function %s owner to postgres', p);
  execute format('revoke all on function %s from public,anon,authenticated,service_role', p);
end $$;

commit;
