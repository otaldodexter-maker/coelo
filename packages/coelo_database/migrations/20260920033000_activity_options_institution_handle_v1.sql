-- Lote 101 (CODE-REVIEW r4, 20/09/2026): activity_options_institution_handle_v1
--
-- As opcoes de instituicao do formulario de atividades (superadmin_activity_template_options
-- e superadmin_activity_filter_options_v2) passam a trazer `handle` (institutions.slug, o @ da
-- instituicao) para a previa do @ da atividade bater com o que o lote 100 gera
-- (stem.@dainstituicao). Nenhuma assinatura muda. Reversao: recriar sem a chave.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if to_regprocedure('app_private.superadmin_activity_template_options(uuid)') is null
    or to_regprocedure('public.superadmin_activity_filter_options_v2()') is null then
    raise object_not_in_prerequisite_state using message = 'activity options RPCs are required';
  end if;
end
$preflight$;

CREATE OR REPLACE FUNCTION app_private.superadmin_activity_template_options(p_institution_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  ctx app_private.superadmin_internal_context;
  effective_institution_id uuid;
  result jsonb;
begin
  select * into strict ctx
  from app_private.require_superadmin_internal_context('activities.read');
  if p_institution_id is not null and not exists(
    select 1 from public.institutions institution
    where institution.id=p_institution_id
  ) then
    raise no_data_found using message='institution not found';
  end if;
  if p_institution_id is not null
     and ctx.scope_kind='institution'
     and ctx.scope_institution_id is distinct from p_institution_id then
    raise insufficient_privilege using message='institution scope denied',detail='SAI_PERMISSION_DENIED';
  end if;
  effective_institution_id:=coalesce(
    p_institution_id,
    case when ctx.scope_kind='institution' then ctx.scope_institution_id end
  );
  select jsonb_build_object(
    'institutions',coalesce((select jsonb_agg(jsonb_build_object(
      'id',institution.id,'name',institution.public_name,'handle',lower(institution.slug)) order by institution.public_name)
      from public.institutions institution
      where effective_institution_id is null
         or institution.id=effective_institution_id),'[]'::jsonb),
    'units',coalesce((select jsonb_agg(jsonb_build_object(
      'id',unit.id,'institution_id',unit.institution_id,'name',unit.name) order by unit.name)
      from public.units unit
      where unit.status<>'archived'
       and (effective_institution_id is null
        or unit.institution_id=effective_institution_id)),'[]'::jsonb),
    'taxonomy',coalesce((select jsonb_agg(jsonb_build_object(
      'id',category.id,'label',category.name,'is_other',category.code='outros',
      'subtypes',coalesce((select jsonb_agg(jsonb_build_object(
        'id',subtype.id,'label',subtype.name) order by subtype.sort_order,subtype.name)
        from public.activity_taxonomies subtype
        where subtype.parent_id=category.id and subtype.status='active'),'[]'::jsonb))
      order by category.sort_order,category.name)
      from public.activity_taxonomies category
      where category.taxonomy_kind='category' and category.status='active'),'[]'::jsonb),
    'templates',coalesce((select jsonb_agg(jsonb_build_object(
      'id',template.id,'name',template.name,'description',template.description,
      'scope_kind',template.scope_kind,'institution_id',template.institution_id,
      'unit_id',template.unit_id,'governance_kind',template.governance_kind,
      'taxonomy_id',coalesce(taxonomy.parent_id,taxonomy.id),
      'subtype_id',case when taxonomy.taxonomy_kind='subtype' then taxonomy.id end,
      'status',template.status) order by template.scope_kind desc,template.name)
      from public.activity_templates template
      join public.activity_taxonomies taxonomy on taxonomy.id=template.taxonomy_id
      where template.status='active'
       and (template.scope_kind='platform'
        or (effective_institution_id is not null
         and template.institution_id=effective_institution_id))),
      '[]'::jsonb)
  ) into result;
  return result;
end $function$;

CREATE OR REPLACE FUNCTION public.superadmin_activity_filter_options_v2()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  result jsonb;
  code text;
begin
  begin
    select * into strict ctx from app_private.activity_v2_require_context('activities.read',null);
    with institutions as (
      select i.id,i.public_name,lower(i.slug) as handle from public.institutions i
      where i.deleted_at is null
        and (ctx.scope_kind <> 'institution' or i.id = ctx.scope_institution_id)
    ), units as (
      select u.id,u.institution_id,u.name from public.units u
      join institutions i on i.id = u.institution_id
      where u.status <> 'archived'
    ), groups as (
      select g.id,g.unit_id,g.name from public.groups g
      join units u on u.id = g.unit_id and u.institution_id = g.institution_id
      where g.status <> 'archived'
    )
    select jsonb_build_object(
      'institutions',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',public_name,'handle',handle)
        order by public_name,id),'[]'::jsonb) from institutions),
      'units',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',name,'parent_id',institution_id)
        order by name,id),'[]'::jsonb) from units),
      'groups',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',name,'parent_id',unit_id)
        order by name,id),'[]'::jsonb) from groups)) into result;
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code,''),'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    return app_private.activity_v2_denied_envelope('activities.read','activity.filter_options',code,
      correlation,case when ctx.scope_kind = 'institution' then ctx.scope_institution_id else null end);
  end if;
  -- The collection audit contains counts only, never filters or row payloads.
  -- Keep the append outside the exception block so an audit failure aborts.
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'activities.read',ctx.aal,'activity.filter_options','success'::public.audit_outcome,null::text,
    correlation,case when ctx.scope_kind = 'institution' then ctx.scope_institution_id else null::uuid end,
    null::text,null::uuid,jsonb_build_object('row_count',
      jsonb_array_length(result->'institutions') + jsonb_array_length(result->'units')
      + jsonb_array_length(result->'groups')));
  return app_private.activity_v2_success_envelope(
    result || jsonb_build_object('correlation_id',correlation));
end $function$;

commit;
