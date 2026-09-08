-- LOCAL REPLAY BOOTSTRAP ONLY. NOT a production migration or seed.
-- Replay owner opts in on the same connection before this file:
-- SET coelo.local_replay = 'location-catalog-v2';
-- Run after dependencies and BEFORE the candidate migration; dispose the local DB after testing.
begin;
set local coelo.local_replay = 'location-catalog-v2';
do $$
begin
  if current_user<>'postgres' or current_setting('coelo.local_replay',true)
      is distinct from 'location-catalog-v2' then
    raise insufficient_privilege using message='explicit local location replay selection required';
  end if;
  if exists(select 1 from public.platform_permissions where code in('locations.read','locations.create'))
    or not exists(select 1 from public.platform_roles where code='owner' and status='active') then
    raise object_not_in_prerequisite_state using message='local location capability fixture requires clean nominal matrix';
  end if;
end
$$;
insert into public.platform_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa,status
) values
  ('locations.read','locations','Locais','directory','Catálogo','read','Ver',
    'LOCAL FIXTURE location read','normal',false,'active'),
  ('locations.create','locations','Locais','management','Catálogo','create','Criar',
    'LOCAL FIXTURE location create','high',false,'active');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
  select r.id,p.id,'allow','active' from public.platform_roles r
  cross join public.platform_permissions p where r.code='owner' and r.status='active'
    and p.code in('locations.read','locations.create');
commit;
