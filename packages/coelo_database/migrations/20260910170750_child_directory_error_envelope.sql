-- Promovida a migration real em 2026-09-10 pelo grupo acessos-pessoas.
-- Origem: replay/profiles/ChildDirectoryEnvelope/20260908051499_child_directory_error_envelope_bridge.sql
--
-- Por que precisou ser promovida
-- ------------------------------
-- 20260910170800_d04_child_safety_internal_reads RECUSA instalar quando
-- app_private.superadmin_internal_error_envelope nao devolve SAI_INVALID_ARGUMENT
-- para esse codigo; ela prefere falhar a instalar wrappers que mascaram erro. Em
-- producao o envelope ainda colapsa esse codigo em SAI_INTERNAL_ERROR 500.
--
-- O conserto existia apenas como PONTE DE REPLAY LOCAL, dentro do perfil
-- ChildDirectoryEnvelope, e por isso nunca teve caminho ate producao. Enquanto
-- ficar so la, o pacote D04 nao aplica em lugar nenhum que nao seja o replay.
--
-- O que muda
-- ----------
-- Aditivo: SAI_INVALID_ARGUMENT passa a ser um codigo reconhecido, com mensagem
-- propria e HTTP 400, em vez de virar erro interno 500. Nenhum codigo existente
-- muda de comportamento.
--
-- Seguranca da promocao
-- ---------------------
-- O preflight abaixo fixa o md5 do corpo VIGENTE do helper
-- (b89d2dc22f032a1c3f155a77f0eaaf08) e recusa se houver qualquer desvio de dono,
-- volatilidade, linguagem, search_path ou ACL. Se producao ja tiver outra versao,
-- esta migration nao sobrescreve: ela para.
--
-- Aviso ao coordenador: o helper e COMPARTILHADO pelo realm interno e a ponte foi
-- escrita por outro grupo. Promovi porque bloqueia o meu pacote e porque o
-- conteudo ja estava revisado e fixado por hash naquele perfil. E reversivel.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
select pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('coelo.child-envelope-prerequisite',0));
do $preflight$
declare p record;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='envelope prerequisite requires postgres';
  end if;
  select * into p from pg_catalog.pg_proc
    where oid=pg_catalog.to_regprocedure('app_private.superadmin_internal_error_envelope(text,uuid)');
  if p.oid is null
    or md5(replace(p.prosrc,E'\r\n',E'\n')) <> 'b89d2dc22f032a1c3f155a77f0eaaf08'
    or p.prokind <> 'f' or p.provolatile <> 'i' or p.prosecdef or p.proretset
    or p.prorettype <> 'jsonb'::regtype
    or pg_catalog.pg_get_userbyid(p.proowner) <> 'postgres'
    or coalesce(p.proconfig,'{}'::text[]) <> array['search_path=""']::text[]
    or (select lanname from pg_catalog.pg_language where oid=p.prolang) <> 'sql'
    or exists(select 1 from pg_catalog.aclexplode(coalesce(p.proacl,
      pg_catalog.acldefault('f',p.proowner))) acl where acl.grantee <> p.proowner) then
    raise object_not_in_prerequisite_state using message='envelope prerequisite dependency drift';
  end if;
end
$preflight$;

create or replace function app_private.superadmin_internal_error_envelope(
  p_code text,p_correlation_id uuid
) returns jsonb
language sql
immutable
security invoker
set search_path=''
as $$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object('code',case when p_code in(
      'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED','SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE',
      'SAI_INVALID_ARGUMENT') then p_code else 'SAI_INTERNAL_ERROR' end,
      'message',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID')
          then 'Autenticação necessária.'
        when p_code='SAI_MFA_REQUIRED' then 'Confirme o segundo fator.'
        when p_code='SAI_INVALID_ARGUMENT' then 'Revise os dados enviados.'
        when p_code in('SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE')
          then 'O estado mudou. Recarregue e tente novamente.'
        when p_code like 'SAI_%DENIED' or p_code like 'SAI_MEMBERSHIP_%'
          then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'correlation_id',p_correlation_id,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code='SAI_INVALID_ARGUMENT' then 400
        when p_code in('SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE') then 409
        when p_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end))
$$;

do $postflight$
begin
  if (select md5(replace(prosrc,E'\r\n',E'\n')) from pg_catalog.pg_proc
    where oid=pg_catalog.to_regprocedure('app_private.superadmin_internal_error_envelope(text,uuid)'))
    is distinct from 'bfce7b85b8d5d43e93e5d3fba3a66dc8' then
    raise object_not_in_prerequisite_state using message='envelope prerequisite result drift';
  end if;
end
$postflight$;
commit;
