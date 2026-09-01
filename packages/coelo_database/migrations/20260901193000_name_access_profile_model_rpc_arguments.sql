-- PostgREST resolves RPC JSON objects by argument name. The first model CRUD
-- migration exposed the right signatures but left the public arguments unnamed.

begin;

create or replace function public.superadmin_access_profile_model_detail(
  p_model_id uuid
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('detail',
  pg_catalog.jsonb_build_object('model_id',p_model_id))$$;

create or replace function public.superadmin_access_profile_models_cursor(
  p_query text,
  p_domain text,
  p_status text,
  p_scope text,
  p_limit integer,
  p_after_name text,
  p_after_id uuid
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

revoke all on function
  public.superadmin_access_profile_model_detail(uuid),
  public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid),
  public.superadmin_access_profile_model_create(uuid,jsonb),
  public.superadmin_access_profile_model_update(uuid,jsonb),
  public.superadmin_access_profile_model_delete(uuid,uuid,bigint,text),
  public.superadmin_access_profile_model_duplicate(uuid,jsonb),
  public.superadmin_access_profile_models_export(text),
  public.superadmin_access_profile_models_import_preview(text,jsonb),
  public.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text)
from public,anon,service_role;

grant execute on function
  public.superadmin_access_profile_model_detail(uuid),
  public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid),
  public.superadmin_access_profile_model_create(uuid,jsonb),
  public.superadmin_access_profile_model_update(uuid,jsonb),
  public.superadmin_access_profile_model_delete(uuid,uuid,bigint,text),
  public.superadmin_access_profile_model_duplicate(uuid,jsonb),
  public.superadmin_access_profile_models_export(text),
  public.superadmin_access_profile_models_import_preview(text,jsonb),
  public.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text)
to authenticated;

commit;
