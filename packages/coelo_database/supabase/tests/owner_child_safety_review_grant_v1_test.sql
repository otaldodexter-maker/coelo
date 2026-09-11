-- Prova do candidato 20260910172000_owner_child_safety_review_grant_v1.
-- Projeto descartavel LOCAL: transacao com rollback.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

select is((select count(*) from public.platform_permissions p where p.status='active' and not exists (
  select 1 from public.platform_role_permissions g join public.platform_roles r on r.id=g.role_id
  where r.code='owner' and g.permission_id=p.id and g.status='active' and g.revoked_at is null and g.effect='allow')), 0::bigint,
  'owner concede todas as permissoes de plataforma ativas (inclusive child_safety.review)');

-- Membership de plataforma do Owner com mfa_required (como a linha de producao): a guarda passa.
insert into public.people(id,person_type,first_name,last_name,display_name)
values('a2000000-0000-4000-8000-000000000001','adult','Owner','Sintetico','Owner sintetico');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select 'a2000000-0000-4000-8000-000000000001', id, 'active', 'platform', true from public.platform_roles where code='owner';
select lives_ok($$select app_private.assert_full_authority_remains()$$,
  'guarda de autoridade plena passa com o Owner completo');

-- Sem nenhuma membership de autoridade plena, a guarda continua negando.
update public.platform_memberships set status='revoked', revoked_at=now() where status='active' and scope_kind='platform';
select throws_ok($$select app_private.assert_full_authority_remains()$$, '23514',
  'active full-authority MFA replacement required', 'guarda continua fail-closed sem autoridade plena');

select ok(not has_function_privilege('anon','app_private.assert_full_authority_remains()','execute'),
  'guarda fora do alcance de anon');

select * from finish();
rollback;
