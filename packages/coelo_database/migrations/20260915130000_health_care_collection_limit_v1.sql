-- R14 owner.r12-29/30: limite defensivo por perfil de cuidado.
-- Ordem candidata: depois de 20260910010400_health_care_behavior_v1.sql.
-- A migration e idempotente e permanece local ate autorizacao nominal para
-- qualquer aplicacao remota.

create or replace function app_private.health_care_collection_limit_guard()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  collection_count integer;
begin
  if tg_table_name = 'health_care_profile_items' then
    select count(*)::integer into collection_count
    from public.health_care_profile_items
    where profile_id = new.profile_id;
  elsif tg_table_name = 'health_care_allergies' then
    select count(*)::integer into collection_count
    from public.health_care_allergies
    where profile_id = new.profile_id;
  else
    raise invalid_parameter_value using message='unsupported health care collection';
  end if;

  if collection_count > 100 then
    raise check_violation using
      message='health care collection limit exceeded',
      detail='HEALTH_CARE_COLLECTION_LIMIT';
  end if;
  return new;
end
$$;

drop trigger if exists health_care_profile_items_collection_limit
  on public.health_care_profile_items;
create constraint trigger health_care_profile_items_collection_limit
after insert or update of profile_id on public.health_care_profile_items
deferrable initially immediate
for each row execute function app_private.health_care_collection_limit_guard();

drop trigger if exists health_care_allergies_collection_limit
  on public.health_care_allergies;
create constraint trigger health_care_allergies_collection_limit
after insert or update of profile_id on public.health_care_allergies
deferrable initially immediate
for each row execute function app_private.health_care_collection_limit_guard();

revoke all on function app_private.health_care_collection_limit_guard() from public, anon, authenticated;
