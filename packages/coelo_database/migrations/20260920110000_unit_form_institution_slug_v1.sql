-- Lote 108 (Sessao CODE-REVIEW r4, 20/09/2026): o formulario de unidade recebe o
-- @ da instituicao (institution_slug) nas opcoes, para a previa do @ padrao
-- (@nomedaunidade.instituicao) bater com o que create_unit_for_superadmin gera.
-- Antes o cliente derivava o slug do nome publico ("Colegio" -> "colgio") e a
-- previa divergia do @ nascido quando o nome tem acento.
-- Redefine app_private.get_unit_form_for_superadmin (corpo de producao + um campo);
-- a casca public.get_unit_form_for_superadmin continua a mesma.
create or replace function app_private.get_unit_form_for_superadmin(p_unit_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$declare t uuid;begin
if(select auth.uid())is null or app_private.current_person_id()is null then raise insufficient_privilege using message='authentication required';end if;
if p_unit_id is not null then select institution_id into t from public.units where id=p_unit_id;
if t is null then return jsonb_build_object('unit',null,'not_found',true,'institutions','[]'::jsonb,'unit_types','[]'::jsonb,'plans','[]'::jsonb);end if;
if not app_private.has_scoped_platform_permission('units.read',t)then raise insufficient_privilege using message='units.read required';end if;end if;
return jsonb_build_object('unit',case when p_unit_id is null then null else app_private.unit_form_payload(p_unit_id)end,'not_found',false,
'institutions',coalesce((select jsonb_agg(jsonb_build_object('institution_id',i.id,'institution_name',i.public_name,'institution_slug',i.slug,
'institution_type',jsonb_build_object('id',i.institution_type_id,'label',it.name),'effective_plan',jsonb_build_object('id',sub.plan_id,'code',p.code,'label',p.name))order by i.public_name)
from public.institutions i left join public.institution_types it on it.id=i.institution_type_id
left join lateral(select s.plan_id from public.institution_subscriptions s where s.institution_id=i.id and s.status not in('cancelled','suspended')order by s.created_at desc,s.id desc limit 1)sub on true
left join public.plans p on p.id=sub.plan_id where i.deleted_at is null and app_private.has_scoped_platform_permission('units.read',i.id)),'[]'::jsonb),
'unit_types',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',name,'code',code)order by name)from public.unit_types where status='active'),'[]'::jsonb),
'plans',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'label',p.name,'code',p.code)order by p.name)from public.plans p where p.status='active'),'[]'::jsonb));end$function$
;
