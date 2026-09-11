-- Modelos de acesso e catalogo de permissoes (app -> modulo -> tela -> acao)
-- sobre a baseline de producao de 10/09/2026. Grupo acessos-pessoas, R04.
--
-- ORIGEM
--   Este pacote reconstroi, forward-only e sobre a baseline
--   `migrations/20260910000000_baseline_producao.sql`, o estado final da cadeia
--   historica de Modelos de acesso que nunca chegou a producao:
--     * migrations-historico/20260901170731_access_profile_models_crud_and_catalog.sql
--       (colunas application_code, coluna created_by_internal_identity_id,
--       tabela de recibos, 18 permissoes *.role_models.*, helpers internos,
--       CRUD, exportacao/importacao, catalogo, despachante com envelope e
--       wrappers publicos);
--     * migrations-historico/20260908021821_access_profile_models_read_prelookup_authorization.sql
--       (app_private.access_profile_require_any_model_read e as versoes
--       corrigidas de access_profile_model_detail e access_profile_model_call,
--       que autorizam ANTES de consultar o modelo).
--   Para que o resultado seja o mesmo que a cadeia historica produziria, tres
--   correcoes posteriores da mesma cadeia sao incorporadas, porque os testes
--   pgTAP do pacote e o cliente Superadmin dependem delas:
--     * 20260901193000_name_access_profile_model_rpc_arguments.sql: wrappers
--       publicos com argumentos nomeados (PostgREST resolve por nome);
--     * 20260908182839_access_profile_models_aal1_phase_policy.sql:
--       access_profile_require_model_action sem exigencia de AAL2 (ADR 0019,
--       adendo de 01/09; coerente com ADR 0034, Decisao 12, MFA fora do MVP);
--     * 20260909174500_d04_access_models_scope_filter.sql: cursor privado com
--       filtro de escopo em lista (uniao server-side) antes da paginacao.
--
-- O QUE FOI OMITIDO POR JA EXISTIR EM PRODUCAO (conferido por pg_proc/pg_class
-- no espelho `coelo_acessos` em 11/09/2026)
--   * app_private.require_superadmin_internal_context(text),
--     app_private.audit_superadmin_internal_denial_if_identified(...),
--     app_private.audit_append_superadmin_internal(... 13 args),
--     app_private.superadmin_internal_identities/_auth_links/_memberships,
--     o tipo app_private.superadmin_internal_context, extensions.digest,
--     app_private.audit_spreadsheet_cell(text): sao dependencias, so conferidas
--     no preflight.
--   * public.access_profile_templates e as tres tabelas de capacidades por
--     modelo, com RLS habilitado e forcado: nao sao recriadas; apenas os grants
--     diretos de authenticated/service_role sao revogados (nao ha policy nelas,
--     todo acesso passa por RPC security definer).
--   * public.platform_permissions com module_label/screen_label/action_label
--     NOT NULL: os 18 registros novos fornecem os tres rotulos.
--   * public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)
--     e app_private.superadmin_access_profile_models_cursor(mesma assinatura)
--     EXISTEM em producao com a mesma assinatura, mas com corpo legado
--     (20260811215451): autorizam por app_private.require_profile_authority
--     (pessoa global via current_person_id) e devolvem o JSON cru, sem o
--     envelope {ok,data,error}. O cliente Superadmin
--     (supabase_access_profile_repository.dart, _modelReadRpc) exige o envelope
--     e os cinco pgTAP do pacote tambem. Por isso este pacote SUBSTITUI o corpo
--     das duas funcoes com `create or replace`, preservando nomes de argumentos
--     e defaults (o PostgreSQL nao permite renomear nem remover defaults por
--     `create or replace`). A diferenca exata esta registrada no relatorio da
--     rodada; e a unica divergencia historico x producao deste pacote.
--
-- AJUSTES DELIBERADOS EM RELACAO AO HISTORICO
--   * requires_mfa das 18 permissoes novas nasce false: a migration
--     20260910230021 (MFA fora do MVP) zerou o catalogo inteiro antes deste
--     pacote e inserir true aqui reintroduziria exigencia que o Owner retirou.
--     A funcao de autorizacao nao exige AAL2 (versao 20260908182839); o
--     argumento p_require_mfa continua existindo por compatibilidade e e
--     ignorado, como no historico.
--   * Exportacao e importacao de modelos ficam pos-MVP (AGENTS.md, ADR 0031):
--     as funcoes existem, mas os wrappers publicos de export/import_preview/
--     import_confirm nao recebem EXECUTE para authenticated, exatamente como
--     o candidato nominal de 09/09 (supabase/tests/ap_models_nominal_package_test.sql)
--     ja fazia. Ligar depois exige apenas GRANT EXECUTE.
--   * Idempotencia: `if not exists`, `create or replace` e `on conflict`; o
--     preflight confere dependencias, nao ausencia, para que reaplicar em
--     espelho ja migrado nao aborte.
--
-- SEGURANCA PRESERVADA
--   security definer com search_path vazio, autorizacao no dominio interno
--   (require_superadmin_internal_context + Owner de plataforma), recibos
--   idempotentes por ator, envelopes de erro estaveis, auditoria de sucesso e
--   negativa, revoke de public/anon/service_role e EXECUTE somente para
--   authenticated nos wrappers publicos liberados no MVP.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
declare postgres_role oid := (select oid from pg_catalog.pg_roles where rolname = 'postgres');
begin
  if current_user <> 'postgres' then
    raise exception using errcode = '42501',
      message = 'access profile models v2 baseline must run as postgres';
  end if;
  if pg_catalog.to_regprocedure(
      'app_private.require_superadmin_internal_context(text)') is null
    or pg_catalog.to_regprocedure(
      'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)') is null
    or pg_catalog.to_regprocedure(
      'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)') is null
    or pg_catalog.to_regtype('app_private.superadmin_internal_context') is null
    or pg_catalog.to_regclass('app_private.superadmin_internal_identities') is null
    or pg_catalog.to_regclass('app_private.superadmin_internal_auth_links') is null
    or pg_catalog.to_regclass('app_private.superadmin_internal_memberships') is null then
    raise exception using errcode = '55000',
      message = 'superadmin internal auth foundation is required';
  end if;
  if pg_catalog.to_regclass('public.access_profile_templates') is null
    or pg_catalog.to_regclass('public.access_profile_template_platform_permissions') is null
    or pg_catalog.to_regclass('public.access_profile_template_institution_permissions') is null
    or pg_catalog.to_regclass('public.access_profile_template_principal_capabilities') is null
    or pg_catalog.to_regclass('public.platform_permissions') is null
    or pg_catalog.to_regclass('public.institution_permissions') is null
    or pg_catalog.to_regclass('public.guardian_permission_capabilities') is null
    or pg_catalog.to_regclass('public.platform_role_permissions') is null then
    raise exception using errcode = '55000',
      message = 'access profile capability core is required';
  end if;
  if pg_catalog.to_regprocedure('extensions.digest(bytea,text)') is null
    or pg_catalog.to_regprocedure('app_private.audit_spreadsheet_cell(text)') is null then
    raise exception using errcode = '55000',
      message = 'extensions.digest and app_private.audit_spreadsheet_cell are required';
  end if;
  if not exists (select 1 from public.platform_roles where code = 'owner' and status = 'active') then
    raise exception using errcode = '55000', message = 'active owner platform role is required';
  end if;
  if (select count(*) from pg_catalog.pg_attribute a
      where a.attrelid in ('public.platform_permissions'::regclass, 'public.institution_permissions'::regclass)
        and a.attname in ('module_label', 'screen_label', 'action_label')
        and a.attnotnull and not a.attisdropped) <> 6 then
    raise exception using errcode = '55000',
      message = 'catalog label columns must exist and be NOT NULL (20260811215451)';
  end if;
  if not exists (
    select 1 from pg_catalog.pg_default_acl default_acl
    where default_acl.defaclrole = postgres_role
      and default_acl.defaclobjtype = 'f'
      and default_acl.defaclnamespace = 0
      and not exists (
        select 1 from pg_catalog.aclexplode(default_acl.defaclacl) grant_item
        where grant_item.privilege_type = 'EXECUTE'
          and grant_item.grantee <> postgres_role)) then
    raise exception using errcode = '55000',
      message = 'default function execute privilege hardening is required';
  end if;
end
$preflight$;

-- 1. Aplicacao dona de cada catalogo (app -> modulo -> tela -> acao).
alter table public.platform_permissions
  add column if not exists application_code text not null default 'superadmin';
alter table public.institution_permissions
  add column if not exists application_code text not null default 'admin';
alter table public.guardian_permission_capabilities
  add column if not exists application_code text not null default 'principal';

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.platform_permissions'::regclass
      and conname = 'platform_permissions_application_code_check'
  ) then
    alter table public.platform_permissions
      add constraint platform_permissions_application_code_check
      check (application_code = 'superadmin');
  end if;
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.institution_permissions'::regclass
      and conname = 'institution_permissions_application_code_check'
  ) then
    alter table public.institution_permissions
      add constraint institution_permissions_application_code_check
      check (application_code = 'admin');
  end if;
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.guardian_permission_capabilities'::regclass
      and conname = 'guardian_capabilities_application_code_check'
  ) then
    alter table public.guardian_permission_capabilities
      add constraint guardian_capabilities_application_code_check
      check (application_code = 'principal');
  end if;
end $$;

-- 2. Ator interno que criou o modelo.
alter table public.access_profile_templates
  add column if not exists created_by_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id) on delete restrict;
create index if not exists access_profile_templates_created_by_internal_idx
  on public.access_profile_templates(created_by_internal_identity_id)
  where created_by_internal_identity_id is not null;

-- 3. Recibos idempotentes dos comandos de modelo (dominio interno).
create table if not exists app_private.access_profile_model_command_receipts(
  request_id uuid primary key,
  actor_internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  command_kind text not null check(command_kind in(
    'model_create','model_update','model_delete','model_duplicate','model_import_confirm')),
  request_hash bytea not null check(octet_length(request_hash)=32),
  result_json jsonb not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default(now()+interval '30 days')
);
create index if not exists access_profile_model_command_receipts_actor_idx
  on app_private.access_profile_model_command_receipts(
    actor_internal_identity_id,created_at desc);
create index if not exists access_profile_model_command_receipts_expiry_idx
  on app_private.access_profile_model_command_receipts(expires_at);
alter table app_private.access_profile_model_command_receipts enable row level security;
alter table app_private.access_profile_model_command_receipts force row level security;
revoke all on app_private.access_profile_model_command_receipts
  from public,anon,authenticated,service_role;

-- 4. Permissoes *.role_models.* (rotulos obrigatorios; requires_mfa false no MVP)
--    e concessao inicial somente ao Owner.
insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,
  status,module_label,screen_label,action_label,application_code
)
select definition.code,'access','access_profile_models',definition.action_code,
  definition.description,definition.risk_level,false,'active',
  'Acessos','Modelos de perfil',definition.action_label,'superadmin'
from (values
  ('platform.role_models.read','read','Consultar modelos Superadmin.','normal','Visualizar'),
  ('platform.role_models.create','create','Criar modelos Superadmin.','high','Criar'),
  ('platform.role_models.update','update','Editar modelos Superadmin.','high','Editar'),
  ('platform.role_models.delete','delete','Inativar modelos Superadmin.','critical','Excluir'),
  ('platform.role_models.import','import','Importar modelos Superadmin.','critical','Importar'),
  ('platform.role_models.export','export','Exportar modelos Superadmin.','high','Exportar'),
  ('institution.role_models.read','read','Consultar modelos Admin.','normal','Visualizar'),
  ('institution.role_models.create','create','Criar modelos Admin.','high','Criar'),
  ('institution.role_models.update','update','Editar modelos Admin.','high','Editar'),
  ('institution.role_models.delete','delete','Inativar modelos Admin.','critical','Excluir'),
  ('institution.role_models.import','import','Importar modelos Admin.','critical','Importar'),
  ('institution.role_models.export','export','Exportar modelos Admin.','high','Exportar'),
  ('principal.role_models.read','read','Consultar modelos Principal.','high','Visualizar'),
  ('principal.role_models.create','create','Criar modelos Principal.','critical','Criar'),
  ('principal.role_models.update','update','Editar modelos Principal.','critical','Editar'),
  ('principal.role_models.delete','delete','Inativar modelos Principal.','critical','Excluir'),
  ('principal.role_models.import','import','Importar modelos Principal.','critical','Importar'),
  ('principal.role_models.export','export','Exportar modelos Principal.','high','Exportar')
) as definition(code,action_code,description,risk_level,action_label)
on conflict(code) do update set
  module_code=excluded.module_code,
  screen_code=excluded.screen_code,
  action_code=excluded.action_code,
  description=excluded.description,
  risk_level=excluded.risk_level,
  requires_mfa=false,
  status='active',
  module_label=excluded.module_label,
  screen_label=excluded.screen_label,
  action_label=excluded.action_label,
  application_code=excluded.application_code,
  updated_at=now();

insert into public.platform_role_permissions(
  role_id,permission_id,effect,conditions_json,status
)
select role_record.id,permission_record.id,'allow','{}'::jsonb,'active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on (permission_record.code like 'platform.role_models.%'
    or permission_record.code like 'institution.role_models.%'
    or permission_record.code like 'principal.role_models.%')
where role_record.code='owner'
on conflict(role_id,permission_id) do update set
  effect='allow',status='active',revoked_at=null;

-- 5. Autorizacao no dominio interno (versao 20260908182839: sem exigencia de
--    AAL2; p_require_mfa mantido por compatibilidade e ignorado).
create or replace function app_private.access_profile_require_model_action(
  p_domain text,
  p_action text,
  p_require_mfa boolean default true
) returns uuid
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  context_record app_private.superadmin_internal_context;
  permission_code text;
begin
  if p_domain not in ('platform','institution','principal')
    or p_action not in ('read','create','update','delete','import','export') then
    raise invalid_parameter_value using message='unsupported access model action';
  end if;
  permission_code:=p_domain||'.role_models.'||p_action;
  select * into strict context_record
  from app_private.require_superadmin_internal_context(permission_code);
  if context_record.scope_kind<>'platform'
    or context_record.platform_role_code<>'owner' then
    raise insufficient_privilege using
      message='access model permission required',detail='SAI_PERMISSION_DENIED';
  end if;
  return context_record.internal_identity_id;
end
$$;

-- Pre-validacao de leitura (20260908021821): qualquer dominio legivel autoriza
-- a entrada; o dominio exato continua sendo exigido depois do lookup.
create or replace function app_private.access_profile_require_any_model_read()
returns void language plpgsql stable security definer set search_path='' as $$
declare
  read_domain text;
  denial_detail text;
begin
  foreach read_domain in array array['platform','institution','principal']::text[] loop
    begin
      perform app_private.access_profile_require_model_action(read_domain,'read',false);
      return;
    exception when insufficient_privilege then
      get stacked diagnostics denial_detail=pg_exception_detail;
      if denial_detail is distinct from 'SAI_PERMISSION_DENIED' then
        raise;
      end if;
    end;
  end loop;
  raise insufficient_privilege using
    message='access model read permission required',detail='SAI_PERMISSION_DENIED';
end
$$;

create or replace function app_private.access_profile_model_replay_internal(
  p_request_id uuid,p_actor uuid,p_command text,p_payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare receipt app_private.access_profile_model_command_receipts%rowtype;
  wanted_hash bytea;
begin
  if p_request_id is null then
    raise invalid_parameter_value using message='request id required';
  end if;
  wanted_hash:=extensions.digest(pg_catalog.convert_to(p_payload::text,'UTF8'),'sha256');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('coelo.access-profile-model:'||p_request_id::text,0));
  select * into receipt from app_private.access_profile_model_command_receipts
    where request_id=p_request_id for update;
  if receipt.request_id is null then return null; end if;
  if receipt.actor_internal_identity_id is distinct from p_actor then
    raise insufficient_privilege using
      message='idempotency receipt actor mismatch',detail='SAI_PERMISSION_DENIED';
  end if;
  if receipt.command_kind<>p_command or receipt.request_hash<>wanted_hash then
    raise invalid_parameter_value using message='idempotency key reused';
  end if;
  return receipt.result_json||pg_catalog.jsonb_build_object('replayed',true);
end
$$;

create or replace function app_private.access_profile_model_store_receipt_internal(
  p_request_id uuid,p_actor uuid,p_command text,p_payload jsonb,p_result jsonb
) returns void language sql volatile security definer set search_path='' as $$
  insert into app_private.access_profile_model_command_receipts(
    request_id,actor_internal_identity_id,command_kind,request_hash,result_json
  ) values(p_request_id,p_actor,p_command,
    extensions.digest(pg_catalog.convert_to(p_payload::text,'UTF8'),'sha256'),p_result)
$$;

create or replace function app_private.access_profile_model_internal_can_delegate(
  p_actor uuid,p_domain text,p_capability_code text
) returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1
    from app_private.superadmin_internal_memberships membership_record
    join public.platform_roles role_record
      on role_record.id=membership_record.platform_role_id
     and role_record.status='active'
    where membership_record.internal_identity_id=p_actor
      and membership_record.status='active'
      and membership_record.scope_kind='platform'
      and role_record.code='owner'
      and (
        p_domain in('institution','principal')
        or exists(
          select 1 from public.platform_role_permissions role_permission
          join public.platform_permissions permission_record
            on permission_record.id=role_permission.permission_id
           and permission_record.status='active'
          where role_permission.role_id=role_record.id
            and permission_record.code=p_capability_code
            and role_permission.effect='allow'
            and role_permission.status='active'
            and role_permission.revoked_at is null)))
$$;

create or replace function app_private.access_profile_model_audit_success(
  p_actor uuid,p_domain text,p_action text,p_object_id uuid default null
) returns void language plpgsql volatile security definer set search_path='' as $$
declare context_record app_private.superadmin_internal_context;
  permission_code text:=p_domain||'.role_models.'||p_action;
begin
  select * into strict context_record
    from app_private.require_superadmin_internal_context(permission_code);
  if context_record.internal_identity_id is distinct from p_actor then
    raise insufficient_privilege using
      message='internal model actor changed',detail='SAI_PERMISSION_DENIED';
  end if;
  perform app_private.audit_append_superadmin_internal(
    context_record.internal_identity_id,context_record.internal_auth_link_id,
    context_record.internal_membership_id,context_record.session_id,
    permission_code,context_record.aal,
    'superadmin.access-profile-models.'||p_action,'success',
    'MODEL_'||upper(p_action),gen_random_uuid(),null,
    'access_profile_model',p_object_id);
end
$$;

-- Detalhe (versao 20260908021821: autoriza antes do lookup).
create or replace function app_private.access_profile_model_detail(
  p_model_id uuid,
  p_authorize boolean default true
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  model_record public.access_profile_templates%rowtype;
  capabilities jsonb;
begin
  if p_authorize then
    perform app_private.access_profile_require_any_model_read();
  end if;
  select * into model_record
  from public.access_profile_templates model
  where model.id=p_model_id;
  if model_record.id is null then
    raise no_data_found using message='access profile model not found';
  end if;
  if p_authorize then
    perform app_private.access_profile_require_model_action(model_record.domain,'read',false);
  end if;
  if model_record.domain='platform' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'code',permission_record.code,'effect',model_permission.effect::text
    ) order by permission_record.code),'[]'::jsonb)
    into capabilities
    from public.access_profile_template_platform_permissions model_permission
    join public.platform_permissions permission_record
      on permission_record.id=model_permission.permission_id
    where model_permission.template_id=model_record.id;
  elsif model_record.domain='institution' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'code',permission_record.code,'effect',model_permission.effect::text
    ) order by permission_record.code),'[]'::jsonb)
    into capabilities
    from public.access_profile_template_institution_permissions model_permission
    join public.institution_permissions permission_record
      on permission_record.id=model_permission.permission_id
    where model_permission.template_id=model_record.id;
  else
    select coalesce(jsonb_agg(jsonb_build_object(
      'code',capability.code,'effect',model_capability.effect::text
    ) order by capability.code),'[]'::jsonb)
    into capabilities
    from public.access_profile_template_principal_capabilities model_capability
    join public.guardian_permission_capabilities capability
      on capability.id=model_capability.capability_id
    where model_capability.template_id=model_record.id;
  end if;
  return to_jsonb(model_record)||jsonb_build_object(
    'application_code',case model_record.domain
      when 'platform' then 'superadmin'
      when 'institution' then 'admin'
      else 'principal' end,
    'capabilities',capabilities,
    'capability_count',jsonb_array_length(capabilities)
  );
end
$$;

-- Cursor privado (versao 20260909174500). SUBSTITUI o corpo legado de
-- producao (autorizacao por require_profile_authority); assinatura, nomes e
-- defaults preservados.
create or replace function app_private.superadmin_access_profile_models_cursor(
  p_query text default null,
  p_domain text default null,
  p_status text default null,
  p_scope text default null,
  p_limit integer default 25,
  p_after_name text default null,
  p_after_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  size_no integer:=least(greatest(coalesce(p_limit,25),1),100);
  scope_values text[];
  allowed_scopes text[];
  result jsonb;
begin
  perform app_private.access_profile_require_model_action(p_domain,'read',false);
  if p_domain not in('platform','institution','principal')
    or char_length(coalesce(p_query,''))>120
    or char_length(coalesce(p_scope,''))>120
    or (p_status is not null and p_status not in('active','inactive'))
    or (p_after_name is null)<>(p_after_id is null) then
    raise invalid_parameter_value using message='invalid access model query';
  end if;
  if p_scope is not null then
    scope_values:=pg_catalog.string_to_array(p_scope,',');
    allowed_scopes:=case p_domain
      when 'platform' then array['platform','institution']::text[]
      when 'institution' then array['institution','unit','group']::text[]
      else array['child_context']::text[] end;
    if pg_catalog.cardinality(scope_values)=0
      or not scope_values <@ allowed_scopes then
      raise invalid_parameter_value using message='invalid access model scope filter';
    end if;
  end if;
  with rows as (
    select model.id,model.domain,model.code,model.name,model.description,
      model.status::text,model.max_scope_kind,model.version,model.is_system,
      case model.domain
        when 'platform' then (select count(*) from public.access_profile_template_platform_permissions item where item.template_id=model.id)
        when 'institution' then (select count(*) from public.access_profile_template_institution_permissions item where item.template_id=model.id)
        else (select count(*) from public.access_profile_template_principal_capabilities item where item.template_id=model.id)
      end::integer capability_count
    from public.access_profile_templates model
    where model.domain=p_domain
      and (nullif(btrim(p_query),'') is null or model.name ilike '%'||btrim(p_query)||'%')
      and (p_status is null or model.status::text=p_status)
      and (scope_values is null or model.max_scope_kind=any(scope_values))
      and (p_after_name is null or (lower(model.name),model.id)>(lower(p_after_name),p_after_id))
  ), page as (
    select * from rows order by lower(name),id limit size_no+1
  )
  select jsonb_build_object(
    'items',coalesce(jsonb_agg(to_jsonb(page) order by lower(name),id)
      filter(where row_number<=size_no),'[]'::jsonb),
    'next_cursor',case when count(*)>size_no then
      (select jsonb_build_object('name',name,'id',id)
        from page order by lower(name),id offset size_no-1 limit 1) end
  ) into result
  from (select page.*,row_number() over(order by lower(name),id) row_number from page) page;
  return result;
end
$$;

create or replace function app_private.access_profile_model_create_internal(
  p_actor uuid,
  p_draft jsonb
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  model_id uuid;
  domain text:=p_draft->>'domain';
  generated_code text;
  base_code text;
  capability_item jsonb;
  capabilities jsonb:=coalesce(p_draft->'capabilities','[]'::jsonb);
  scope_kind text:=p_draft->>'max_scope_kind';
begin
  if domain not in ('platform','institution','principal')
    or octet_length(pg_catalog.convert_to(p_draft::text,'UTF8'))>65536
    or char_length(btrim(coalesce(p_draft->>'name',''))) not between 2 and 120
    or coalesce(nullif(p_draft->>'status',''),'active') not in ('active','inactive')
    or jsonb_typeof(capabilities)<>'array'
    or jsonb_array_length(capabilities)>500 then
    raise invalid_parameter_value using message='invalid access model draft';
  end if;
  scope_kind:=coalesce(nullif(scope_kind,''),case domain
    when 'platform' then 'platform'
    when 'institution' then 'institution'
    else 'child_context' end);
  if (domain='platform' and scope_kind not in ('platform','institution'))
    or (domain='institution' and scope_kind not in ('institution','unit','group'))
    or (domain='principal' and scope_kind<>'child_context') then
    raise invalid_parameter_value using message='invalid access model scope';
  end if;
  if jsonb_array_length(capabilities)<>(
    select count(distinct item.value->>'code')
    from jsonb_array_elements(capabilities) item
  ) then
    raise invalid_parameter_value using message='duplicate access model capability';
  end if;
  for capability_item in select value from jsonb_array_elements(capabilities) loop
    if capability_item->>'effect' not in ('allow','deny') then
      raise invalid_parameter_value using message='invalid access model capability effect';
    end if;
    if domain='platform' and not exists(
      select 1 from public.platform_permissions permission_record
      where permission_record.code=capability_item->>'code' and permission_record.status='active'
    ) then
      raise invalid_parameter_value using message='unknown access model capability';
    elsif domain='institution' and not exists(
      select 1 from public.institution_permissions permission_record
      where permission_record.code=capability_item->>'code' and permission_record.status='active'
    ) then
      raise invalid_parameter_value using message='unknown access model capability';
    elsif domain='principal' and not exists(
      select 1 from public.guardian_permission_capabilities capability
      where capability.code=capability_item->>'code' and capability.status='active'
    ) then
      raise invalid_parameter_value using message='unknown access model capability';
    end if;
    if capability_item->>'effect'='allow'
      and not app_private.access_profile_model_internal_can_delegate(
        p_actor,domain,capability_item->>'code') then
      raise insufficient_privilege using message='cannot delegate capability operator does not hold';
    end if;
  end loop;
  base_code:=trim(both '-' from regexp_replace(
    lower(btrim(p_draft->>'name')),'[^a-z0-9]+','-','g'
  ));
  if char_length(base_code)<3 then base_code:='model'; end if;
  generated_code:=base_code||'-'||left(replace(gen_random_uuid()::text,'-',''),8);
  insert into public.access_profile_templates(
    domain,code,name,description,max_scope_kind,is_system,status,
    created_by_internal_identity_id
  ) values(
    domain,generated_code,btrim(p_draft->>'name'),
    nullif(btrim(p_draft->>'description'),''),scope_kind,false,
    coalesce(nullif(p_draft->>'status',''),'active')::public.record_status,p_actor
  ) returning id into model_id;
  if domain='platform' then
    insert into public.access_profile_template_platform_permissions(
      template_id,permission_id,effect
    )
    select model_id,permission_record.id,
      (item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.platform_permissions permission_record
      on permission_record.code=item.value->>'code';
  elsif domain='institution' then
    insert into public.access_profile_template_institution_permissions(
      template_id,permission_id,effect
    )
    select model_id,permission_record.id,
      (item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.institution_permissions permission_record
      on permission_record.code=item.value->>'code';
  else
    insert into public.access_profile_template_principal_capabilities(
      template_id,capability_id,effect
    )
    select model_id,capability.id,
      (item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.guardian_permission_capabilities capability
      on capability.code=item.value->>'code';
  end if;
  return app_private.access_profile_model_detail(model_id,false);
end
$$;

create or replace function app_private.superadmin_access_profile_model_create(
  p_request_id uuid,
  p_draft jsonb
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid;
  replay jsonb;
  model jsonb;
  result jsonb;
begin
  actor:=app_private.access_profile_require_model_action(p_draft->>'domain','create');
  if nullif(btrim(p_draft->>'reason'),'') is null
    or char_length(p_draft->>'reason')>500 then
    raise invalid_parameter_value using message='audit reason required';
  end if;
  replay:=app_private.access_profile_model_replay_internal(
    p_request_id,actor,'model_create',p_draft);
  if replay is not null then return replay; end if;
  model:=app_private.access_profile_model_create_internal(actor,p_draft);
  result:=jsonb_build_object('model',model,'model_id',model->>'id',
    'version',(model->>'version')::bigint,'replayed',false);
  perform app_private.access_profile_model_audit_success(
    actor,p_draft->>'domain','create',(model->>'id')::uuid);
  perform app_private.access_profile_model_store_receipt_internal(
    p_request_id,actor,'model_create',p_draft,result
  );
  return result;
end
$$;

create or replace function app_private.superadmin_access_profile_model_update(
  p_request_id uuid,
  p_draft jsonb
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  model_record public.access_profile_templates%rowtype;
  actor uuid;
  replay jsonb;
  before_data jsonb;
  after_data jsonb;
  result jsonb;
  capability_item jsonb;
  capabilities jsonb:=coalesce(p_draft->'capabilities','[]'::jsonb);
  expected_version bigint:=nullif(p_draft->>'expected_version','')::bigint;
begin
  select * into model_record from public.access_profile_templates model
  where model.id=nullif(p_draft->>'id','')::uuid for update;
  if model_record.id is null then raise no_data_found using message='access profile model not found'; end if;
  actor:=app_private.access_profile_require_model_action(model_record.domain,'update');
  if nullif(btrim(p_draft->>'reason'),'') is null
    or char_length(p_draft->>'reason')>500
    or octet_length(pg_catalog.convert_to(p_draft::text,'UTF8'))>65536 then
    raise invalid_parameter_value using message='invalid access model update';
  end if;
  replay:=app_private.access_profile_model_replay_internal(
    p_request_id,actor,'model_update',p_draft);
  if replay is not null then return replay; end if;
  if model_record.is_system then raise insufficient_privilege using message='system access model is protected'; end if;
  if model_record.version is distinct from expected_version then
    raise serialization_failure using message='stale access model version';
  end if;
  if char_length(btrim(coalesce(p_draft->>'name',''))) not between 2 and 120
    or coalesce(nullif(p_draft->>'status',''),model_record.status::text) not in ('active','inactive')
    or jsonb_typeof(capabilities)<>'array' or jsonb_array_length(capabilities)>500 then
    raise invalid_parameter_value using message='invalid access model draft';
  end if;
  if jsonb_array_length(capabilities)<>(
    select count(distinct item.value->>'code')
    from jsonb_array_elements(capabilities) item
  ) then
    raise invalid_parameter_value using message='duplicate access model capability';
  end if;
  for capability_item in select value from jsonb_array_elements(capabilities) loop
    if capability_item->>'effect' not in ('allow','deny')
      or (model_record.domain='platform' and not exists(select 1 from public.platform_permissions p where p.code=capability_item->>'code' and p.status='active'))
      or (model_record.domain='institution' and not exists(select 1 from public.institution_permissions p where p.code=capability_item->>'code' and p.status='active'))
      or (model_record.domain='principal' and not exists(select 1 from public.guardian_permission_capabilities p where p.code=capability_item->>'code' and p.status='active')) then
      raise invalid_parameter_value using message='unknown or invalid access model capability';
    end if;
    if capability_item->>'effect'='allow'
      and not app_private.access_profile_model_internal_can_delegate(
        actor,model_record.domain,capability_item->>'code') then
      raise insufficient_privilege using message='cannot delegate capability operator does not hold';
    end if;
  end loop;
  before_data:=app_private.access_profile_model_detail(model_record.id,false);
  update public.access_profile_templates set
    name=btrim(p_draft->>'name'),
    description=nullif(btrim(p_draft->>'description'),''),
    max_scope_kind=coalesce(nullif(p_draft->>'max_scope_kind',''),max_scope_kind),
    status=coalesce(nullif(p_draft->>'status',''),status::text)::public.record_status,
    version=version+1,
    updated_at=now()
  where id=model_record.id;
  delete from public.access_profile_template_platform_permissions where template_id=model_record.id;
  delete from public.access_profile_template_institution_permissions where template_id=model_record.id;
  delete from public.access_profile_template_principal_capabilities where template_id=model_record.id;
  if model_record.domain='platform' then
    insert into public.access_profile_template_platform_permissions(template_id,permission_id,effect)
    select model_record.id,p.id,(item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.platform_permissions p on p.code=item.value->>'code';
  elsif model_record.domain='institution' then
    insert into public.access_profile_template_institution_permissions(template_id,permission_id,effect)
    select model_record.id,p.id,(item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.institution_permissions p on p.code=item.value->>'code';
  else
    insert into public.access_profile_template_principal_capabilities(template_id,capability_id,effect)
    select model_record.id,p.id,(item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.guardian_permission_capabilities p on p.code=item.value->>'code';
  end if;
  after_data:=app_private.access_profile_model_detail(model_record.id,false);
  result:=jsonb_build_object('model',after_data,'model_id',model_record.id,
    'version',(after_data->>'version')::bigint,'replayed',false);
  perform app_private.access_profile_model_audit_success(
    actor,model_record.domain,'update',model_record.id);
  perform app_private.access_profile_model_store_receipt_internal(
    p_request_id,actor,'model_update',p_draft,result);
  return result;
end
$$;

create or replace function app_private.superadmin_access_profile_model_delete(
  p_request_id uuid,
  p_model_id uuid,
  p_expected_version bigint,
  p_reason text
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  model_record public.access_profile_templates%rowtype;
  actor uuid;
  payload jsonb:=jsonb_build_object('model_id',p_model_id,'expected_version',p_expected_version,'reason',p_reason);
  replay jsonb;
  before_data jsonb;
  after_data jsonb;
  result jsonb;
begin
  select * into model_record from public.access_profile_templates model
  where model.id=p_model_id for update;
  if model_record.id is null then raise no_data_found using message='access profile model not found'; end if;
  actor:=app_private.access_profile_require_model_action(model_record.domain,'delete');
  replay:=app_private.access_profile_model_replay_internal(
    p_request_id,actor,'model_delete',payload);
  if replay is not null then return replay; end if;
  if model_record.is_system then raise insufficient_privilege using message='system access model is protected'; end if;
  if model_record.version is distinct from p_expected_version then
    raise serialization_failure using message='stale access model version';
  end if;
  if nullif(btrim(p_reason),'') is null or char_length(p_reason)>500 then
    raise invalid_parameter_value using message='audit reason required';
  end if;
  before_data:=app_private.access_profile_model_detail(model_record.id,false);
  update public.access_profile_templates set status='inactive',version=version+1,updated_at=now()
  where id=model_record.id;
  after_data:=app_private.access_profile_model_detail(model_record.id,false);
  result:=jsonb_build_object('model_id',model_record.id,'status','inactive',
    'version',(after_data->>'version')::bigint,'replayed',false);
  perform app_private.access_profile_model_audit_success(
    actor,model_record.domain,'delete',model_record.id);
  perform app_private.access_profile_model_store_receipt_internal(
    p_request_id,actor,'model_delete',payload,result);
  return result;
end
$$;

create or replace function app_private.superadmin_access_profile_model_duplicate(
  p_request_id uuid,
  p_draft jsonb
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  source jsonb:=app_private.access_profile_model_detail(
    nullif(p_draft->>'source_model_id','')::uuid,false
  );
  actor uuid;
  replay jsonb;
  model jsonb;
  result jsonb;
  create_draft jsonb;
begin
  actor:=app_private.access_profile_require_model_action(source->>'domain','create');
  if nullif(btrim(p_draft->>'reason'),'') is null
    or char_length(p_draft->>'reason')>500
    or octet_length(pg_catalog.convert_to(p_draft::text,'UTF8'))>65536 then
    raise invalid_parameter_value using message='invalid access model duplication';
  end if;
  replay:=app_private.access_profile_model_replay_internal(
    p_request_id,actor,'model_duplicate',p_draft);
  if replay is not null then return replay; end if;
  create_draft:=jsonb_build_object(
    'domain',source->>'domain',
    'name',coalesce(nullif(btrim(p_draft->>'name'),''),source->>'name'||' (cópia)'),
    'description',coalesce(p_draft->>'description',source->>'description'),
    'max_scope_kind',source->>'max_scope_kind',
    'status','inactive',
    'capabilities',source->'capabilities'
  );
  model:=app_private.access_profile_model_create_internal(actor,create_draft);
  result:=jsonb_build_object('model',model,'model_id',model->>'id',
    'version',(model->>'version')::bigint,'replayed',false);
  perform app_private.access_profile_model_audit_success(
    actor,source->>'domain','create',(model->>'id')::uuid);
  perform app_private.access_profile_model_store_receipt_internal(
    p_request_id,actor,'model_duplicate',p_draft,result);
  return result;
end
$$;

create or replace function app_private.superadmin_access_profile_models_export(
  p_domain text
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid;
  csv text;
begin
  actor:=app_private.access_profile_require_model_action(p_domain,'export');
  select 'format_version,domain,name,description,max_scope_kind,status,capabilities'||E'\n'||
    coalesce(string_agg(
      'access-profile-models-v1,'||model.domain||',"'||
      replace(app_private.audit_spreadsheet_cell(model.name),'"','""')||'","'||
      replace(app_private.audit_spreadsheet_cell(coalesce(model.description,'')),'"','""')||'",'||
      model.max_scope_kind||','||model.status||',"'||
      replace(coalesce((app_private.access_profile_model_detail(model.id,false)->'capabilities')::text,'[]'),'"','""')||'"',
      E'\n' order by lower(model.name),model.id
    ),'')
  into csv
  from public.access_profile_templates model
  where model.domain=p_domain;
  perform app_private.access_profile_model_audit_success(
    actor,p_domain,'export',null);
  return jsonb_build_object('format_version','access-profile-models-v1',
    'domain',p_domain,'mime_type','text/csv','csv',csv);
end
$$;

create or replace function app_private.superadmin_access_profile_models_import_preview(
  p_domain text,
  p_rows jsonb
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid;
  row_item jsonb;
  capability_item jsonb;
  row_number integer:=0;
  error_code text;
  valid_count integer:=0;
  error_count integer:=0;
  preview_rows jsonb:='[]'::jsonb;
begin
  actor:=app_private.access_profile_require_model_action(p_domain,'import');
  if jsonb_typeof(p_rows)<>'array'
    or jsonb_array_length(p_rows) not between 1 and 100
    or octet_length(pg_catalog.convert_to(p_rows::text,'UTF8'))>1048576 then
    raise invalid_parameter_value using message='invalid access model import rows';
  end if;
  for row_item in select value from jsonb_array_elements(p_rows) loop
    row_number:=row_number+1;
    error_code:=null;
    if row_item ?| array['person_id','membership_id','assignment_id','institution_id',
      'unit_id','group_id','child_context_id','created_by','is_system'] then
      error_code:='mass_assignment_field';
    elsif coalesce(row_item->>'domain',p_domain)<>p_domain then
      error_code:='domain_mismatch';
    elsif char_length(btrim(coalesce(row_item->>'name',''))) not between 2 and 120 then
      error_code:='invalid_name';
    elsif jsonb_typeof(coalesce(row_item->'capabilities','[]'::jsonb))<>'array'
      or jsonb_array_length(coalesce(row_item->'capabilities','[]'::jsonb))>500 then
      error_code:='invalid_capabilities';
    elsif jsonb_array_length(coalesce(row_item->'capabilities','[]'::jsonb))<>(
      select count(distinct item.value->>'code')
      from jsonb_array_elements(coalesce(row_item->'capabilities','[]'::jsonb)) item
    ) then
      error_code:='duplicate_capability';
    else
      for capability_item in
        select value from jsonb_array_elements(coalesce(row_item->'capabilities','[]'::jsonb))
      loop
        if capability_item->>'effect' not in ('allow','deny')
          or (p_domain='platform' and not exists(select 1 from public.platform_permissions p where p.code=capability_item->>'code' and p.status='active'))
          or (p_domain='institution' and not exists(select 1 from public.institution_permissions p where p.code=capability_item->>'code' and p.status='active'))
          or (p_domain='principal' and not exists(select 1 from public.guardian_permission_capabilities p where p.code=capability_item->>'code' and p.status='active')) then
          error_code:='unknown_or_invalid_capability';
          exit;
        end if;
        if capability_item->>'effect'='allow'
          and not app_private.access_profile_model_internal_can_delegate(
            actor,p_domain,capability_item->>'code') then
          error_code:='capability_not_delegable';
          exit;
        end if;
      end loop;
    end if;
    preview_rows:=preview_rows||jsonb_build_array(jsonb_build_object(
      'row_number',row_number,
      'valid',error_code is null,
      'error_code',error_code,
      'payload',(row_item-array['person_id','membership_id','assignment_id',
        'institution_id','unit_id','group_id','child_context_id','created_by','is_system'])
        ||jsonb_build_object('domain',p_domain,'status','inactive')
    ));
    if error_code is null then valid_count:=valid_count+1;
    else error_count:=error_count+1; end if;
  end loop;
  return jsonb_build_object(
    'format_version','access-profile-models-v1','domain',p_domain,
    'valid_count',valid_count,'error_count',error_count,'rows',preview_rows
  );
end
$$;

create or replace function app_private.superadmin_access_profile_models_import_confirm(
  p_request_id uuid,
  p_domain text,
  p_rows jsonb,
  p_reason text
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid;
  payload jsonb:=jsonb_build_object('domain',p_domain,'rows',p_rows,'reason',p_reason);
  replay jsonb;
  preview jsonb;
  preview_row jsonb;
  model jsonb;
  created_models jsonb:='[]'::jsonb;
  result jsonb;
begin
  actor:=app_private.access_profile_require_model_action(p_domain,'import');
  if nullif(btrim(p_reason),'') is null or char_length(p_reason)>500
    or octet_length(pg_catalog.convert_to(p_rows::text,'UTF8'))>1048576 then
    raise invalid_parameter_value using message='audit reason required';
  end if;
  replay:=app_private.access_profile_model_replay_internal(
    p_request_id,actor,'model_import_confirm',payload);
  if replay is not null then return replay; end if;
  preview:=app_private.superadmin_access_profile_models_import_preview(p_domain,p_rows);
  if (preview->>'error_count')::integer<>0 then
    raise check_violation using message='access model import validation errors must be resolved';
  end if;
  for preview_row in select value from jsonb_array_elements(preview->'rows') loop
    model:=app_private.access_profile_model_create_internal(actor,preview_row->'payload');
    created_models:=created_models||jsonb_build_array(jsonb_build_object(
      'id',model->>'id','name',model->>'name','version',(model->>'version')::bigint
    ));
    perform app_private.access_profile_model_audit_success(
      actor,p_domain,'import',(model->>'id')::uuid);
  end loop;
  result:=jsonb_build_object(
    'format_version','access-profile-models-v1','domain',p_domain,
    'created_count',jsonb_array_length(created_models),'models',created_models,
    'replayed',false
  );
  perform app_private.access_profile_model_store_receipt_internal(
    p_request_id,actor,'model_import_confirm',payload,result
  );
  return result;
end
$$;

-- Catalogo app -> modulo -> tela -> acao (tres catalogos, so ativos).
create or replace function app_private.superadmin_access_permission_catalog()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare result jsonb;
begin
  perform app_private.access_profile_require_model_action('platform','read',false);
  with catalog as (
    select permission.application_code,permission.module_code,permission.module_label,
      coalesce(permission.screen_code,permission.module_code) screen_code,
      permission.screen_label,permission.action_code,permission.action_label,
      permission.code,permission.description,permission.risk_level,
      permission.requires_mfa
    from public.platform_permissions permission where permission.status='active'
    union all
    select permission.application_code,permission.module_code,permission.module_label,
      coalesce(permission.screen_code,permission.module_code),permission.screen_label,
      permission.action_code,permission.action_label,permission.code,
      permission.description,permission.risk_level,permission.requires_mfa
    from public.institution_permissions permission where permission.status='active'
    union all
    select capability.application_code,capability.module_code,capability.module_label,
      capability.screen_code,capability.screen_label,capability.action_code,
      capability.action_label,capability.code,capability.description,
      capability.risk_level,capability.requires_mfa
    from public.guardian_permission_capabilities capability where capability.status='active'
  )
  select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(catalog)
    order by application_code,module_code,screen_code,action_code,code),'[]'::jsonb))
  into result from catalog;
  return result;
end
$$;

create or replace function app_private.access_profile_model_error_envelope(
  p_code text,p_correlation_id uuid
) returns jsonb language sql immutable security invoker set search_path='' as $$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object(
      'code',case when p_code in(
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED','SAI_INVALID_ARGUMENT',
        'SAI_CONCURRENT_CHANGE') then p_code else 'SAI_INTERNAL_ERROR' end,
      'message',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 'Autenticação necessária.'
        when p_code='SAI_MFA_REQUIRED' then 'Confirme o segundo fator.'
        when p_code='SAI_INVALID_ARGUMENT' then 'Revise os dados informados.'
        when p_code='SAI_CONCURRENT_CHANGE' then 'O estado mudou. Recarregue e tente novamente.'
        when p_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED') then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'correlation_id',p_correlation_id,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code='SAI_INVALID_ARGUMENT' then 400
        when p_code='SAI_CONCURRENT_CHANGE' then 409
        when p_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end))
$$;

-- Despachante com envelope (versao 20260908021821: pre-validacao de leitura
-- antes de qualquer lookup por id).
create or replace function app_private.access_profile_model_call(
  p_operation text,p_args jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare result jsonb;domain text;permission_action text;actor uuid;
  correlation uuid:=gen_random_uuid();error_code text;error_detail text;sql_state text;
  object_id uuid;
begin
  begin
    if p_operation in('list','detail','catalog') then
      perform app_private.access_profile_require_any_model_read();
    end if;
    domain:=case
      when p_operation in('list','create','export','import_preview','import_confirm')
        then coalesce(p_args->>'domain',p_args#>>'{draft,domain}')
      when p_operation='catalog' then 'platform'
      when p_operation in('detail','delete') then (
        select model.domain from public.access_profile_templates model
        where model.id=nullif(p_args->>'model_id','')::uuid)
      when p_operation='update' then (
        select model.domain from public.access_profile_templates model
        where model.id=nullif(p_args#>>'{draft,id}','')::uuid)
      when p_operation='duplicate' then (
        select model.domain from public.access_profile_templates model
        where model.id=nullif(p_args#>>'{draft,source_model_id}','')::uuid)
    end;
    permission_action:=case p_operation
      when 'list' then 'read' when 'detail' then 'read' when 'catalog' then 'read'
      when 'duplicate' then 'create' when 'import_preview' then 'import'
      when 'import_confirm' then 'import' else p_operation end;
    if p_operation='list' then
      result:=app_private.superadmin_access_profile_models_cursor(
        p_args->>'query',domain,p_args->>'status',p_args->>'scope',
        coalesce((p_args->>'limit')::integer,25),p_args->>'after_name',
        nullif(p_args->>'after_id','')::uuid);
    elsif p_operation='detail' then
      result:=app_private.access_profile_model_detail(
        nullif(p_args->>'model_id','')::uuid,true);
    elsif p_operation='create' then
      result:=app_private.superadmin_access_profile_model_create(
        nullif(p_args->>'request_id','')::uuid,p_args->'draft');
    elsif p_operation='update' then
      result:=app_private.superadmin_access_profile_model_update(
        nullif(p_args->>'request_id','')::uuid,p_args->'draft');
    elsif p_operation='delete' then
      result:=app_private.superadmin_access_profile_model_delete(
        nullif(p_args->>'request_id','')::uuid,
        nullif(p_args->>'model_id','')::uuid,(p_args->>'expected_version')::bigint,
        p_args->>'reason');
    elsif p_operation='duplicate' then
      result:=app_private.superadmin_access_profile_model_duplicate(
        nullif(p_args->>'request_id','')::uuid,p_args->'draft');
    elsif p_operation='export' then
      result:=app_private.superadmin_access_profile_models_export(domain);
    elsif p_operation='import_preview' then
      result:=app_private.superadmin_access_profile_models_import_preview(
        domain,p_args->'rows');
    elsif p_operation='import_confirm' then
      result:=app_private.superadmin_access_profile_models_import_confirm(
        nullif(p_args->>'request_id','')::uuid,domain,p_args->'rows',p_args->>'reason');
    elsif p_operation='catalog' then
      result:=app_private.superadmin_access_permission_catalog();
    else
      raise invalid_parameter_value using message='unsupported model operation';
    end if;
    if p_operation in('list','detail','catalog','import_preview') then
      actor:=app_private.access_profile_require_model_action(
        coalesce(domain,'platform'),permission_action,false);
      object_id:=case when p_operation='detail'
        then nullif(p_args->>'model_id','')::uuid else null end;
      perform app_private.access_profile_model_audit_success(
        actor,coalesce(domain,'platform'),permission_action,object_id);
    end if;
  exception when others then
    get stacked diagnostics error_detail=pg_exception_detail,sql_state=returned_sqlstate;
    error_code:=case
      when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID',
        'SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
        'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
        then error_detail
      when sql_state='40001' then 'SAI_CONCURRENT_CHANGE'
      when sql_state in('22023','22P02','23514','23505','22001')
        then 'SAI_INVALID_ARGUMENT'
      when sql_state in('P0002','42501') then 'SAI_PERMISSION_DENIED'
      else 'SAI_INTERNAL_ERROR' end;
    perform app_private.audit_superadmin_internal_denial_if_identified(
      coalesce(case when domain in('platform','institution','principal')
        then domain else 'platform' end||'.role_models.'||
        coalesce(permission_action,'read'),'platform.role_models.read'),
      'superadmin.access-profile-models.'||coalesce(p_operation,'invalid'),
      error_code,correlation,null);
    return app_private.access_profile_model_error_envelope(error_code,correlation);
  end;
  return pg_catalog.jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

-- 6. Wrappers publicos com argumentos nomeados (20260901193000). O cursor
--    publico mantem nomes e defaults que producao ja tem.
create or replace function public.superadmin_access_profile_model_detail(
  p_model_id uuid
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('detail',
  pg_catalog.jsonb_build_object('model_id',p_model_id))$$;

create or replace function public.superadmin_access_profile_models_cursor(
  p_query text default null,
  p_domain text default null,
  p_status text default null,
  p_scope text default null,
  p_limit integer default 25,
  p_after_name text default null,
  p_after_id uuid default null
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('list',
  pg_catalog.jsonb_build_object(
    'query',p_query,'domain',p_domain,'status',p_status,'scope',p_scope,
    'limit',p_limit,'after_name',p_after_name,'after_id',p_after_id))$$;

create or replace function public.superadmin_access_profile_model_create(
  p_request_id uuid,
  p_draft jsonb
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('create',
  pg_catalog.jsonb_build_object('request_id',p_request_id,'draft',p_draft))$$;

create or replace function public.superadmin_access_profile_model_update(
  p_request_id uuid,
  p_draft jsonb
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('update',
  pg_catalog.jsonb_build_object('request_id',p_request_id,'draft',p_draft))$$;

create or replace function public.superadmin_access_profile_model_delete(
  p_request_id uuid,
  p_model_id uuid,
  p_expected_version bigint,
  p_reason text
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('delete',
  pg_catalog.jsonb_build_object(
    'request_id',p_request_id,'model_id',p_model_id,
    'expected_version',p_expected_version,'reason',p_reason))$$;

create or replace function public.superadmin_access_profile_model_duplicate(
  p_request_id uuid,
  p_draft jsonb
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('duplicate',
  pg_catalog.jsonb_build_object('request_id',p_request_id,'draft',p_draft))$$;

create or replace function public.superadmin_access_profile_models_export(
  p_domain text
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('export',
  pg_catalog.jsonb_build_object('domain',p_domain))$$;

create or replace function public.superadmin_access_profile_models_import_preview(
  p_domain text,
  p_rows jsonb
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('import_preview',
  pg_catalog.jsonb_build_object('domain',p_domain,'rows',p_rows))$$;

create or replace function public.superadmin_access_profile_models_import_confirm(
  p_request_id uuid,
  p_domain text,
  p_rows jsonb,
  p_reason text
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('import_confirm',
  pg_catalog.jsonb_build_object(
    'request_id',p_request_id,'domain',p_domain,
    'rows',p_rows,'reason',p_reason))$$;

create or replace function public.superadmin_access_permission_catalog()
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('catalog','{}'::jsonb)$$;

-- 7. ACLs: privados sem cliente; publicos somente authenticated; exportacao e
--    importacao sem EXECUTE para ninguem alem do owner (pos-MVP).
revoke all on function
  app_private.access_profile_require_model_action(text,text,boolean),
  app_private.access_profile_require_any_model_read(),
  app_private.access_profile_model_replay_internal(uuid,uuid,text,jsonb),
  app_private.access_profile_model_store_receipt_internal(uuid,uuid,text,jsonb,jsonb),
  app_private.access_profile_model_internal_can_delegate(uuid,text,text),
  app_private.access_profile_model_audit_success(uuid,text,text,uuid),
  app_private.access_profile_model_error_envelope(text,uuid),
  app_private.access_profile_model_call(text,jsonb),
  app_private.access_profile_model_detail(uuid,boolean),
  app_private.access_profile_model_create_internal(uuid,jsonb),
  app_private.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid),
  app_private.superadmin_access_profile_model_create(uuid,jsonb),
  app_private.superadmin_access_profile_model_update(uuid,jsonb),
  app_private.superadmin_access_profile_model_delete(uuid,uuid,bigint,text),
  app_private.superadmin_access_profile_model_duplicate(uuid,jsonb),
  app_private.superadmin_access_profile_models_export(text),
  app_private.superadmin_access_profile_models_import_preview(text,jsonb),
  app_private.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text),
  app_private.superadmin_access_permission_catalog()
from public,anon,authenticated,service_role;

revoke all on function
  public.superadmin_access_profile_model_detail(uuid),
  public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid),
  public.superadmin_access_profile_model_create(uuid,jsonb),
  public.superadmin_access_profile_model_update(uuid,jsonb),
  public.superadmin_access_profile_model_delete(uuid,uuid,bigint,text),
  public.superadmin_access_profile_model_duplicate(uuid,jsonb),
  public.superadmin_access_profile_models_export(text),
  public.superadmin_access_profile_models_import_preview(text,jsonb),
  public.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text),
  public.superadmin_access_permission_catalog()
from public,anon,authenticated,service_role;

grant execute on function
  public.superadmin_access_profile_model_detail(uuid),
  public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid),
  public.superadmin_access_profile_model_create(uuid,jsonb),
  public.superadmin_access_profile_model_update(uuid,jsonb),
  public.superadmin_access_profile_model_delete(uuid,uuid,bigint,text),
  public.superadmin_access_profile_model_duplicate(uuid,jsonb),
  public.superadmin_access_permission_catalog()
to authenticated;

-- 8. Persistencia dos modelos sem bypass direto (RLS ja habilitado e forcado
--    em producao; nenhuma policy depende destes grants).
revoke all on table
  public.access_profile_templates,
  public.access_profile_template_platform_permissions,
  public.access_profile_template_institution_permissions,
  public.access_profile_template_principal_capabilities
from public,anon,authenticated,service_role;

do $postflight$
declare item record; deferred boolean;
begin
  for item in
    select p.oid,p.proname,p.proowner,p.proacl,p.proconfig,n.nspname
    from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname in('public','app_private') and (
      p.proname like 'access_profile_model_%'
      or p.proname like 'superadmin_access_profile_model%'
      or p.proname in('access_profile_require_model_action',
        'access_profile_require_any_model_read','superadmin_access_permission_catalog'))
  loop
    deferred := item.proname in('superadmin_access_profile_models_export',
      'superadmin_access_profile_models_import_preview',
      'superadmin_access_profile_models_import_confirm');
    if item.proowner <> 'postgres'::regrole
      or item.proconfig is distinct from array['search_path=""']::text[]
      or exists(select 1 from pg_catalog.aclexplode(
          coalesce(item.proacl,pg_catalog.acldefault('f',item.proowner))) a
        where a.grantee <> item.proowner
          and (item.nspname <> 'public' or deferred
            or a.grantee <> 'authenticated'::regrole or a.is_grantable))
      or (item.nspname='public' and not deferred
        and not pg_catalog.has_function_privilege('authenticated',item.oid,'EXECUTE')) then
      raise exception using errcode='55000',
        message='access profile models function metadata/ACL drift: '||item.nspname||'.'||item.proname;
    end if;
  end loop;
  if not exists(select 1 from pg_catalog.pg_class
    where oid='app_private.access_profile_model_command_receipts'::regclass
      and relrowsecurity and relforcerowsecurity) then
    raise exception using errcode='55000', message='model receipts RLS required';
  end if;
  if (select count(*) from public.platform_permissions
      where screen_code='access_profile_models' and status='active') <> 18 then
    raise exception using errcode='55000', message='18 role_models permissions expected';
  end if;
  if exists(select 1 from public.platform_permissions
      where screen_code='access_profile_models' and requires_mfa) then
    raise exception using errcode='55000', message='MVP: role_models permissions must not require MFA';
  end if;
end
$postflight$;

commit;
