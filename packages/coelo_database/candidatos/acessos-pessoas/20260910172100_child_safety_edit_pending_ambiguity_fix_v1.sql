-- Correcao de defeito em producao (achado na R04, 11/09/2026, 03:13):
-- app_private.child_safety_edit_pending_authorization declara a variavel
-- plpgsql request_reason e faz `set ... request_reason=request_reason`, o que
-- levanta 42702 (column reference "request_reason" is ambiguous) em toda
-- edicao de autorizacao pendente. Reescreve a funcao com o corpo de producao
-- (lido por supabase db query --linked) renomeando so a variavel para
-- requested_reason. Autorizacao, assinatura, ACL, recibos e auditoria ficam
-- identicos.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'child safety edit fix must run as postgres';
  end if;
  if to_regprocedure('app_private.child_safety_edit_pending_authorization(uuid,uuid,bigint,jsonb)') is null then
    raise object_not_in_prerequisite_state using message = 'child_safety_edit_pending_authorization is required';
  end if;
end
$preflight$;

CREATE OR REPLACE FUNCTION app_private.child_safety_edit_pending_authorization(p_request_id uuid, p_authorization_id uuid, p_expected_version bigint, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare
  actor uuid:=app_private.current_person_id(); request_hash bytea; replay jsonb;
  current_row public.authorized_person_authorizations%rowtype; relation_id uuid;
  relation_code text; relation_detail text; capabilities text[]; starts date;
  ends date; requested_reason text; before_state jsonb; result jsonb;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null
    or p_expected_version is null or p_expected_version<1
    or jsonb_typeof(p_payload)<>'object' then
    raise insufficient_privilege using message='child safety record unavailable';
  end if;
  request_hash:=extensions.digest(convert_to(
    jsonb_build_object('authorization_id',p_authorization_id,'version',p_expected_version,
      'payload',p_payload)::text,'utf8'),'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
  replay:=app_private.child_safety_receipt(p_request_id,actor,'edit_pending',request_hash);
  if replay is not null then return replay; end if;
  select a.* into current_row from public.authorized_person_authorizations a
  where a.id=p_authorization_id and a.decision_status='pending'
    and (app_private.child_safety_can_administer(
      a.institution_id,a.unit_id,a.child_context_id
    ) or (a.created_by_person_id=actor and app_private.guardian_has_capability(
      a.child_context_id,'manage_authorized_people'
    )))
  for update;
  if current_row.id is null then raise no_data_found using message='child safety record unavailable'; end if;
  if current_row.version<>p_expected_version then
    raise serialization_failure using message='stale child safety version';
  end if;
  begin
    starts:=coalesce(nullif(p_payload->>'valid_from','')::date,current_row.valid_from);
    ends:=nullif(p_payload->>'valid_until','')::date;
  exception when others then raise invalid_parameter_value using message='invalid authorization request'; end;
  requested_reason:=btrim(coalesce(p_payload->>'request_reason',''));
  relation_code:=btrim(coalesce(p_payload->>'relationship_code',''));
  relation_detail:=nullif(btrim(coalesce(p_payload->>'relationship_detail','')),'');
  if jsonb_typeof(coalesce(p_payload->'capability_codes','[]'))<>'array' then
    raise invalid_parameter_value using message='invalid authorization request';
  end if;
  select array_agg(distinct value order by value) into capabilities
  from jsonb_array_elements_text(coalesce(p_payload->'capability_codes','[]')) value;
  select id into relation_id from public.family_relationship_types
    where code=relation_code and status='active';
  if char_length(requested_reason) not between 3 and 500
     or (ends is not null and ends<starts) or relation_id is null
     or (lower(relation_code) in ('other','others','outros') and relation_detail is null)
     or capabilities is null
     or not capabilities<@array['emergency_contact','pickup','transport']::text[]
     or cardinality(capabilities)=0 then
    raise invalid_parameter_value using message='invalid authorization request';
  end if;
  before_state:=jsonb_build_object('decision_status',current_row.decision_status,
    'lifecycle_status',current_row.status,'version',current_row.version);
  update public.authorized_person_authorizations set
    relationship_type_id=relation_id,relationship_detail=relation_detail,
    valid_from=starts,valid_until=ends,request_reason=requested_reason,
    version=version+1,updated_at=now() where id=current_row.id;
  delete from public.authorized_person_authorization_capabilities
    where authorization_id=current_row.id;
  insert into public.authorized_person_authorization_capabilities(authorization_id,capability_code)
    select current_row.id,unnest(capabilities);
  result:=jsonb_build_object('authorization_id',current_row.id,'decision_status','pending',
    'lifecycle_status','inactive','version',current_row.version+1);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    institution_id,outcome,before_json,after_json)
  values(actor,auth.jwt()->>'aal','child_safety.authorization.edit_pending',
    'authorized_person_authorization',current_row.id,current_row.institution_id,'success',
    before_state,result);
  return app_private.child_safety_store_receipt(
    p_request_id,actor,'edit_pending',request_hash,current_row.id,result
  );
end $function$;

revoke all on function app_private.child_safety_edit_pending_authorization(uuid,uuid,bigint,jsonb) from public, anon;

commit;
