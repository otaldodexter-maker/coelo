-- R06 (ADR 0034, Decisao 17): um usuario interno sintetico por frente
-- (qa-r06-<grupo>@coelo.me). O auth user nasce pela API de administracao do
-- Auth (nunca insert em auth.users); esta semente, idempotente por e-mail,
-- da a cada um o que qa-r03 tem: identidade interna + vinculo de auth +
-- membership owner de PLATAFORMA + perfil interno sintetico (padrao 171200).
-- A ponte 220400 espelha pessoa de servico e platform_membership por gatilho;
-- o sincronizador 130000 (com escopo, 20260912210000) da membership owner nas
-- instituicoes ativas, inclusive as sinteticas qa-r04-* (P35), e o insert
-- final repete o padrao do lote 27 para essas tres por seguranca.
--
-- E-mail ausente em auth.users -> NOTICE e no-op para aquele grupo (rodar de
-- novo depois de criar o usuario). Rodar duas vezes nao duplica nem altera.
-- Sem segredo: a senha vive so em Coelo-backups/qa-r06-<grupo>.env.
-- Limpeza: junto com os demais dados sinteticos no fim da Etapa 2 (P42).

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create or replace function app_private.seed_qa_r06_group_users()
returns table (email text, outcome text)
language plpgsql
security definer
set search_path to ''
as $$
declare
  g record;
  owner_role_id uuid;
  v_auth_user_id uuid;
  identity_id uuid;
begin
  select id into owner_role_id from public.platform_roles where code = 'owner' and status = 'active';
  if owner_role_id is null then
    raise object_not_in_prerequisite_state using message = 'platform role owner missing';
  end if;

  for g in
    select * from (values
      ('qa-r06-estrutura@coelo.me',   'Estrutura',    '00000000101'),
      ('qa-r06-acessos@coelo.me',     'Acessos',      '00000000102'),
      ('qa-r06-formularios@coelo.me', 'Formularios',  '00000000103'),
      ('qa-r06-principal@coelo.me',   'Principal',    '00000000104'),
      ('qa-r06-realm@coelo.me',       'Realm',        '00000000105'),
      ('qa-r06-publicacoes@coelo.me', 'Publicacoes',  '00000000106'),
      ('qa-r06-operacoes@coelo.me',   'Operacoes',    '00000000107')
    ) v(email, grupo, cpf)
  loop
    select u.id into v_auth_user_id from auth.users u where lower(u.email) = g.email limit 1;
    if v_auth_user_id is null then
      email := g.email; outcome := 'auth user ausente (criar pela API de administracao do Auth)';
      return next; continue;
    end if;

    select l.internal_identity_id into identity_id
    from app_private.superadmin_internal_auth_links l
    where l.auth_user_id = v_auth_user_id and l.status = 'active';
    if identity_id is null then
      insert into app_private.superadmin_internal_identities default values returning id into identity_id;
      insert into app_private.superadmin_internal_auth_links (internal_identity_id, auth_user_id)
      values (identity_id, v_auth_user_id);
    end if;

    if not exists (
      select 1 from app_private.superadmin_internal_memberships m
      where m.internal_identity_id = identity_id and m.status = 'active'
    ) then
      insert into app_private.superadmin_internal_memberships (internal_identity_id, platform_role_id, scope_kind, scope_institution_id)
      values (identity_id, owner_role_id, 'platform', null);
    end if;

    insert into app_private.superadmin_internal_profiles (
      internal_identity_id, first_name, last_name, display_name, cpf,
      professional_email, job_title, department, internal_function
    )
    select identity_id, 'QA R06', g.grupo, 'QA R06 ' || g.grupo, g.cpf,
           g.email, 'Usuario sintetico de teste', 'QA', 'Rodada 6'
    where not exists (
      select 1 from app_private.superadmin_internal_profiles p where p.internal_identity_id = identity_id
    );

    email := g.email; outcome := 'ok (identidade ' || left(identity_id::text, 8) || ')';
    return next;
  end loop;

  -- Padrao do lote 27: owner nas instituicoes sinteticas (o sync do 130000 ja cobre; idempotente).
  insert into public.institution_memberships (person_id, institution_id, role_code, status, scope_kind)
  select actor.person_id, inst.id, 'owner', 'active', 'institution'
  from app_private.superadmin_internal_actor_people actor
  join app_private.superadmin_internal_auth_links link
    on link.internal_identity_id = actor.internal_identity_id and link.status = 'active'
  join auth.users u on u.id = link.auth_user_id and lower(u.email) like 'qa-r06-%@coelo.me'
  cross join public.institutions inst
  where inst.deleted_at is null
    and inst.slug in ('qa-r04-chat', 'qa-r04-cuidado-sintetico', 'qa-r04-escola')
    and not exists (
      select 1 from public.institution_memberships m
      where m.person_id = actor.person_id and m.institution_id = inst.id
        and m.status = 'active' and m.revoked_at is null
    );
  return;
end
$$;
revoke all on function app_private.seed_qa_r06_group_users() from public, anon, authenticated, service_role;

do $$
declare r record;
begin
  for r in select * from app_private.seed_qa_r06_group_users() loop
    raise notice 'qa_r06_group_users_seed_v1: % -> %', r.email, r.outcome;
  end loop;
end $$;

commit;
