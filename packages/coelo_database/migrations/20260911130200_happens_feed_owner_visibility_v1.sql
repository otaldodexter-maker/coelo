-- Rodada 5 (E2-R05-20260911), principal-chat-sistema. Medido na rota real as
-- 14:45: qa-r03 (membership role_code 'owner', lote 27) publica no Acontece
-- (save_happens_draft + publish_happens_post 200) mas list_visible_happens_feed
-- devolve [] porque app_private.circular_feed_post_visible so reconhece os
-- papeis guardian/student/professional/institution_admin/unit_admin/teacher/
-- coordinator; 'owner' cai em 'else false'. Regra do Owner (P35): o Superadmin
-- (e o owner da instituicao) ve tudo. Tambem inclui 'secretary' (papel de
-- sistema do P31) no ramo de equipe escolar.
-- Forward-only: create or replace da funcao existente, mesma assinatura, mesmos
-- grants (app_private, sem execute a cliente).

begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $$
begin
  if to_regprocedure('app_private.circular_feed_post_visible(public.posts,uuid,text,uuid,uuid)') is null then
    raise exception 'happens_feed_owner_visibility_v1: circular_feed_post_visible ausente';
  end if;
end $$;

CREATE OR REPLACE FUNCTION "app_private"."circular_feed_post_visible"("p_post" "public"."posts", "p_person_id" "uuid", "p_role" "text", "p_unit_id" "uuid", "p_group_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select p_post.status in ('scheduled','published') and p_post.publish_at<=now()
    and (p_post.unit_id is null or p_post.unit_id=p_unit_id)
    and (p_post.group_id is null or p_post.group_id=p_group_id)
    and exists (
      select 1 from public.post_audiences audience
      where audience.post_id=p_post.id and audience.institution_id=p_post.institution_id
        and audience.unit_id is not distinct from p_post.unit_id
        and audience.group_id is not distinct from p_post.group_id
        and case
          when lower(coalesce(p_role,'')) in ('guardian','responsible','responsavel','parent','family') then
            audience.audience_kind in ('families','guardians_only') and exists (
              select 1
              from public.guardian_links guardian
              join public.guardian_context_permissions permission on permission.guardian_link_id=guardian.id
              join public.child_contexts child on child.id=permission.child_context_id
              where guardian.guardian_person_id=p_person_id
                and guardian.status='active' and guardian.revoked_at is null
                and permission.status='active' and permission.can_view
                and (permission.starts_at is null or permission.starts_at<=now())
                and (permission.expires_at is null or permission.expires_at>now())
                and child.institution_id=p_post.institution_id and child.status='active'
                and (p_post.unit_id is null or exists (
                  select 1 from public.child_unit_links child_unit
                  where child_unit.child_context_id=child.id and child_unit.unit_id=p_post.unit_id
                    and child_unit.status='active' and child_unit.revoked_at is null
                    and (p_post.group_id is null or exists (
                      select 1 from public.child_group_links child_group
                      where child_group.child_unit_link_id=child_unit.id and child_group.group_id=p_post.group_id
                        and child_group.status='active'
                        and (child_group.starts_at is null or child_group.starts_at<=now())
                        and (child_group.ends_at is null or child_group.ends_at>now())
                    ))
                ))
            )
          when lower(coalesce(p_role,'')) in ('student','aluno') then
            audience.audience_kind='students' and exists (
              select 1 from public.child_contexts child
              where child.child_person_id=p_person_id and child.institution_id=p_post.institution_id and child.status='active'
                and (p_post.unit_id is null or exists (
                  select 1 from public.child_unit_links child_unit
                  where child_unit.child_context_id=child.id and child_unit.unit_id=p_post.unit_id
                    and child_unit.status='active' and child_unit.revoked_at is null
                    and (p_post.group_id is null or exists (
                      select 1 from public.child_group_links child_group
                      where child_group.child_unit_link_id=child_unit.id and child_group.group_id=p_post.group_id
                        and child_group.status='active'
                        and (child_group.starts_at is null or child_group.starts_at<=now())
                        and (child_group.ends_at is null or child_group.ends_at>now())
                    ))
                ))
            )
          -- P35 (Owner, 11/09/2026): owner da instituicao (e o espelho do
          -- Superadmin, que recebe esse papel) ve tudo que foi publicado no
          -- escopo, qualquer que seja o publico.
          when lower(coalesce(p_role,''))='owner' then true
          when lower(coalesce(p_role,'')) in ('professional','institution_admin','unit_admin','teacher','coordinator','secretary') then
            audience.audience_kind='school_staff'
          else false
        end
    )
$$;

revoke all on function app_private.circular_feed_post_visible(public.posts,uuid,text,uuid,uuid) from public, anon, authenticated;

commit;
