-- LOCAL REPLAY BOOTSTRAP ONLY. NOT a production migration or seed.
-- This file runs only in the disposable LocationCatalogV2 nominal profile.
begin;
set local coelo.local_replay = 'location-catalog-v2';
do $$
declare
  required_codes constant text[] := array[
    'locations.read', 'locations.create', 'locations.update',
    'locations.status', 'locations.copy', 'locations.schedule'
  ];
begin
  if current_user <> 'postgres'
     or current_setting('coelo.local_replay', true) is distinct from 'location-catalog-v2' then
    raise insufficient_privilege using message='explicit local location replay selection required';
  end if;
  if exists(select 1 from public.platform_permissions where code = any(required_codes))
     or not exists(select 1 from public.platform_roles where code='owner' and status='active') then
    raise object_not_in_prerequisite_state using message='local location capability fixture requires clean nominal matrix';
  end if;
end
$$;
insert into public.platform_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa,status
) values
  ('locations.read','locations','Locais','directory','Catálogo','read','Ver','LOCAL FIXTURE location read','normal',false,'active'),
  ('locations.create','locations','Locais','management','Catálogo','create','Criar','LOCAL FIXTURE location create','high',false,'active'),
  ('locations.update','locations','Locais','management','Catálogo','update','Editar','LOCAL FIXTURE location update','high',false,'active'),
  ('locations.status','locations','Locais','management','Catálogo','status','Alterar status','LOCAL FIXTURE location status','high',false,'active'),
  ('locations.copy','locations','Locais','management','Catálogo','copy','Copiar','LOCAL FIXTURE location copy','high',false,'active'),
  ('locations.schedule','locations','Locais','schedule','Disponibilidade','schedule','Editar disponibilidade','LOCAL FIXTURE location schedule','high',false,'active');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id, permission.id, 'allow', 'active'
from public.platform_roles role_record
cross join public.platform_permissions permission
where role_record.code='owner' and role_record.status='active'
  and permission.code = any(array[
    'locations.read', 'locations.create', 'locations.update',
    'locations.status', 'locations.copy', 'locations.schedule'
  ]);
commit;
