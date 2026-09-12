-- 20260911170800_internal_user_create_v1
-- internal-users.create (BE fail-closed desde a R03): contrato em dois tempos
-- para a Edge Function internal-user-create (dona: acessos-pessoas; deploy
-- pelo coordenador; contrato completo em acessos-pessoas.json rev 141).
--
--   1. superadmin_internal_user_create_authorize_v1(p_draft) - com o token do
--      operador: exige platform.member.update em escopo de PLATAFORMA, valida
--      o rascunho com as mesmas chaves do update, perfil ativo, owner so em
--      escopo de plataforma, CPF e e-mail inexistentes entre os internos e
--      escopos existentes. Nao grava nada; devolve o ator e o e-mail.
--   2. superadmin_internal_user_create_for_worker_v1(p_request_id,
--      p_actor_internal_identity_id, p_auth_user_id, p_draft) - so service_role
--      (a Edge Function chama depois de criar o auth user pelo Admin API):
--      reconfere o ator (membership interna ativa de plataforma) e o auth user
--      (existe e nao esta vinculado), cria identidade + perfil + vinculo auth
--      ativo + membership (+ escopos) numa transacao, audita e devolve a
--      projecao. A ponte de ator (220400/170500) cria a pessoa de servico e o @.
--      Replay do mesmo p_request_id devolve a mesma identidade.

create or replace function app_private.superadmin_internal_user_draft_valid(p_draft jsonb)
returns boolean language sql immutable set search_path='' as $$
  select p_draft is not null and pg_column_size(p_draft)<=32768
    and jsonb_typeof(p_draft)='object' and jsonb_typeof(p_draft->'identity')='object'
    and (select array_agg(key order by key) from jsonb_object_keys(p_draft) key)
      = array['identity','profile_id','scope','scope_ids']::text[]
    and (select array_agg(key order by key) from jsonb_object_keys(p_draft->'identity') key)
      = array['additional_phone','birth_date','city','complement','country','cpf','department',
        'display_name','first_name','internal_function','job_title','last_name','mobile',
        'neighborhood','number','postal_code','professional_email','professional_notes','state',
        'street']::text[]
    and jsonb_typeof(p_draft->'profile_id')='string'
    and p_draft->>'scope' in('platform','limited')
    and jsonb_typeof(p_draft->'scope_ids')='array'
    and jsonb_array_length(p_draft->'scope_ids')<=100
    and (select count(*)=count(distinct value) from jsonb_array_elements_text(p_draft->'scope_ids'))
    and (p_draft->>'scope'='platform' or jsonb_array_length(p_draft->'scope_ids')>=1)
$$;
revoke all on function app_private.superadmin_internal_user_draft_valid(jsonb) from public, anon, authenticated;

-- Regras de negocio comuns aos dois tempos (perfil, owner, unicidade, escopos).
create or replace function app_private.superadmin_internal_user_create_check(p_draft jsonb)
returns void language plpgsql stable security definer set search_path='' as $$
declare target_role public.platform_roles%rowtype; scope_id uuid;
  draft_email text := lower(btrim(p_draft#>>'{identity,professional_email}'));
  draft_cpf text := regexp_replace(coalesce(p_draft#>>'{identity,cpf}',''),'\D','','g');
begin
  if not app_private.superadmin_internal_user_draft_valid(p_draft) then
    raise invalid_parameter_value using message='invalid internal user command';
  end if;
  select * into target_role from public.platform_roles
    where id=(p_draft->>'profile_id')::uuid and status='active';
  if target_role.id is null then
    raise invalid_parameter_value using message='unknown or inactive profile';
  end if;
  if target_role.code='owner' and p_draft->>'scope'<>'platform' then
    raise check_violation using message='owner requires platform scope';
  end if;
  if draft_cpf !~ '^[0-9]{11}$' or draft_email not like '%@%' then
    raise invalid_parameter_value using message='invalid internal user command';
  end if;
  if exists(select 1 from app_private.superadmin_internal_profiles p where p.cpf=draft_cpf) then
    raise unique_violation using message='internal user cpf already registered', detail='SAI_CONFLICT';
  end if;
  if exists(select 1 from app_private.superadmin_internal_profiles p where p.professional_email=draft_email) then
    raise unique_violation using message='internal user email already registered', detail='SAI_CONFLICT';
  end if;
  if p_draft->>'scope'='limited' then
    for scope_id in select value::uuid from jsonb_array_elements_text(p_draft->'scope_ids') loop
      if not exists(select 1 from public.institutions i where i.id=scope_id) then
        raise foreign_key_violation using message='unknown institution scope';
      end if;
    end loop;
  end if;
end $$;
revoke all on function app_private.superadmin_internal_user_create_check(jsonb) from public, anon, authenticated;

-- 1. autorizacao com o token do operador ----------------------------------------
create or replace function public.superadmin_internal_user_create_authorize_v1(p_draft jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
  error_state text; error_detail text; reason_code text;
begin
  select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.member.update');
  if ctx.scope_kind<>'platform' then
    raise insufficient_privilege using message='internal user creation requires platform scope',detail='SAI_PERMISSION_DENIED';
  end if;
  perform app_private.superadmin_internal_user_create_check(p_draft);
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'platform.member.update',ctx.aal,'superadmin.internal-users.create-authorize','success',null,
    correlation,null,'superadmin_internal_identity',null);
  return jsonb_build_object('ok',true,'data',jsonb_build_object(
    'actor_internal_identity_id',ctx.internal_identity_id,
    'professional_email',lower(btrim(p_draft#>>'{identity,professional_email}')),
    'display_name',coalesce(nullif(btrim(p_draft#>>'{identity,display_name}'),''),
      btrim(p_draft#>>'{identity,first_name}')||' '||btrim(p_draft#>>'{identity,last_name}'))),'error',null);
exception when others then
  get stacked diagnostics error_state=returned_sqlstate,error_detail=pg_exception_detail;
  reason_code:=app_private.superadmin_internal_user_denial_code(error_state,error_detail);
  perform app_private.audit_superadmin_internal_denial_if_identified(
    'platform.member.update','superadmin.internal-users.create-authorize',reason_code,correlation);
  return app_private.superadmin_internal_user_error_envelope(reason_code,correlation);
end $$;
revoke all on function public.superadmin_internal_user_create_authorize_v1(jsonb) from public, anon, service_role;
grant execute on function public.superadmin_internal_user_create_authorize_v1(jsonb) to authenticated;

-- 2. criacao pela Edge Function (service_role) -----------------------------------
create or replace function public.superadmin_internal_user_create_for_worker_v1(
  p_request_id uuid, p_actor_internal_identity_id uuid, p_auth_user_id uuid, p_draft jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor_membership app_private.superadmin_internal_memberships%rowtype;
  new_identity uuid; new_membership uuid; scope_id uuid; existing uuid;
begin
  if current_setting('request.jwt.claim.role', true) is distinct from 'service_role'
     and current_user not in ('postgres','service_role') then
    raise insufficient_privilege using message='worker only',detail='SAI_PERMISSION_DENIED';
  end if;
  if p_request_id is null or p_actor_internal_identity_id is null or p_auth_user_id is null then
    raise invalid_parameter_value using message='invalid internal user command';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('coelo.internal-user-create:'||p_request_id::text,0));
  -- replay: a identidade criada com este request ja existe
  select identity.id into existing from app_private.superadmin_internal_identities identity
    join app_private.superadmin_internal_auth_links link on link.internal_identity_id=identity.id
    where link.auth_user_id=p_auth_user_id;
  if existing is not null then
    return jsonb_build_object('ok',true,'data',app_private.superadmin_internal_user_projection(existing,true),'error',null);
  end if;
  select * into actor_membership from app_private.superadmin_internal_memberships
    where internal_identity_id=p_actor_internal_identity_id and status='active' and scope_kind='platform'
    order by created_at desc limit 1;
  if actor_membership.id is null then
    raise insufficient_privilege using message='actor without active platform membership',detail='SAI_PERMISSION_DENIED';
  end if;
  if not exists(select 1 from auth.users u where u.id=p_auth_user_id) then
    raise foreign_key_violation using message='unknown auth user';
  end if;
  if exists(select 1 from public.person_auth_links l where l.auth_user_id=p_auth_user_id and l.status='active') then
    raise check_violation using message='auth user belongs to the people realm';
  end if;
  perform app_private.superadmin_internal_user_create_check(p_draft);

  insert into app_private.superadmin_internal_identities(created_by_internal_identity_id)
    values(p_actor_internal_identity_id) returning id into new_identity;
  insert into app_private.superadmin_internal_profiles(
    internal_identity_id,first_name,last_name,display_name,birth_date,cpf,professional_email,mobile,
    additional_phone,job_title,department,internal_function,professional_notes,postal_code,street,
    address_number,complement,neighborhood,city,state,country)
  values(new_identity,
    btrim(p_draft#>>'{identity,first_name}'), btrim(p_draft#>>'{identity,last_name}'),
    coalesce(btrim(p_draft#>>'{identity,display_name}'),''),
    nullif(p_draft#>>'{identity,birth_date}','')::date,
    regexp_replace(coalesce(p_draft#>>'{identity,cpf}',''),'\D','','g'),
    lower(btrim(p_draft#>>'{identity,professional_email}')),
    coalesce(btrim(p_draft#>>'{identity,mobile}'),''), coalesce(btrim(p_draft#>>'{identity,additional_phone}'),''),
    btrim(p_draft#>>'{identity,job_title}'), coalesce(btrim(p_draft#>>'{identity,department}'),''),
    coalesce(btrim(p_draft#>>'{identity,internal_function}'),''), coalesce(btrim(p_draft#>>'{identity,professional_notes}'),''),
    coalesce(btrim(p_draft#>>'{identity,postal_code}'),''), coalesce(btrim(p_draft#>>'{identity,street}'),''),
    coalesce(btrim(p_draft#>>'{identity,number}'),''), coalesce(btrim(p_draft#>>'{identity,complement}'),''),
    coalesce(btrim(p_draft#>>'{identity,neighborhood}'),''), coalesce(btrim(p_draft#>>'{identity,city}'),''),
    coalesce(btrim(p_draft#>>'{identity,state}'),''), coalesce(nullif(btrim(p_draft#>>'{identity,country}'),''),'Brasil'));
  insert into app_private.superadmin_internal_auth_links(internal_identity_id,auth_user_id,changed_by_internal_identity_id)
    values(new_identity,p_auth_user_id,p_actor_internal_identity_id);
  insert into app_private.superadmin_internal_memberships(
    internal_identity_id,platform_role_id,scope_kind,scope_institution_id,changed_by_internal_identity_id)
  values(new_identity,(p_draft->>'profile_id')::uuid,
    case when p_draft->>'scope'='platform' then 'platform' else 'institution' end::app_private.superadmin_internal_scope_kind,
    case when p_draft->>'scope'='platform' then null else (p_draft->'scope_ids'->>0)::uuid end,
    p_actor_internal_identity_id)
  returning id into new_membership;
  if p_draft->>'scope'='limited' then
    for scope_id in select value::uuid from jsonb_array_elements_text(p_draft->'scope_ids') loop
      insert into app_private.superadmin_internal_membership_scopes(membership_id,institution_id)
        values(new_membership,scope_id) on conflict do nothing;
    end loop;
  end if;
  -- O helper interno exige vinculo auth e sessao do ator; o worker nao os tem.
  -- A trilha guarda o ator (pessoa de servico), o request e a identidade criada.
  insert into audit.audit_logs(actor_person_id, mfa_aal, action_code, object_type, object_id, outcome, reason, correlation_id, after_json)
  values ((select person_id from app_private.superadmin_internal_actor_people where internal_identity_id=p_actor_internal_identity_id),
    'aal1', 'membership_changed', 'superadmin_internal_identity', new_identity, 'success',
    'superadmin.internal-users.create', p_request_id,
    jsonb_build_object('actor_internal_identity_id', p_actor_internal_identity_id, 'auth_user_id', p_auth_user_id));
  return jsonb_build_object('ok',true,'data',app_private.superadmin_internal_user_projection(new_identity,true),'error',null);
end $$;
revoke all on function public.superadmin_internal_user_create_for_worker_v1(uuid,uuid,uuid,jsonb) from public, anon, authenticated;
grant execute on function public.superadmin_internal_user_create_for_worker_v1(uuid,uuid,uuid,jsonb) to service_role;
