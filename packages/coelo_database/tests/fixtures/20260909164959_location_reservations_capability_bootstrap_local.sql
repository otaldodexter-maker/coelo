-- LOCAL REPLAY BOOTSTRAP ONLY. NOT a production migration or seed.
-- This file runs only in the disposable LocationReservationsV1 profile.
begin;
set local coelo.local_replay = 'location-reservations-v1';
do $$
declare
  required_codes constant text[] := array[
    'locations.reservations.read',
    'locations.reservations.manage',
    'locations.reservations.override'
  ];
begin
  if current_user <> 'postgres'
     or current_setting('coelo.local_replay', true) is distinct from 'location-reservations-v1' then
    raise insufficient_privilege using message='explicit local reservation replay selection required';
  end if;
  if exists(select 1 from public.platform_permissions where code = any(required_codes))
     or not exists(select 1 from public.platform_roles where code='owner' and status='active') then
    raise object_not_in_prerequisite_state using message='local reservation capability fixture requires clean nominal matrix';
  end if;
end
$$;
insert into public.platform_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa,status
) values
  ('locations.reservations.read','locations','Locais','reservations','Reservas','read','Ver',
    'LOCAL FIXTURE location reservation read','normal',false,'active'),
  ('locations.reservations.manage','locations','Locais','reservations','Reservas','manage','Gerenciar',
    'LOCAL FIXTURE location reservation management','high',false,'active'),
  ('locations.reservations.override','locations','Locais','reservations','Reservas','override','Confirmar conflito',
    'LOCAL FIXTURE location reservation conflict override','critical',false,'active');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id, permission.id, 'allow', 'active'
from public.platform_roles role_record
cross join public.platform_permissions permission
where role_record.code='owner' and role_record.status='active'
  and permission.code = any(array[
    'locations.reservations.read',
    'locations.reservations.manage',
    'locations.reservations.override'
  ]);
commit;
