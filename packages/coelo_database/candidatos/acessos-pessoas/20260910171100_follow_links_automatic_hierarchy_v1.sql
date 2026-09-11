-- D1 (ADR 0034, Decisao 6; decisao do Owner em 10/09/2026): ao cadastrar uma
-- crianca em instituicao, unidade e turma, ela e seus responsaveis passam a
-- acompanhar automaticamente toda a hierarquia acima. O Perfil do Principal
-- (grupo principal-chat-sistema) consome Acompanhar / Seguidores / Seguindo.
--
-- Modelo (proposta da R03 em
-- docs/reviews/evidence/etapa-2/r03-acessos-pessoas/acompanhamento-d1-proposta.md,
-- adotada aqui com as recomendacoes do proprio documento porque o grupo
-- consumidor nao respondeu aos quatro pontos ate a R04):
--
--   public.follow_links: tabela materializada com procedencia. origin =
--   'automatic' nasce e morre por sincronizacao a partir dos vinculos
--   estruturais (child_contexts, child_unit_links, child_group_links,
--   guardian_links); origin = 'manual' nasce e morre pelo botao Acompanhar
--   (follow_set) e nunca e tocado pela estrutura. Automatico e manual
--   coexistem na mesma dupla seguidor/alvo.
--
--   Sincronizacao por contexto de crianca (app_private.follow_links_sync_child_context):
--   recalcula o conjunto {seguidor x alvo} que aquele contexto justifica e
--   insere o que falta / revoga o que sobrou, sempre com
--   source_child_context_id = o contexto. Um vinculo de irmao em outra unidade
--   gera linhas com outra procedencia e sobrevive sozinho. Gatilhos AFTER
--   INSERT OR UPDATE nas quatro tabelas chamam a sincronizacao do contexto
--   afetado. ponytail: gatilho por linha; se uma carga em massa de turma
--   pesar, trocar por gatilho de instrucao com transition table.
--
-- Leitura (para o Perfil):
--   follow_summary(kind, id)          contagem de seguidores do alvo e, para
--                                     pessoa, tambem quantos ela segue; exige
--                                     sessao autenticada; sem dado pessoal.
--   follow_following_list(person, ..) o que uma pessoa segue; a propria pessoa
--                                     ou quem tem people.read.
--   follow_followers_list(kind, id,.) quem segue um alvo; exige people.read,
--                                     porque expoe pessoas (inclusive criancas).
--   follow_set(kind, id, follow)      botao Acompanhar (origin manual) da
--                                     pessoa da sessao.
--
-- Seguranca: RLS deny-by-default, sem policy e sem grant direto na tabela;
-- toda leitura e escrita passa por security definer que valida sessao,
-- ator e capacidade. Nenhuma funcao exige AAL2 (MFA fora do MVP).

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'follow_links migration must run as postgres';
  end if;
  if to_regclass('public.people') is null
     or to_regclass('public.child_contexts') is null
     or to_regclass('public.child_unit_links') is null
     or to_regclass('public.child_group_links') is null
     or to_regclass('public.guardian_links') is null
     or to_regclass('public.institutions') is null
     or to_regclass('public.units') is null
     or to_regclass('public.groups') is null
     or to_regprocedure('app_private.current_person_id()') is null
     or to_regprocedure('app_private.has_platform_permission(text)') is null then
    raise object_not_in_prerequisite_state using message = 'follow_links dependencies are required';
  end if;
  if to_regclass('public.follow_links') is not null then
    raise object_not_in_prerequisite_state using message = 'public.follow_links already exists: package already applied';
  end if;
end
$preflight$;

create type public.follow_target_kind as enum ('institution', 'unit', 'group', 'person');
create type public.follow_origin as enum ('automatic', 'manual');
create type public.follow_source_relationship as enum ('self', 'guardian');

create table public.follow_links (
  id uuid primary key default gen_random_uuid(),
  follower_person_id uuid not null references public.people(id) on delete cascade,
  target_kind public.follow_target_kind not null,
  target_id uuid not null,
  origin public.follow_origin not null,
  source_child_context_id uuid references public.child_contexts(id) on delete cascade,
  source_relationship public.follow_source_relationship,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint follow_links_origin_check check (
    (origin = 'automatic' and source_child_context_id is not null and source_relationship is not null)
    or (origin = 'manual' and source_child_context_id is null and source_relationship is null)
  ),
  constraint follow_links_lifecycle_check check (
    (status = 'active' and revoked_at is null) or (status <> 'active' and revoked_at is not null)
  )
);

comment on table public.follow_links is
  'D1: acompanhamento materializado com procedencia. automatic vem da estrutura (child_contexts/unit/group + guardian_links); manual vem do botao Acompanhar. Sem grant direto: leitura e escrita por RPC security definer.';

-- nulls not distinct: a linha manual (procedencia nula) tambem e unica por
-- seguidor/alvo.
create unique index follow_links_active_unique_idx on public.follow_links (
  follower_person_id, target_kind, target_id, origin,
  source_child_context_id, source_relationship
) nulls not distinct where status = 'active';
create index follow_links_target_active_idx on public.follow_links (target_kind, target_id) where status = 'active';
create index follow_links_follower_active_idx on public.follow_links (follower_person_id) where status = 'active';
create index follow_links_source_idx on public.follow_links (source_child_context_id) where source_child_context_id is not null;

alter table public.follow_links enable row level security;
alter table public.follow_links force row level security;
revoke all on table public.follow_links from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Sincronizacao automatica por contexto de crianca
-- ---------------------------------------------------------------------------
create function app_private.follow_links_sync_child_context(p_child_context_id uuid)
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
  delete from follow_links_expected;

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

revoke all on function app_private.follow_links_sync_child_context(uuid) from public, anon, authenticated;

create function app_private.follow_links_on_child_context()
returns trigger language plpgsql security definer set search_path to '' as $$
begin
  perform app_private.follow_links_sync_child_context(new.id);
  return null;
end $$;

create function app_private.follow_links_on_child_unit_link()
returns trigger language plpgsql security definer set search_path to '' as $$
begin
  perform app_private.follow_links_sync_child_context(new.child_context_id);
  return null;
end $$;

create function app_private.follow_links_on_child_group_link()
returns trigger language plpgsql security definer set search_path to '' as $$
begin
  perform app_private.follow_links_sync_child_context(unit_link.child_context_id)
  from public.child_unit_links unit_link
  where unit_link.id = new.child_unit_link_id;
  return null;
end $$;

create function app_private.follow_links_on_guardian_link()
returns trigger language plpgsql security definer set search_path to '' as $$
begin
  perform app_private.follow_links_sync_child_context(ctx.id)
  from public.child_contexts ctx
  where ctx.child_person_id = new.child_person_id;
  return null;
end $$;

revoke all on function app_private.follow_links_on_child_context() from public, anon, authenticated;
revoke all on function app_private.follow_links_on_child_unit_link() from public, anon, authenticated;
revoke all on function app_private.follow_links_on_child_group_link() from public, anon, authenticated;
revoke all on function app_private.follow_links_on_guardian_link() from public, anon, authenticated;

-- Nomes com prefixo zz_ para correrem depois das validacoes existentes
-- (child_*_validate, guardian_links_00_relationship_defaults): os gatilhos
-- de mesmo evento disparam em ordem alfabetica.
create trigger zz_follow_links_sync after insert or update on public.child_contexts
  for each row execute function app_private.follow_links_on_child_context();
create trigger zz_follow_links_sync after insert or update on public.child_unit_links
  for each row execute function app_private.follow_links_on_child_unit_link();
create trigger zz_follow_links_sync after insert or update on public.child_group_links
  for each row execute function app_private.follow_links_on_child_group_link();
create trigger zz_follow_links_sync after insert or update on public.guardian_links
  for each row execute function app_private.follow_links_on_guardian_link();

-- ---------------------------------------------------------------------------
-- Leitura e comando para o Perfil
-- ---------------------------------------------------------------------------
create function app_private.follow_target_kind_of(p_kind text)
returns public.follow_target_kind
language plpgsql immutable set search_path to '' as $$
begin
  if p_kind not in ('institution', 'unit', 'group', 'person') then
    raise invalid_parameter_value using message = 'unsupported follow target kind';
  end if;
  return p_kind::public.follow_target_kind;
end $$;
revoke all on function app_private.follow_target_kind_of(text) from public, anon, authenticated;

create function public.follow_summary(p_target_kind text, p_target_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  kind public.follow_target_kind := app_private.follow_target_kind_of(p_target_kind);
  followers_count bigint;
  following_count bigint;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'follow summary requires a session';
  end if;
  select count(distinct link.follower_person_id) into followers_count
  from public.follow_links link
  where link.target_kind = kind and link.target_id = p_target_id and link.status = 'active';
  if kind = 'person' then
    select count(distinct (link.target_kind, link.target_id)) into following_count
    from public.follow_links link
    where link.follower_person_id = p_target_id and link.status = 'active';
  end if;
  return jsonb_build_object(
    'target_kind', kind, 'target_id', p_target_id,
    'followers_count', followers_count,
    'following_count', following_count
  );
end $$;

create function public.follow_following_list(
  p_person_id uuid,
  p_limit integer default 50,
  p_after_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  actor uuid := app_private.current_person_id();
  safe_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  if (select auth.uid()) is null
     or not (actor = p_person_id or app_private.has_platform_permission('people.read')) then
    raise insufficient_privilege using message = 'follow list permission denied';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', link.id, 'target_kind', link.target_kind, 'target_id', link.target_id,
      'origin', link.origin, 'since', link.created_at
    ) order by link.created_at desc, link.id)
    from (
      select * from public.follow_links link
      where link.follower_person_id = p_person_id and link.status = 'active'
        and (p_after_id is null or link.id > p_after_id)
      order by link.created_at desc, link.id
      limit safe_limit
    ) link
  ), '[]'::jsonb);
end $$;

create function public.follow_followers_list(
  p_target_kind text,
  p_target_id uuid,
  p_limit integer default 50,
  p_after_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  kind public.follow_target_kind := app_private.follow_target_kind_of(p_target_kind);
  safe_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  if (select auth.uid()) is null or not app_private.has_platform_permission('people.read') then
    raise insufficient_privilege using message = 'follow list permission denied';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', link.id, 'person_id', link.follower_person_id,
      'display_name', person.display_name, 'person_type', person.person_type,
      'origin', link.origin, 'since', link.created_at
    ) order by link.created_at desc, link.id)
    from (
      select * from public.follow_links link
      where link.target_kind = kind and link.target_id = p_target_id and link.status = 'active'
        and (p_after_id is null or link.id > p_after_id)
      order by link.created_at desc, link.id
      limit safe_limit
    ) link
    join public.people person on person.id = link.follower_person_id
  ), '[]'::jsonb);
end $$;

create function public.follow_set(p_target_kind text, p_target_id uuid, p_follow boolean)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  kind public.follow_target_kind := app_private.follow_target_kind_of(p_target_kind);
  actor uuid := app_private.current_person_id();
  target_exists boolean;
begin
  if (select auth.uid()) is null or actor is null then
    raise insufficient_privilege using message = 'follow requires an identified person';
  end if;
  if kind = 'person' and p_target_id = actor then
    raise invalid_parameter_value using message = 'a person cannot follow themselves';
  end if;
  target_exists := case kind
    when 'institution' then exists(select 1 from public.institutions x where x.id = p_target_id)
    when 'unit' then exists(select 1 from public.units x where x.id = p_target_id)
    when 'group' then exists(select 1 from public.groups x where x.id = p_target_id)
    when 'person' then exists(select 1 from public.people x where x.id = p_target_id)
  end;
  if not target_exists then
    raise no_data_found using message = 'follow target not found';
  end if;
  if p_follow then
    insert into public.follow_links (follower_person_id, target_kind, target_id, origin)
    select actor, kind, p_target_id, 'manual'
    where not exists (
      select 1 from public.follow_links link
      where link.follower_person_id = actor and link.target_kind = kind
        and link.target_id = p_target_id and link.origin = 'manual' and link.status = 'active'
    );
  else
    update public.follow_links link
    set status = 'inactive', revoked_at = now(), updated_at = now()
    where link.follower_person_id = actor and link.target_kind = kind
      and link.target_id = p_target_id and link.origin = 'manual' and link.status = 'active';
  end if;
  return public.follow_summary(p_target_kind, p_target_id)
    || jsonb_build_object('following', exists(
      select 1 from public.follow_links link
      where link.follower_person_id = actor and link.target_kind = kind
        and link.target_id = p_target_id and link.status = 'active'));
end $$;

revoke all on function public.follow_summary(text, uuid) from public, anon;
revoke all on function public.follow_following_list(uuid, integer, uuid) from public, anon;
revoke all on function public.follow_followers_list(text, uuid, integer, uuid) from public, anon;
revoke all on function public.follow_set(text, uuid, boolean) from public, anon;
grant execute on function public.follow_summary(text, uuid) to authenticated;
grant execute on function public.follow_following_list(uuid, integer, uuid) to authenticated;
grant execute on function public.follow_followers_list(text, uuid, integer, uuid) to authenticated;
grant execute on function public.follow_set(text, uuid, boolean) to authenticated;

commit;
