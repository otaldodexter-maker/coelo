-- Perfil interno sintetico para o usuario de teste qa-r03@coelo.me (ADR 0034,
-- Decisao 10 / P17). Producao tem 4 identidades internas e 0 perfis: a lista
-- de Usuarios internos (superadmin_internal_users_list faz join com
-- superadmin_internal_profiles) devolve vazio e as acoes internal-users.list,
-- detail e edit nao podem ser provadas na rota normal. Nao existe RPC de
-- criacao de usuario interno em producao (so update e change_status), entao
-- o perfil entra como semente idempotente, aplicada pelo coordenador como
-- lote. Dado 100% sintetico: CPF invalido de teste, e-mail do proprio usuario
-- sintetico, cargo "Usuario sintetico de teste". Sai junto com o usuario ao
-- fim da rodada (delete por internal_identity_id).
--
-- A semente so grava se a identidade existir (producao); em bases sem ela e
-- no-op. Rodar duas vezes nao duplica nem altera.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

create or replace function app_private.seed_qa_r03_internal_profile()
returns integer
language plpgsql
security definer
set search_path to ''
as $$
declare
  inserted integer := 0;
begin
  insert into app_private.superadmin_internal_profiles (
    internal_identity_id, first_name, last_name, display_name, cpf,
    professional_email, job_title, department, internal_function
  )
  select identity.id, 'QA', 'R04 Sintetico', 'QA R04 Sintetico', '00000000000',
         'qa-r03@coelo.me', 'Usuario sintetico de teste', 'QA', 'Rodada 4'
  from app_private.superadmin_internal_identities identity
  join app_private.superadmin_internal_auth_links auth_link
    on auth_link.internal_identity_id = identity.id
  join auth.users auth_user on auth_user.id = auth_link.auth_user_id
  where auth_user.email = 'qa-r03@coelo.me'
    and not exists (
      select 1 from app_private.superadmin_internal_profiles existing
      where existing.internal_identity_id = identity.id
    );
  get diagnostics inserted = row_count;
  return inserted;
end
$$;

revoke all on function app_private.seed_qa_r03_internal_profile() from public, anon, authenticated;

select app_private.seed_qa_r03_internal_profile();

commit;
