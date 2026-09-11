begin;
select plan(2);
-- No espelho local nao existe ator interno nem instituicao sintetica; a migration precisa ser inerte.
select lives_ok($$
  insert into public.institution_memberships (person_id, institution_id, role_code, status, scope_kind)
  select actor.person_id, inst.id, 'owner', 'active', 'institution'
  from app_private.superadmin_internal_actor_people actor
  cross join public.institutions inst
  where inst.slug in ('qa-r04-chat')
    and not exists (select 1 from public.institution_memberships m where m.person_id = actor.person_id and m.institution_id = inst.id and m.status = 'active')
$$, 'insercao idempotente executa sem erro');
select is((select count(*)::int from public.institution_memberships m where m.role_code = 'owner' and not exists (select 1 from public.institutions i where i.id = m.institution_id)), 0, 'nenhuma membership orfa');
select * from finish();
rollback;
