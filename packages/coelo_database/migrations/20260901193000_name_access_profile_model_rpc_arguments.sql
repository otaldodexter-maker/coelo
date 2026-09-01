-- PostgREST resolves RPC JSON objects by argument name. The first model CRUD
-- migration exposed the right signatures but left the public arguments unnamed.

create or replace function public.superadmin_access_profile_model_detail(
  p_model_id uuid
) returns jsonb language sql stable security definer set search_path=''
as $$select app_private.access_profile_model_detail(p_model_id,true)$$;

create or replace function public.superadmin_access_profile_models_cursor(
  p_query text,
  p_domain text,
  p_status text,
  p_scope text,
  p_limit integer,
  p_after_name text,
  p_after_id uuid
) returns jsonb language sql stable security definer set search_path=''
as $$select app_private.superadmin_access_profile_models_cursor(
  p_query,p_domain,p_status,p_scope,p_limit,p_after_name,p_after_id
)$$;

create or replace function public.superadmin_access_profile_model_create(
  p_request_id uuid,
  p_draft jsonb
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_access_profile_model_create(p_request_id,p_draft)$$;

create or replace function public.superadmin_access_profile_model_update(
  p_request_id uuid,
  p_draft jsonb
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_access_profile_model_update(p_request_id,p_draft)$$;

create or replace function public.superadmin_access_profile_model_delete(
  p_request_id uuid,
  p_model_id uuid,
  p_expected_version bigint,
  p_reason text
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_access_profile_model_delete(
  p_request_id,p_model_id,p_expected_version,p_reason
)$$;

create or replace function public.superadmin_access_profile_model_duplicate(
  p_request_id uuid,
  p_draft jsonb
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_access_profile_model_duplicate(p_request_id,p_draft)$$;

create or replace function public.superadmin_access_profile_models_export(
  p_domain text
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_access_profile_models_export(p_domain)$$;

create or replace function public.superadmin_access_profile_models_import_preview(
  p_domain text,
  p_rows jsonb
) returns jsonb language sql stable security definer set search_path=''
as $$select app_private.superadmin_access_profile_models_import_preview(p_domain,p_rows)$$;

create or replace function public.superadmin_access_profile_models_import_confirm(
  p_request_id uuid,
  p_domain text,
  p_rows jsonb,
  p_reason text
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_access_profile_models_import_confirm(
  p_request_id,p_domain,p_rows,p_reason
)$$;

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
from public,anon;

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
