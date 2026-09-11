-- Correcao de defeito em producao (achado na R04, 11/09/2026): 
-- app_private.child_safety_decide_authorization atribui p_decision (text) a
-- decision_status (enum public.child_safety_decision_status) sem cast. Em
-- Postgres 17 isso levanta 42804 no UPDATE, entao NENHUM ator (nem o revisor
-- exato da unidade) consegue persistir uma decisao de autorizacao de retirada.
-- Este pacote reescreve a funcao com o corpo de producao (lido em 11/09/2026
-- por supabase db query --linked) mudando somente o cast. Autorizacao,
-- assinatura, ACL, recibos, auditoria e notificacoes ficam identicos.
-- Nao depende da P32 (quem decide); o candidato RETIDO 171800 ja inclui este
-- cast e, se for aplicado depois, continua idempotente.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'child safety decision cast fix must run as postgres';
  end if;
  if to_regprocedure('app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text)') is null then
    raise object_not_in_prerequisite_state using message = 'child_safety_decide_authorization is required';
  end if;
end
$preflight$;

CREATE OR REPLACE FUNCTION app_private.child_safety_decide_authorization(p_request_id uuid, p_authorization_id uuid, p_expected_version bigint, p_decision text, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare
  actor uuid:=app_private.current_person_id(); request_hash bytea; replay jsonb;
  current_row public.authorized_person_authorizations%rowtype; before_state jsonb;
  result jsonb; notification_id uuid;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null
    or p_expected_version is null or p_expected_version<1
    or not app_private.has_mfa_aal2()
    or p_decision not in ('approved','rejected')
    or char_length(btrim(coalesce(p_reason,''))) not between 3 and 500 then
    raise insufficient_privilege using message='child safety decision unavailable';
  end if;
  request_hash:=extensions.digest(convert_to(jsonb_build_object('authorization_id',p_authorization_id,
    'version',p_expected_version,'decision',p_decision,'reason',btrim(p_reason))::text,'utf8'),'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
  replay:=app_private.child_safety_receipt(p_request_id,actor,'decide_authorization',request_hash);
  if replay is not null then return replay; end if;
  select a.* into current_row from public.authorized_person_authorizations a
  where a.id=p_authorization_id and a.decision_status='pending'
    and app_private.child_safety_has_exact_unit_review(a.institution_id,a.unit_id)
  for update;
  if current_row.id is null then raise no_data_found using message='child safety record unavailable'; end if;
  if current_row.version<>p_expected_version then
    raise serialization_failure using message='stale child safety version';
  end if;
  before_state:=jsonb_build_object('decision_status',current_row.decision_status,
    'lifecycle_status',current_row.status,'version',current_row.version);
  update public.authorized_person_authorizations set decision_status=p_decision::public.child_safety_decision_status,
    decision_reason=btrim(p_reason),decided_by_person_id=actor,decided_at=now(),
    status=case when p_decision='approved' then 'active'::public.record_status
      else 'inactive'::public.record_status end,version=version+1,updated_at=now()
  where id=current_row.id;
  result:=jsonb_build_object('authorization_id',current_row.id,'decision_status',p_decision,
    'lifecycle_status',case when p_decision='approved' then 'active' else 'inactive' end,
    'version',current_row.version+1);
  insert into public.context_notification_events(
    institution_id,unit_id,child_context_id,event_code,object_type,object_id,payload_json,
    created_by_person_id
  ) values(current_row.institution_id,current_row.unit_id,current_row.child_context_id,
    'child_safety.authorization_decided','authorized_person_authorization',current_row.id,
    jsonb_build_object('authorization_id',current_row.id,'decision_status',p_decision),actor)
  returning id into notification_id;
  perform app_private.child_safety_add_unit_review_recipients(
    notification_id,current_row.institution_id,current_row.unit_id
  );
  insert into public.context_notification_recipients(event_id,person_id)
    values(notification_id,current_row.created_by_person_id) on conflict do nothing;
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    institution_id,outcome,reason,before_json,after_json)
  values(actor,auth.jwt()->>'aal','child_safety.authorization.decide',
    'authorized_person_authorization',current_row.id,current_row.institution_id,'success',
    btrim(p_reason),before_state,result);
  return app_private.child_safety_store_receipt(
    p_request_id,actor,'decide_authorization',request_hash,current_row.id,result
  );
end $function$;

revoke all on function app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text) from public, anon;

commit;
