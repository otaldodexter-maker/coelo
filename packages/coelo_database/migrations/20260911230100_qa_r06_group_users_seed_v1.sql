-- Rodada 6 (E2-R06-20260911), decisao do Owner de 11/09 15:20 (ADR 0034
-- Decisao 17): um usuario interno sintetico por frente. Os sete auth users
-- qa-r06-<grupo>@coelo.me foram criados pela API de administracao do Auth
-- (nunca insert em auth.users). Esta semente, idempotente por e-mail, da a
-- cada um: identidade interna v2, vinculo auth ativo, membership Owner de
-- plataforma (mesmo papel do qa-r03), perfil interno (padrao do 171200),
-- ponte de ator (220400, disparada pelo trigger da membership) e membership
-- owner ativa nas instituicoes sinteticas qa-r04-* (padrao do 230024).
-- Sem segredo, sem e-mail alem dos sinteticos. Em bases sem os auth users
-- (espelho local) e no-op por usuario. Rodar duas vezes nao duplica.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

drop function if exists app_private.seed_qa_r06_group_user(text, text);

create or replace function app_private.seed_qa_r06_group_user(p_email text, p_group text, p_cpf text default '00000000000')
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_auth_user_id uuid;
  v_identity_id uuid;
  v_role_id uuid;
  v_person_id uuid;
  v_inst_memberships integer := 0;
  v_created boolean := false;
begin
  select id into v_auth_user_id from auth.users where email = p_email;
  if v_auth_user_id is null then
    return jsonb_build_object('email', p_email, 'skipped', 'auth user ausente');
  end if;

  -- papel Owner de plataforma: o mesmo do qa-r03 (fonte de verdade em producao)
  select m.platform_role_id into v_role_id
  from app_private.superadmin_internal_memberships m
  join app_private.superadmin_internal_auth_links l on l.internal_identity_id = m.internal_identity_id
  join auth.users u on u.id = l.auth_user_id
  where u.email = 'qa-r03@coelo.me' and m.status = 'active' and m.scope_kind = 'platform'
  order by m.created_at limit 1;
  if v_role_id is null then
    select id into v_role_id from public.platform_roles where code = 'owner' limit 1;
  end if;
  if v_role_id is null then
    raise exception 'papel owner de plataforma nao encontrado' using errcode = '55000';
  end if;

  select l.internal_identity_id into v_identity_id
  from app_private.superadmin_internal_auth_links l
  where l.auth_user_id = v_auth_user_id
  order by (l.status = 'active') desc, l.created_at limit 1;

  if v_identity_id is null then
    insert into app_private.superadmin_internal_identities default values
      returning id into v_identity_id;
    insert into app_private.superadmin_internal_auth_links (internal_identity_id, auth_user_id, status)
      values (v_identity_id, v_auth_user_id, 'active');
    v_created := true;
  else
    update app_private.superadmin_internal_auth_links
      set status = 'active', suspended_at = null, revoked_at = null
      where internal_identity_id = v_identity_id and auth_user_id = v_auth_user_id
        and status <> 'active';
  end if;

  if not exists (
    select 1 from app_private.superadmin_internal_memberships m
    where m.internal_identity_id = v_identity_id and m.status = 'active' and m.scope_kind = 'platform'
  ) then
    insert into app_private.superadmin_internal_memberships (internal_identity_id, platform_role_id, scope_kind, status)
      values (v_identity_id, v_role_id, 'platform', 'active');
  end if;

  insert into app_private.superadmin_internal_profiles (
    internal_identity_id, first_name, last_name, display_name, cpf,
    professional_email, job_title, department, internal_function
  )
  select v_identity_id, 'QA', 'R06 ' || initcap(p_group), 'QA R06 ' || initcap(p_group), p_cpf,
         p_email, 'Usuario sintetico de teste', 'QA', 'Rodada 6 - ' || p_group
  where not exists (
    select 1 from app_private.superadmin_internal_profiles existing
    where existing.internal_identity_id = v_identity_id
  );

  -- ponte de ator: garante a pessoa de servico mesmo se o trigger nao disparou
  v_person_id := app_private.superadmin_internal_actor_sync(v_identity_id);

  insert into public.institution_memberships (person_id, institution_id, role_code, status, scope_kind)
  select v_person_id, inst.id, 'owner', 'active', 'institution'
  from public.institutions inst
  where inst.deleted_at is null
    and inst.slug in ('qa-r04-chat', 'qa-r04-cuidado-sintetico', 'qa-r04-escola')
    and not exists (
      select 1 from public.institution_memberships m
      where m.person_id = v_person_id and m.institution_id = inst.id
        and m.status = 'active' and m.revoked_at is null
    );
  get diagnostics v_inst_memberships = row_count;

  return jsonb_build_object(
    'email', p_email, 'identity_id', v_identity_id, 'person_id', v_person_id,
    'identity_created', v_created, 'institution_memberships_added', v_inst_memberships);
end
$$;

revoke all on function app_private.seed_qa_r06_group_user(text, text, text) from public, anon, authenticated;

-- CPF sintetico distinto por usuario (o catalogo tem indice unico por hash de CPF).
select app_private.seed_qa_r06_group_user('qa-r06-' || g || '@coelo.me', g, lpad((60000 + n)::text, 11, '0'))
from unnest(array['estrutura','acessos','formularios','principal','realm','publicacoes','operacoes']) with ordinality as t(g, n);

commit;
