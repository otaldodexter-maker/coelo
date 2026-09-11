-- Acontece: retirada soft de publicacao (action_id acontece.remove) sobre a
-- baseline. Junta as historicas 20260909213000_happens_post_withdrawal_v1
-- (withdraw_happens_post e feed direto: em producao so o feed direto existe,
-- SEM as colunas de retirada, medido 1/2) e 20260909214000
-- _happens_mixed_feed_withdrawal_v1 (feed misto, presente em producao 1/1 mas
-- SEM o predicado de retirada nem can_withdraw: a presenca do nome nao provou o
-- corpo). Corpos fieis aos originais. O feed direto 4 argumentos e recriado com
-- post_id, management_version e can_withdraw; o feed misto ganha o predicado
-- withdrawn_at is null e os dois campos no payload, que o cliente ja le.
-- Retirada de publicacao do Acontece (action_id acontece.remove).
--
-- A rodada anterior registrou que o cliente estava fail-closed porque nao havia
-- contrato de servidor: nenhuma RPC de retirada, nenhuma capacidade catalogada
-- e nenhuma projecao de identidade no feed. Esta migration fecha esse contrato.
--
-- A retirada e SOFT por decisao de escopo: nao apaga linha, nao apaga midia e
-- nao altera retencao. Marca autor, horario e motivo opcional, registra
-- auditoria e some do feed. Nao existe hard delete nesta superficie.
--
-- Forward-only. `list_visible_happens_posts` muda o tipo de retorno, entao
-- precisa de drop + create; os grants originais sao reaplicados no fim.
--
-- Revisao apos revisao do coordenador, antes de qualquer aplicacao:
--  * a versao esperada e obrigatoria. Comparar com `<>` deixava um
--    `p_expected_version` nulo devolver NULL e escapar da guarda, dispensando o
--    lock otimista sem dizer. Agora nulo e conflito, e a comparacao usa
--    `is distinct from`.
--  * `can_withdraw` confere tambem a capacidade `happens.posts.remove` no
--    escopo, e nao so a autoria. Sem isso o feed oferecia ao autor uma acao que
--    o servidor negaria logo em seguida.
--  * a negacao de `withdraw_happens_post` e UNIFICADA. Antes, um post
--    inexistente levantava `no_data_found:post_not_found` ANTES de chamar
--    `happens_actor`, e um post alheio levantava
--    `insufficient_privilege:happens_permission_denied` depois. Um ator
--    autenticado distinguia "nao existe" de "existe e nao e seu", inclusive
--    atravessando tenant: informacao entregue antes da autorizacao. Agora os
--    dois casos usam a MESMA classe e a MESMA mensagem, como `withdraw_moment`
--    e `circulars_production` ja faziam. Nao reintroduzir a granularidade: a
--    suite tem uma assercao dedicada a essa igualdade.

alter table public.posts
  add column if not exists withdrawn_at timestamptz,
  add column if not exists withdrawn_by_person_id uuid references public.people(id),
  add column if not exists withdrawal_reason text;

alter table public.posts
  drop constraint if exists posts_withdrawal_reason_ck;
alter table public.posts
  add constraint posts_withdrawal_reason_ck
  check (withdrawal_reason is null or char_length(withdrawal_reason) <= 280);

alter table public.posts
  drop constraint if exists posts_withdrawal_shape_ck;
alter table public.posts
  add constraint posts_withdrawal_shape_ck
  check (
    withdrawn_at is null
    or (status in ('scheduled','published') and withdrawn_by_person_id is not null)
  );

create index if not exists posts_withdrawn_idx
  on public.posts(institution_id, withdrawn_at desc)
  where withdrawn_at is not null;

insert into public.institution_permissions(
  code,module_code,screen_code,action_code,description,status,
  module_label,screen_label,action_label
)
values
 ('happens.posts.remove','happens','posts','remove','Retirar do feed uma publicacao propria ja publicada ou agendada.','active','Acontece','Publicacoes','Remover')
on conflict(code) do update set
  module_code=excluded.module_code,
  screen_code=excluded.screen_code,
  action_code=excluded.action_code,
  description=excluded.description,
  status='active',
  module_label=excluded.module_label,
  screen_label=excluded.screen_label,
  action_label=excluded.action_label;

create or replace function public.withdraw_happens_post(
  p_request_id uuid,
  p_post_id uuid,
  p_expected_version bigint,
  p_reason text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  target public.posts%rowtype;
  actor record;
  normalized_reason text;
begin
  select * into target from public.posts where id=p_post_id for update;
  -- A negacao e unificada DE PROPOSITO. Quem nao pode retirar recebe a mesma
  -- classe de erro e a mesma mensagem para "nao existe" e para "existe e nao e
  -- seu". Distinguir os dois entregaria informacao antes da autorizacao e daria
  -- ao ator autenticado um oraculo de existencia, inclusive atravessando tenant.
  -- E o mesmo que withdraw_moment e circulars_production fazem. Nao "restaurar"
  -- a granularidade achando que se perdeu qualidade de erro.
  if not found then
    raise insufficient_privilege using message='happens_permission_denied';
  end if;

  select * into actor from app_private.happens_actor(
    target.institution_id,'happens.posts.remove',target.unit_id,target.group_id);

  if target.author_person_id<>actor.person_id then
    raise insufficient_privilege using message='happens_permission_denied';
  end if;

  if target.withdrawn_at is not null then
    return jsonb_build_object(
      'id',target.id,
      'status',target.status,
      'withdrawn_at',target.withdrawn_at,
      'management_version',target.management_version
    );
  end if;

  if p_expected_version is null or target.management_version is distinct from p_expected_version then
    raise serialization_failure using message='expected_version_conflict';
  end if;

  if target.status='draft' then
    raise check_violation using message='post_not_published';
  end if;

  normalized_reason:=nullif(btrim(coalesce(p_reason,'')),'');
  if normalized_reason is not null and char_length(normalized_reason)>280 then
    raise check_violation using message='reason_too_long';
  end if;

  update public.posts
  set withdrawn_at=now(),
      withdrawn_by_person_id=actor.person_id,
      withdrawal_reason=normalized_reason,
      management_version=management_version+1,
      updated_at=now()
  where id=target.id
  returning * into target;

  insert into app_private.happens_publication_audit(
    post_id,institution_id,actor_person_id,event_code,detail)
  values(
    target.id,target.institution_id,actor.person_id,'post_withdrawn',
    jsonb_build_object('request_id',p_request_id,'reason',normalized_reason));

  return jsonb_build_object(
    'id',target.id,
    'status',target.status,
    'withdrawn_at',target.withdrawn_at,
    'management_version',target.management_version
  );
end $$;

drop function if exists public.list_visible_happens_posts(uuid,uuid,uuid,integer);

create function public.list_visible_happens_posts(p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_limit integer default 20)
returns table(
  post_id uuid,
  author_name text,
  author_initials text,
  context_label text,
  caption text,
  published_at timestamptz,
  management_version bigint,
  can_withdraw boolean,
  media jsonb
) language plpgsql security definer set search_path='' as $$
declare
  actor record;
  actor_role text;
  visible_post record;
  visible_media record;
  media_items jsonb;
  read_ticket uuid;
begin
  select * into actor from app_private.happens_actor(p_institution_id,'happens.posts.read',p_unit_id,p_group_id);
  select lower(membership.role_code) into actor_role
  from public.institution_memberships membership
  where membership.id=actor.membership_id;

  delete from app_private.happens_media_read_tickets ticket
  where ticket.expires_at<=now();

  for visible_post in
    select
      post.id,
      post.author_person_id,
      post.management_version as resolved_version,
      person.display_name,
      coalesce(scoped_group.name,scoped_unit.name,institution.public_name) as resolved_context,
      post.caption,
      coalesce(post.published_at,post.publish_at) as resolved_published_at
    from public.posts post
    join public.people person on person.id=post.author_person_id
    join public.institutions institution on institution.id=post.institution_id
    left join public.units scoped_unit on scoped_unit.id=post.unit_id
    left join public.groups scoped_group on scoped_group.id=post.group_id
    where post.institution_id=p_institution_id
      and post.status in('scheduled','published')
      and post.withdrawn_at is null
      and post.publish_at<=now()
      and (post.unit_id is null or post.unit_id=p_unit_id)
      and (post.group_id is null or post.group_id=p_group_id)
      and exists(
        select 1
        from public.post_audiences audience
        where audience.post_id=post.id
          and audience.institution_id=p_institution_id
          and audience.unit_id is not distinct from post.unit_id
          and audience.group_id is not distinct from post.group_id
          and app_private.happens_audience_matches_role(actor_role,audience.audience_kind)
      )
    order by post.publish_at desc,post.id
    limit least(greatest(coalesce(p_limit,20),1),50)
  loop
    media_items:='[]'::jsonb;
    for visible_media in
      select asset.id,asset.mime_type,link.display_order
      from public.media_links link
      join public.media_assets asset on asset.id=link.media_asset_id
      where link.post_id=visible_post.id and asset.status='ready'
      order by link.display_order
    loop
      insert into app_private.happens_media_read_tickets(media_asset_id,viewer_person_id)
      values(visible_media.id,actor.person_id)
      returning token into read_ticket;
      media_items:=media_items||jsonb_build_array(jsonb_build_object(
        'read_ticket',read_ticket,
        'mime_type',visible_media.mime_type,
        'display_order',visible_media.display_order
      ));
    end loop;

    post_id:=visible_post.id;
    author_name:=visible_post.display_name;
    author_initials:=upper(left(visible_post.display_name,1));
    context_label:=visible_post.resolved_context;
    caption:=visible_post.caption;
    published_at:=visible_post.resolved_published_at;
    management_version:=visible_post.resolved_version;
    can_withdraw:=visible_post.author_person_id=actor.person_id
      and app_private.has_institution_permission(
        p_institution_id,'happens.posts.remove',p_unit_id,p_group_id,false);
    media:=media_items;
    return next;
  end loop;
end
$$;

revoke all on function
  public.withdraw_happens_post(uuid,uuid,bigint,text),
  public.list_visible_happens_posts(uuid,uuid,uuid,integer)
  from public,anon,authenticated;
grant execute on function
  public.withdraw_happens_post(uuid,uuid,bigint,text),
  public.list_visible_happens_posts(uuid,uuid,uuid,integer)
  to authenticated;

-- ---- feed misto (historica 20260909214000) ----
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

-- Medido na baseline de producao: anon tinha EXECUTE no feed misto. O feed e
-- security definer e exige sessao (happens_actor); o grant a anon nao servia
-- a ninguem e amplia a superficie. Revogado aqui; authenticated preservado.
revoke all on function public.list_visible_happens_feed(uuid,uuid,uuid,uuid,timestamptz,text,uuid,integer) from public,anon;
grant execute on function public.list_visible_happens_feed(uuid,uuid,uuid,uuid,timestamptz,text,uuid,integer) to authenticated;
