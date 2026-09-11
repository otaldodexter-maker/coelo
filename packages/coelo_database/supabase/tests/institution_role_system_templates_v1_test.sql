-- Prova do candidato 20260910171600_institution_role_system_templates_v1 (RETIDO ate P31).
-- Projeto descartavel LOCAL: transacao com rollback.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

select ok(app_private.seed_institution_role_system_templates() >= 0, 'a semente roda');
select is((select count(*) from public.institution_roles where institution_id is null and is_system and code in ('institution_admin','coordinator','teacher','secretary')), 4::bigint,
  'quatro papeis de sistema existem');
select is((select count(*) from public.institution_role_permissions rp join public.institution_roles r on r.id=rp.role_id where r.code='institution_admin' and r.is_system and rp.status='active'),
  (select count(*) from public.institution_permissions where status='active'),
  'administrador recebe todas as permissoes institucionais ativas');
select ok((select count(*) from public.institution_role_permissions rp join public.institution_roles r on r.id=rp.role_id where r.code='teacher' and r.is_system and rp.status='active')
  < (select count(*) from public.institution_role_permissions rp join public.institution_roles r on r.id=rp.role_id where r.code='coordinator' and r.is_system and rp.status='active'),
  'professor tem menos permissoes que coordenacao');
select ok(not exists (select 1 from public.institution_role_permissions rp join public.institution_roles r on r.id=rp.role_id join public.institution_permissions p on p.id=rp.permission_id
  where r.code='teacher' and r.is_system and p.code in ('people.manage','permissions.manage','transfers.manage')),
  'professor nao gerencia pessoas, permissoes nem transferencias');
select is(app_private.seed_institution_role_system_templates(), 0, 'rodar de novo nao concede nada a mais (idempotente)');
select ok(not has_function_privilege('anon','app_private.seed_institution_role_system_templates()','execute')
  and not has_function_privilege('authenticated','app_private.seed_institution_role_system_templates()','execute'),
  'semente fora do alcance de anon e authenticated');

select * from finish();
rollback;
