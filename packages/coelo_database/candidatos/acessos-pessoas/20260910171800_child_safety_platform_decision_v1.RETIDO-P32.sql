-- Candidato RETIDO. So se aplica apos "P32 aprovado (b)" pelo Owner.
--
-- Nao aplicar antes da decisao. Ele amplia quem pode decidir uma autorizacao
-- de retirada em Seguranca infantil (dado de crianca), e isso e decisao de
-- produto e de risco, nao do integrador.
--
-- Problema que resolve
-- --------------------
-- app_private.child_safety_decide_authorization so aceita o revisor exato da
-- unidade (app_private.child_safety_has_exact_unit_review). O Superadmin
-- (Owner de plataforma com child_safety.manage) recebe P0002
-- 'child safety record unavailable' ao aprovar ou rejeitar uma autorizacao
-- pendente, mesmo com a ponte de ator (superadmin_internal_actor_people)
-- dando pessoa de servico e espelho em public.platform_memberships.
--
-- Opcao (b) da pergunta P32
-- -------------------------
-- O ator de plataforma com app_private.has_platform_permission(
-- 'child_safety.manage', institution_id) passa a decidir TAMBEM, alem do
-- revisor exato da unidade. Quem nao tem nenhuma das duas condicoes continua
-- recebendo P0002, sem distinguir "nao existe" de "nao autorizado".
--
-- O escopo da permissao de plataforma e conferido contra a instituicao da
-- propria autorizacao: membership de plataforma com escopo 'platform' decide
-- em qualquer instituicao; membership com escopo 'institution' decide so na
-- instituicao correspondente.
--
-- O que muda em cada funcao
-- -------------------------
-- * app_private.child_safety_decide_authorization: a clausula de autorizacao
--   do SELECT ... FOR UPDATE ganha a alternativa de plataforma. A auditoria
--   (audit.audit_logs) continua a mesma: actor_person_id recebe a pessoa de
--   servico do operador interno (ponte de ator) e o guard append-only deriva
--   actor_role_code ('owner' para a plataforma, papel institucional para o
--   revisor), tudo dentro da cadeia de hash. Nao se acrescenta chave nova ao
--   payload porque audit_minimize_payload a descartaria. O recibo, a
--   resposta, a notificacao e os destinatarios nao mudam. Corrige tambem um defeito latente do corpo
--   de producao: `decision_status=p_decision` atribuia text ao enum
--   public.child_safety_decision_status sem cast, o que falha em tempo de
--   execucao (42804) para QUALQUER ator que passasse pela autorizacao,
--   inclusive o revisor exato da unidade. O cast explicito
--   `p_decision::public.child_safety_decision_status` resolve; o valor ja
--   e validado antes contra ('approved','rejected').
-- * app_private.child_safety_change_lifecycle: ja aceitava o ator de
--   plataforma por app_private.child_safety_can_administer (que inclui
--   has_platform_permission('child_safety.manage')). A substituicao so torna
--   a alternativa explicita e escopada por instituicao. Nao ha mudanca de
--   quem pode chamar nem na auditoria.
--   Se o Superadmin recebeu P0002 nessa funcao, a causa mais provavel e a
--   autorizacao nao estar com decision_status='approved' (a funcao so
--   opera sobre autorizacoes aprovadas), nao a permissao.
--
-- O que NAO muda
-- --------------
-- child_safety_request_authorization, child_safety_edit_pending_authorization,
-- child_safety_has_exact_unit_review, child_safety_can_administer, assinaturas,
-- ACL (postgres/authenticated em app_private; wrappers publicos intactos),
-- SECURITY DEFINER, search_path vazio, exigencia de AAL (has_mfa_aal2),
-- bloqueio otimista por versao, advisory lock, recibos idempotentes,
-- notificacao de decisao e destinatarios.
--
-- Prova
-- -----
-- supabase/tests/child_safety_platform_decision_v1_test.sql (pgTAP, rollback).
--
-- Reversao
-- --------
-- Reaplicar os corpos de 20260910170700_child_safety_security_closure.sql,
-- mantendo o cast do enum. Sem migracao de dado.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise exception 'aplicar como postgres';
  end if;
  if to_regprocedure(
       'app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text)'
     ) is null
     or to_regprocedure(
       'app_private.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)'
     ) is null
     or to_regprocedure('app_private.has_platform_permission(text,uuid)') is null
     or to_regprocedure('app_private.child_safety_has_exact_unit_review(uuid,uuid)') is null
     or to_regprocedure('app_private.child_safety_can_administer(uuid,uuid,uuid)') is null then
    raise exception 'funcoes base de child_safety ausentes; aplicar a baseline antes';
  end if;
  if not exists (
    select 1 from public.platform_permissions where code = 'child_safety.manage'
  ) then
    raise exception 'permissao child_safety.manage ausente no catalogo';
  end if;
end $preflight$;

create or replace function app_private.child_safety_decide_authorization(
  p_request_id uuid, p_authorization_id uuid, p_expected_version bigint,
  p_decision text, p_reason text
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$ declare
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
  -- P32 (b): revisor exato da unidade OU ator de plataforma com
  -- child_safety.manage escopado na instituicao da autorizacao.
  select a.* into current_row from public.authorized_person_authorizations a
  where a.id=p_authorization_id and a.decision_status='pending'
    and (app_private.child_safety_has_exact_unit_review(a.institution_id,a.unit_id)
      or app_private.has_platform_permission('child_safety.manage',a.institution_id))
  for update;
  if current_row.id is null then raise no_data_found using message='child safety record unavailable'; end if;
  if current_row.version<>p_expected_version then
    raise serialization_failure using message='stale child safety version';
  end if;
  before_state:=jsonb_build_object('decision_status',current_row.decision_status,
    'lifecycle_status',current_row.status,'version',current_row.version);
  update public.authorized_person_authorizations set
    decision_status=p_decision::public.child_safety_decision_status,
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

create or replace function app_private.child_safety_change_lifecycle(
  p_request_id uuid, p_authorization_id uuid, p_expected_version bigint,
  p_lifecycle_status text, p_reason text
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$ declare
  actor uuid:=app_private.current_person_id(); request_hash bytea; replay jsonb;
  current_row public.authorized_person_authorizations%rowtype; before_state jsonb; result jsonb;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null
    or p_expected_version is null or p_expected_version<1
    or not app_private.has_mfa_aal2()
    or p_lifecycle_status not in ('active','suspended','archived')
    or char_length(btrim(coalesce(p_reason,''))) not between 3 and 500 then
    raise insufficient_privilege using message='child safety lifecycle unavailable';
  end if;
  request_hash:=extensions.digest(convert_to(jsonb_build_object('authorization_id',p_authorization_id,
    'version',p_expected_version,'status',p_lifecycle_status,'reason',btrim(p_reason))::text,
    'utf8'),'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
  replay:=app_private.child_safety_receipt(p_request_id,actor,'change_lifecycle',request_hash);
  if replay is not null then return replay; end if;
  -- P32 (b): ator de plataforma com child_safety.manage escopado na
  -- instituicao OU quem administra o contexto (child_safety_can_administer,
  -- que ja incluia a plataforma sem escopo). Guardiao continua fora.
  select a.* into current_row from public.authorized_person_authorizations a
  where a.id=p_authorization_id and a.decision_status='approved'
    and (app_private.has_platform_permission('child_safety.manage',a.institution_id)
      or app_private.child_safety_can_administer(a.institution_id,a.unit_id,a.child_context_id))
  for update;
  if current_row.id is null then raise no_data_found using message='child safety record unavailable'; end if;
  if current_row.version<>p_expected_version then
    raise serialization_failure using message='stale child safety version';
  end if;
  if p_lifecycle_status='active' and (current_row.valid_from>current_date
    or current_row.valid_until is not null and current_row.valid_until<current_date) then
    raise check_violation using message='authorization validity prevents activation';
  end if;
  before_state:=jsonb_build_object('decision_status',current_row.decision_status,
    'lifecycle_status',current_row.status,'version',current_row.version);
  update public.authorized_person_authorizations set
    status=p_lifecycle_status::public.record_status,
    suspended_by_person_id=case when p_lifecycle_status='suspended' then actor end,
    suspended_at=case when p_lifecycle_status='suspended' then now() end,
    suspension_reason=case when p_lifecycle_status='suspended' then btrim(p_reason) end,
    revoked_at=case when p_lifecycle_status='archived' then now() end,
    version=version+1,updated_at=now() where id=current_row.id;
  result:=jsonb_build_object('authorization_id',current_row.id,'decision_status','approved',
    'lifecycle_status',p_lifecycle_status,'version',current_row.version+1);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    institution_id,outcome,reason,before_json,after_json)
  values(actor,auth.jwt()->>'aal','child_safety.authorization.lifecycle',
    'authorized_person_authorization',current_row.id,current_row.institution_id,'success',
    btrim(p_reason),before_state,result);
  return app_private.child_safety_store_receipt(
    p_request_id,actor,'change_lifecycle',request_hash,current_row.id,result
  );
end $function$;

do $postflight$
declare
  f record;
begin
  for f in
    select p.oid, p.proname, p.prosecdef, p.proconfig, p.proacl
    from pg_proc p
    where p.pronamespace = 'app_private'::regnamespace
      and p.proname in ('child_safety_decide_authorization','child_safety_change_lifecycle')
  loop
    if not f.prosecdef or coalesce(array_to_string(f.proconfig, ','), '') <> 'search_path=""' then
      raise exception 'funcao % perdeu security definer ou search_path vazio', f.proname;
    end if;
    if has_function_privilege('anon', f.oid, 'EXECUTE') then
      raise exception 'funcao % ficou executavel por anon', f.proname;
    end if;
    if not has_function_privilege('authenticated', f.oid, 'EXECUTE') then
      raise exception 'funcao % perdeu execute de authenticated', f.proname;
    end if;
  end loop;
  if has_function_privilege('anon',
       'public.child_safety_decide_authorization(uuid,uuid,bigint,text,text)', 'EXECUTE')
     or has_function_privilege('anon',
       'public.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)', 'EXECUTE') then
    raise exception 'wrapper publico ficou executavel por anon';
  end if;
end $postflight$;

commit;
