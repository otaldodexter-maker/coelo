-- Rodada 5 (E2-R05, frente Operacoes), gate de Back-end de plans.list,
-- plans.create e plans.edit pela regua do MVP (ADR 0034).
--
-- Defeitos encontrados ao provar as RPCs de Planos no espelho local
-- (baseline + 107 pacotes na ordem de producao):
--
-- 1. Depois de 20260910171000 (P7, Decisao 12), app_private.has_platform_permission(text)
--    passou a contar memberships escopadas a instituicao. app_private.assert_plan_permission
--    usava essa forma, entao um perfil de instituicao que conceda plan.change
--    conseguia criar e editar o catalogo de planos, que e da plataforma e nao
--    tem instituicao. Passa a exigir membership de plataforma via
--    app_private.has_scoped_platform_permission(p_permission, null), que ja
--    e a semantica usada por institution_subscriptions ('plan.change required').
-- 2. superadmin_plan_save validava status com coalesce('active') mas inseria
--    e atualizava sem coalesce: payload sem status virava 23502 em vez do
--    padrao 'active' que a validacao promete.
-- 3. public.plans, plan_entitlements e plan_change_receipts nao concedem nada a
--    anon/authenticated em producao (dump da baseline: somente service_role),
--    mas o espelho local herda grants do default ACL da imagem. Revogar de
--    forma idempotente deixa o espelho igual a producao; as RPCs sao
--    SECURITY DEFINER e nao dependem desses grants.
--
-- Reversao: recriar assert_plan_permission e superadmin_plan_save com o corpo
-- da baseline 20260910000000 (linhas ~1401 e ~25629).

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'plans platform scope migration must run as postgres';
  end if;
  if to_regprocedure('app_private.assert_plan_permission(text,boolean)') is null
     or to_regprocedure('app_private.has_scoped_platform_permission(text,uuid)') is null
     or to_regprocedure('public.superadmin_plan_save(uuid,uuid,bigint,jsonb,text)') is null
     or to_regprocedure('public.superadmin_plan_get(uuid)') is null
     or to_regclass('public.plans') is null
     or to_regclass('public.plan_entitlements') is null
     or to_regclass('public.plan_change_receipts') is null then
    raise object_not_in_prerequisite_state using message = 'plans catalog dependencies are required';
  end if;
end
$preflight$;

create or replace function app_private.assert_plan_permission(p_permission text, p_require_aal2 boolean default false)
returns uuid
language plpgsql
security definer
set search_path to ''
as $$
declare v_actor uuid;
begin
  if (select auth.uid()) is null then raise exception using errcode='28000',message='authentication_required'; end if;
  v_actor := app_private.current_person_id();
  if v_actor is null then raise exception using errcode='42501',message='internal_actor_required'; end if;
  -- Catalogo de planos e da plataforma: somente membership de plataforma conta.
  if not app_private.has_scoped_platform_permission(p_permission, null::uuid) then
    raise exception using errcode='42501',message='permission_denied';
  end if;
  if p_require_aal2 and not app_private.has_mfa_aal2() then raise exception using errcode='42501',message='mfa_aal2_required'; end if;
  return v_actor;
end; $$;

create or replace function public.superadmin_plan_save(p_request_id uuid, p_plan_id uuid, p_expected_revision bigint, p_payload jsonb, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $_$
declare
  v_actor uuid; v_plan public.plans%rowtype; v_existing public.plans%rowtype; v_key text; v_value jsonb; v_action text;
  v_status text := coalesce(p_payload->>'status','active');
begin
  v_actor:=app_private.assert_plan_permission('plan.change',true);
  if p_request_id is null then raise exception using errcode='22023',message='request_id_required'; end if;
  if coalesce(char_length(trim(p_reason)),0) not between 1 and 1000 then raise exception using errcode='22023',message='reason_required'; end if;
  if coalesce(char_length(trim(p_payload->>'name')),0) not between 1 and 160 or coalesce(char_length(trim(p_payload->>'description')),0) not between 1 and 2000 then
    raise exception using errcode='22023',message='invalid_plan_identity';
  end if;
  if v_status not in ('active','archived') then raise exception using errcode='22023',message='invalid_status'; end if;
  select p.* into v_existing from public.plans p join public.plan_change_receipts r on r.plan_id=p.id where r.request_id=p_request_id;
  if found then return public.superadmin_plan_get(v_existing.id); end if;
  if p_plan_id is null then
    if coalesce(p_payload->>'code','') !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then raise exception using errcode='22023',message='invalid_plan_code'; end if;
    insert into public.plans(code,name,description,status,billing_mode,revision,created_by_person_id,updated_by_person_id)
    values(p_payload->>'code',trim(p_payload->>'name'),trim(p_payload->>'description'),v_status::public.record_status,'manual',1,v_actor,v_actor)
    returning * into v_plan;
    v_action:='create';
  else
    select * into v_existing from public.plans where id=p_plan_id for update;
    if not found then raise exception using errcode='P0002',message='plan_not_found'; end if;
    if p_expected_revision is null or p_expected_revision<>v_existing.revision then raise exception using errcode='40001',message='plan_revision_conflict'; end if;
    if p_payload?'code' and p_payload->>'code'<>v_existing.code then raise exception using errcode='22023',message='plan_code_immutable'; end if;
    update public.plans set name=trim(p_payload->>'name'),description=trim(p_payload->>'description'),
      status=v_status::public.record_status,revision=revision+1,updated_at=now(),updated_by_person_id=v_actor
    where id=p_plan_id returning * into v_plan;
    v_action:=case when v_existing.status='active' and v_plan.status='archived' then 'archive'
      when v_existing.status='archived' and v_plan.status='active' then 'restore' else 'update' end;
  end if;
  delete from public.plan_entitlements where plan_id=v_plan.id;
  for v_key,v_value in select key,value from jsonb_each(coalesce(p_payload->'entitlements','{}'::jsonb)) loop
    if v_key not in ('feature.communication','feature.agenda','feature.invitations','feature.chat','feature.notices','feature.routine','feature.happens','feature.now','feature.moments','limit.units','limit.memberships','limit.storage_gb','limit.media_gb') then
      raise exception using errcode='22023',message='invalid_entitlement';
    end if;
    if v_key like 'feature.%' and jsonb_typeof(v_value->'enabled')<>'boolean' then raise exception using errcode='22023',message='invalid_feature_value'; end if;
    if v_key like 'limit.%' and (jsonb_typeof(v_value->'value')<>'number' or (v_value->>'value')::numeric<0 or (v_value->>'value')::numeric>100000000) then
      raise exception using errcode='22023',message='invalid_limit_value';
    end if;
    insert into public.plan_entitlements(plan_id,entitlement_key,value_kind,value_json,status)
    values(v_plan.id,v_key,case when v_key like 'feature.%' then 'boolean' else 'integer' end,v_value,'active');
  end loop;
  insert into public.plan_change_receipts(request_id,plan_id,actor_person_id,action,previous_revision,next_revision,reason)
  values(p_request_id,v_plan.id,v_actor,v_action,v_existing.revision,v_plan.revision,trim(p_reason));
  return public.superadmin_plan_get(v_plan.id);
exception when unique_violation then raise exception using errcode='23505',message='plan_code_or_request_conflict';
end; $_$;

-- ACL igual a producao para as RPCs de Planos (authenticated executa; anon nao).
revoke all on function app_private.assert_plan_permission(text,boolean) from public, anon;
revoke all on function public.superadmin_plan_save(uuid,uuid,bigint,jsonb,text) from public, anon;
grant execute on function public.superadmin_plan_save(uuid,uuid,bigint,jsonb,text) to authenticated, service_role;

-- Tabelas do catalogo continuam sem acesso direto de cliente (RLS + sem grant).
revoke all on table public.plans, public.plan_entitlements, public.plan_change_receipts from public, anon, authenticated;

comment on function app_private.assert_plan_permission(text,boolean) is
  'Portao das RPCs de Planos: sessao autenticada, pessoa resolvida e permissao concedida por membership de plataforma (has_scoped_platform_permission com instituicao nula). Membership escopada a instituicao nao alcanca o catalogo de planos.';

commit;
