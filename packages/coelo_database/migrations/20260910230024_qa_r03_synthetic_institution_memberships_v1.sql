-- Rodada 4 (E2-R04-20260911), P35 "A agora" decidido pelo Owner em 11/09/2026.
-- A pessoa de servico do usuario interno de teste (ponte de ator 220400) recebe
-- membership owner ativa nas instituicoes sinteticas de QA, para que o menu
-- Coelo (Principal) enxergue conteudo com o mesmo usuario usado nas provas.
-- Nao contem segredo nem e-mail: resolve a pessoa pela ponte interna.
-- Idempotente: nao duplica membership ativa existente.

insert into public.institution_memberships (person_id, institution_id, role_code, status, scope_kind)
select actor.person_id, inst.id, 'owner', 'active', 'institution'
from app_private.superadmin_internal_actor_people actor
join app_private.superadmin_internal_auth_links link
  on link.internal_identity_id = actor.internal_identity_id and link.status = 'active'
cross join public.institutions inst
where inst.deleted_at is null
  and inst.slug in ('qa-r04-chat', 'qa-r04-cuidado-sintetico', 'qa-r04-escola')
  and not exists (
    select 1 from public.institution_memberships m
    where m.person_id = actor.person_id and m.institution_id = inst.id
      and m.status = 'active' and m.revoked_at is null
  );
