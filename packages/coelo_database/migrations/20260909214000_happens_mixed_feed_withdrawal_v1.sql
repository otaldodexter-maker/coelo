-- Feed misto do Acontece coerente com a retirada de publicacao.
--
-- `20260909133000_happens_post_withdrawal_v1.sql` introduziu a retirada soft e
-- ensinou `list_visible_happens_posts` a esconder publicacoes retiradas e a
-- projetar identidade, versao e autorizacao. O feed misto de
-- `20260821190000_circulars_production.sql`, que une publicacoes e Circulares,
-- ficou sem essas duas coisas: continuaria mostrando publicacoes ja retiradas e
-- nao ofereceria a retirada ao autor.
--
-- Este delta so alinha essa funcao. A assinatura NAO muda: identidade e versao
-- entram dentro do `payload` jsonb do item de post, que ja e um objeto aberto, e
-- o `item_id` da linha ja e o id da publicacao. Por isso basta `create or
-- replace`, sem drop e sem alterar grants.
--
-- Forward-only. Corpo copiado fielmente do original; as unicas diferencas sao o
-- predicado de retirada e os dois campos novos no payload de post.
--
-- `can_withdraw` confere autoria E a capacidade `happens.posts.remove` no
-- escopo, igual ao feed direto: oferecer a acao a quem o servidor negaria seria
-- uma promessa falsa na interface.

create or replace function public.list_visible_happens_feed(
  p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_activity_id uuid,p_before_at timestamptz,p_before_type text,p_before_id uuid,p_limit integer default 20
) returns table(item_type text,item_id uuid,effective_published_at timestamptz,payload jsonb)
language plpgsql security definer set search_path='' as $$
declare actor record; actor_role text;
begin
  select * into actor from app_private.happens_actor(p_institution_id,'happens.posts.read',p_unit_id,p_group_id);
  select lower(m.role_code) into actor_role from public.institution_memberships m where m.id=actor.membership_id;
  delete from app_private.happens_media_read_tickets ticket where ticket.expires_at<=now();
  return query
  with authorized_items as (
    select 'post'::text as kind,post.id,coalesce(post.published_at,post.publish_at) as at,
      jsonb_build_object('author_name',person.display_name,'author_initials',upper(left(person.display_name,1)),'context_label',coalesce(g.name,u.name,i.public_name),'caption',post.caption,'management_version',post.management_version,'can_withdraw',post.author_person_id=actor.person_id and app_private.has_institution_permission(p_institution_id,'happens.posts.remove',p_unit_id,p_group_id,false),'media',app_private.circular_feed_post_media(post.id,actor.person_id)) as body
    from public.posts post join public.people person on person.id=post.author_person_id join public.institutions i on i.id=post.institution_id
    left join public.units u on u.id=post.unit_id left join public.groups g on g.id=post.group_id
    where post.institution_id=p_institution_id
      and post.withdrawn_at is null
      and app_private.circular_feed_post_visible(post,actor.person_id,actor_role,p_unit_id,p_group_id)
    union all
    select 'circular',c.id,c.publish_at,jsonb_build_object('author_name',person.display_name,'author_initials',upper(left(person.display_name,1)),'context_label',coalesce(g.name,u.name,i.public_name),
      'title',r.title,'excerpt',left(r.body_text,420),'revised_at',c.revised_at,'attachment_count',(select count(*) from public.circular_media_links ml where ml.revision_id=r.id),
      'question_count',(select count(*) from public.circular_questions q where q.revision_id=r.id),'response_state',case when exists(select 1 from public.circular_response_sessions s where s.revision_id=r.id and s.last_actor_person_id=actor.person_id and s.status='submitted') then 'answered' when exists(select 1 from public.circular_response_sessions s where s.revision_id=r.id and s.last_actor_person_id=actor.person_id) then 'partial' else 'unanswered' end)
    from public.circulars c join public.circular_revisions r on r.id=c.current_revision_id join public.people person on person.id=c.author_person_id join public.institutions i on i.id=c.institution_id
    left join public.units u on u.id=c.unit_id left join public.groups g on g.id=c.group_id
    where c.institution_id=p_institution_id
      and app_private.has_institution_permission(c.institution_id,'circulars.circulars.read',c.unit_id,c.group_id,false)
      and app_private.circular_visible(c,actor.person_id,actor_role,p_unit_id,p_group_id,p_activity_id)
  )
  select source.kind,source.id,source.at,source.body from authorized_items source
  where p_before_at is null or (source.at,source.kind,source.id)<(p_before_at,coalesce(p_before_type,'zz'),p_before_id)
  order by source.at desc,source.kind desc,source.id desc limit least(greatest(coalesce(p_limit,20),1),50);
end $$;
