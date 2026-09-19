-- Perfis oficiais do Coelo — spec 068 (carga do catálogo + leitor do Principal). Lote 104.
--   * Carga da lista final (decisão delegada pelo Owner à Sessão ETAPA-3, 20/09/2026): cinco
--     perfis — coelo (obrigatório, já existia), coelo.alimentacao, coelo.educa, coelo.cuidado e
--     coelo.brincar — cada um com pessoa técnica própria (c0e10000-…0002..0005) e @ reservado.
--     Meta somada: 1,5 posts/dia (dentro de 1–4). coelo.escola e coelo.familias ficam de fora.
--   * public.principal_official_profiles_v1(p_handle): leitor de família (auth.uid → pessoa).
--     Sem handle devolve o catálogo ativo com `following`; com handle devolve o perfil, se o
--     ator o segue e as publicações do perfil que ele pode ver (reusa list_my_principal_for_you,
--     ou seja, mesma audiência/vigência do Para você, filtrada pelo autor).
-- Reversão: drop function public.principal_official_profiles_v1(text); os perfis novos ficam
-- (status='inactive' os tira do Principal).

begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then raise exception 'executar como postgres'; end if;
  if to_regclass('public.official_profiles') is null
    or to_regprocedure('public.list_my_principal_for_you(text,uuid,integer)') is null
    or to_regprocedure('app_private.official_profiles_backfill_follows_v1()') is null then
    raise exception 'pre-requisitos do lote 95 ausentes';
  end if;
end $preflight$;

-- 1. pessoas técnicas + @ reservados + catálogo -------------------------------------------
insert into public.people (id, person_type, first_name, last_name, display_name, status) values
  ('c0e10000-0000-4000-8000-000000000002', 'service', 'Coelo Alimentação', '', 'Coelo Alimentação', 'active'),
  ('c0e10000-0000-4000-8000-000000000003', 'service', 'Coelo Educa', '', 'Coelo Educa', 'active'),
  ('c0e10000-0000-4000-8000-000000000004', 'service', 'Coelo Cuidado', '', 'Coelo Cuidado', 'active'),
  ('c0e10000-0000-4000-8000-000000000005', 'service', 'Coelo Brincar', '', 'Coelo Brincar', 'active')
on conflict (id) do nothing;

insert into public.reserved_handles (handle, reason) values
  ('coelo.alimentacao', 'perfil oficial do app (spec 068)'),
  ('coelo.educa', 'perfil oficial do app (spec 068)'),
  ('coelo.cuidado', 'perfil oficial do app (spec 068)'),
  ('coelo.brincar', 'perfil oficial do app (spec 068)'),
  ('coelo.escola', 'reservado para perfil oficial futuro (spec 068)'),
  ('coelo.familias', 'reservado para perfil oficial futuro (spec 068)')
on conflict (handle) do nothing;

insert into public.official_profiles (person_id, handle, display_name, description, mandatory, sort_order, posts_per_day_target) values
  ('c0e10000-0000-4000-8000-000000000002', 'coelo.alimentacao', 'Coelo Alimentação',
    'Lanches, cardápios, alergias e rotina alimentar.', false, 1, 0.25),
  ('c0e10000-0000-4000-8000-000000000003', 'coelo.educa', 'Coelo Educa',
    'Desenvolvimento infantil, limites, sono e telas.', false, 2, 0.25),
  ('c0e10000-0000-4000-8000-000000000004', 'coelo.cuidado', 'Coelo Cuidado',
    'Saúde e segurança infantil, primeiros socorros e medicação.', false, 3, 0.25),
  ('c0e10000-0000-4000-8000-000000000005', 'coelo.brincar', 'Coelo Brincar',
    'Atividades, brincadeiras e passeios por faixa etária.', false, 4, 0.25)
on conflict (handle) do nothing;

-- Pessoas técnicas não seguem nem são seguidas pelo sync antigo da Coelo (P35): limpa o que o
-- trigger de people criou ao inserir as quatro acima.
delete from public.follow_links link
where link.origin = 'manual'
  and (link.follower_person_id in ('c0e10000-0000-4000-8000-000000000002', 'c0e10000-0000-4000-8000-000000000003',
        'c0e10000-0000-4000-8000-000000000004', 'c0e10000-0000-4000-8000-000000000005')
    or (link.target_kind = 'person' and link.target_id in ('c0e10000-0000-4000-8000-000000000002',
        'c0e10000-0000-4000-8000-000000000003', 'c0e10000-0000-4000-8000-000000000004',
        'c0e10000-0000-4000-8000-000000000005')));

select app_private.official_profiles_backfill_follows_v1();

-- 2. leitor do Principal ---------------------------------------------------------------------
create or replace function public.principal_official_profiles_v1(p_handle text default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid;
  profile public.official_profiles;
  profiles jsonb;
  items jsonb := '[]'::jsonb;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;
  actor := app_private.current_person_id();
  if actor is null then
    raise insufficient_privilege using message = 'principal_context_denied';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', o.id, 'handle', o.handle, 'display_name', o.display_name, 'description', o.description,
      'mandatory', o.mandatory, 'person_id', o.person_id, 'sort_order', o.sort_order,
      'followers', (select count(*) from public.follow_links f
        where f.target_kind = 'person' and f.target_id = o.person_id and f.status = 'active'),
      'following', exists (select 1 from public.follow_links f
        where f.follower_person_id = actor and f.target_kind = 'person'
          and f.target_id = o.person_id and f.status = 'active'))
      order by o.sort_order, o.handle), '[]'::jsonb)
    into profiles
  from public.official_profiles o where o.status = 'active';

  if p_handle is null then
    return jsonb_build_object('ok', true, 'data', jsonb_build_object('profiles', profiles), 'error', null);
  end if;

  select * into profile from public.official_profiles o
  where o.handle = lower(btrim(p_handle)) and o.status = 'active';
  if profile.id is null then
    raise no_data_found using message = 'official profile not found', detail = 'OFFICIAL_PROFILE_NOT_FOUND';
  end if;

  -- Publicações do perfil que o ator pode ver: mesma regra do Para você, filtrada pelo autor.
  select coalesce(jsonb_agg(item), '[]'::jsonb) into items
  from jsonb_array_elements(public.list_my_principal_for_you('all', null, 100) #> '{data,items}') item
  where item #>> '{author,id}' = profile.id::text;

  return jsonb_build_object('ok', true, 'data', jsonb_build_object(
    'profiles', profiles,
    'profile', (select p from jsonb_array_elements(profiles) p where p ->> 'id' = profile.id::text),
    'items', items), 'error', null);
end
$$;
alter function public.principal_official_profiles_v1(text) owner to postgres;
revoke all on function public.principal_official_profiles_v1(text) from public, anon, service_role;
grant execute on function public.principal_official_profiles_v1(text) to authenticated;
comment on function public.principal_official_profiles_v1(text) is
  'Leitor do Principal para perfis oficiais (spec 068): catálogo ativo com following; com handle, o perfil e as publicações visíveis ao ator (mesma audiência do Para você).';

commit;
