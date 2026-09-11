-- 20260911170200_follow_links_safeupdate_fix_v1
-- Defeito de producao encontrado na R05 (students.link por REST, 11/09 12:55):
-- superadmin_student_link devolvia 21000 "DELETE requires a WHERE clause".
-- Causa: app_private.follow_links_sync_child_context (D1, 171100) faz
-- `delete from follow_links_expected;` na tabela temporaria sem WHERE. O pgTAP
-- passou porque psql nao carrega pg_safeupdate; nas sessoes do PostgREST
-- (authenticator) o safeupdate esta ativo e bloqueia qualquer DELETE sem WHERE,
-- mesmo dentro de funcao security definer. Efeito: toda insercao/alteracao de
-- child_unit_links e child_group_links pela API (vincular, transferir, revogar
-- aluno; cadastro de crianca) falhava desde o lote 12.
-- Correcao: `where true`. Corpo identico no resto (copiado de 171100).
-- Idempotente: create or replace.
create or replace function app_private.follow_links_sync_child_context(p_child_context_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $$
declare
  context_record record;
begin
  select ctx.id, ctx.child_person_id, ctx.institution_id, ctx.status
  into context_record
  from public.child_contexts ctx
  where ctx.id = p_child_context_id;
  if context_record.id is null then
    return;
  end if;

  create temp table if not exists follow_links_expected (
    follower_person_id uuid,
    target_kind public.follow_target_kind,
    target_id uuid,
    source_relationship public.follow_source_relationship
  ) on commit drop;
  delete from follow_links_expected where true;

  if context_record.status = 'active' then
    insert into follow_links_expected (follower_person_id, target_kind, target_id, source_relationship)
    with followers as (
      select context_record.child_person_id as person_id, 'self'::public.follow_source_relationship as relationship
      union all
      select guardian.guardian_person_id, 'guardian'::public.follow_source_relationship
      from public.guardian_links guardian
      where guardian.child_person_id = context_record.child_person_id
        and guardian.status = 'active' and guardian.revoked_at is null
    ), targets as (
      select 'institution'::public.follow_target_kind as kind, context_record.institution_id as target_id
      union all
      select 'unit', unit_link.unit_id
      from public.child_unit_links unit_link
      where unit_link.child_context_id = context_record.id
        and unit_link.status = 'active' and unit_link.revoked_at is null
      union all
      select 'group', group_link.group_id
      from public.child_group_links group_link
      join public.child_unit_links unit_link on unit_link.id = group_link.child_unit_link_id
      where unit_link.child_context_id = context_record.id
        and unit_link.status = 'active' and unit_link.revoked_at is null
        and group_link.status = 'active'
        and (group_link.starts_at is null or group_link.starts_at <= now())
        and (group_link.ends_at is null or group_link.ends_at > now())
    )
    select distinct followers.person_id, targets.kind, targets.target_id, followers.relationship
    from followers cross join targets;
  end if;

  -- Revoga o automatico deste contexto que a estrutura nao justifica mais.
  update public.follow_links link
  set status = 'inactive', revoked_at = now(), updated_at = now()
  where link.origin = 'automatic'
    and link.source_child_context_id = context_record.id
    and link.status = 'active'
    and not exists (
      select 1 from follow_links_expected expected
      where expected.follower_person_id = link.follower_person_id
        and expected.target_kind = link.target_kind
        and expected.target_id = link.target_id
        and expected.source_relationship = link.source_relationship
    );

  -- Insere o que a estrutura justifica e ainda nao existe.
  insert into public.follow_links (
    follower_person_id, target_kind, target_id, origin, source_child_context_id, source_relationship
  )
  select expected.follower_person_id, expected.target_kind, expected.target_id,
         'automatic', context_record.id, expected.source_relationship
  from follow_links_expected expected
  where not exists (
    select 1 from public.follow_links link
    where link.origin = 'automatic'
      and link.source_child_context_id = context_record.id
      and link.status = 'active'
      and link.follower_person_id = expected.follower_person_id
      and link.target_kind = expected.target_kind
      and link.target_id = expected.target_id
      and link.source_relationship = expected.source_relationship
  );
end
$$;
