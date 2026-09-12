-- Invariante final de question-image: todo uso encerrado por status deleted
-- solta o binding do item, inclusive mismatch, expiracao e caminhos futuros.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
declare
  authorize_definition text;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'forms question media terminal unbind must run as postgres';
  end if;
  if to_regprocedure('public.superadmin_form_media_authorize_finalize_v2(uuid)') is null
    or to_regclass('public.media_assets') is null
    or to_regclass('public.media_bindings') is null then
    raise object_not_in_prerequisite_state using
      message = 'forms question media retry/delete 140548 is required';
  end if;
  select pg_catalog.pg_get_functiondef(
    'public.superadmin_form_media_authorize_finalize_v2(uuid)'::regprocedure
  ) into authorize_definition;
  if authorize_definition !~ '''replayed''' or authorize_definition !~ 'asset.status = ''ready''' then
    raise object_not_in_prerequisite_state using
      message = 'forms question media retry/delete 140548 must be applied first';
  end if;
end
$preflight$;

create or replace function app_private.form_media_unbind_deleted_question_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.media_bindings binding
  where binding.media_asset_id = new.id
    and binding.purpose = 'question-image';
  return new;
end;
$$;

drop trigger if exists form_media_unbind_deleted_question_v1 on public.media_assets;
create trigger form_media_unbind_deleted_question_v1
after update of status on public.media_assets
for each row
when (
  old.status is distinct from new.status
  and new.status = 'deleted'
  and new.catalog_kind = 'form-image'
  and new.media_purpose = 'question-image'
)
execute function app_private.form_media_unbind_deleted_question_v1();

alter function app_private.form_media_unbind_deleted_question_v1() owner to postgres;
revoke all on function app_private.form_media_unbind_deleted_question_v1()
  from public,anon,authenticated,service_role;

-- Cura somente usos que ja estao logicamente encerrados. Assets, variantes,
-- tickets, cleanup e auditoria permanecem intactos.
delete from public.media_bindings binding
using public.media_assets asset
where binding.media_asset_id = asset.id
  and binding.purpose = 'question-image'
  and asset.catalog_kind = 'form-image'
  and asset.media_purpose = 'question-image'
  and asset.status = 'deleted';

commit;
