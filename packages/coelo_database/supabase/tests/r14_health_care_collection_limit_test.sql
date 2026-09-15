-- R14 owner.r12-29/30: colecoes independentes de cuidado com teto defensivo.
-- A fixture e descartavel: nenhuma pessoa, vinculo ou dado de producao e usado.
begin;

create extension if not exists pgtap with schema extensions;

select plan(6);

insert into public.people(id,person_type,first_name,last_name,display_name)
values
  ('c0e10000-0000-4000-8000-000000000001','adult','Coelo','System','Coelo System'),
  ('30000000-0000-4000-8000-000000000001','adult','R14','Actor','R14 Actor'),
  ('30000000-0000-4000-8000-000000000002','child','R14','Child','R14 Child');
insert into public.institutions(id,public_name,slug,status)
values ('30000000-0000-4000-8000-000000000003','R14 Health Fixture','r14-health-fixture','active');
insert into public.child_contexts(id,child_person_id,institution_id,status)
values ('30000000-0000-4000-8000-000000000004',
  '30000000-0000-4000-8000-000000000002',
  '30000000-0000-4000-8000-000000000003','active');
insert into public.health_care_profiles(
  id,institution_id,child_context_id,created_by_person_id)
values ('30000000-0000-4000-8000-000000000005',
  '30000000-0000-4000-8000-000000000003',
  '30000000-0000-4000-8000-000000000004',
  '30000000-0000-4000-8000-000000000001');

insert into public.health_care_profile_items(profile_id,catalog_item_id)
select '30000000-0000-4000-8000-000000000005', 'r14_guidance_'||n
from generate_series(1,100) as series(n);
select is(
  (select count(*)::integer from public.health_care_profile_items
   where profile_id='30000000-0000-4000-8000-000000000005'),
  100,
  'orientacoes aceitam mais de dois registros independentes'
);
select throws_ok(
  $$insert into public.health_care_profile_items(profile_id,catalog_item_id)
    values ('30000000-0000-4000-8000-000000000005','r14_guidance_101')$$,
  '23514',
  null,
  'backend rejeita a orientacao 101'
);
select is(
  (select count(*)::integer from public.health_care_profile_items
   where profile_id='30000000-0000-4000-8000-000000000005'),
  100,
  'rejeicao da orientacao 101 nao deixa residuo'
);

insert into public.health_care_allergies(
  profile_id,label,allergy_type,created_by_person_id)
select '30000000-0000-4000-8000-000000000005', 'R14 Allergy '||n,
  'other','30000000-0000-4000-8000-000000000001'
from generate_series(1,100) as series(n);
select is(
  (select count(*)::integer from public.health_care_allergies
   where profile_id='30000000-0000-4000-8000-000000000005'),
  100,
  'alergias aceitam mais de dois registros independentes'
);
select throws_ok(
  $$insert into public.health_care_allergies(
    profile_id,label,allergy_type,created_by_person_id)
    values ('30000000-0000-4000-8000-000000000005','R14 Allergy 101',
      'other','30000000-0000-4000-8000-000000000001')$$,
  '23514',
  null,
  'backend rejeita a alergia 101'
);
select is(
  (select count(*)::integer from public.health_care_allergies
   where profile_id='30000000-0000-4000-8000-000000000005'),
  100,
  'rejeicao da alergia 101 nao deixa residuo'
);

select * from finish();
rollback;
