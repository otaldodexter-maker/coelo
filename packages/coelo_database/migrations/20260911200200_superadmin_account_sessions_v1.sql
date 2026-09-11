-- R06 · Operacoes — account.sessions (P43 = B, tela minima no MVP).
-- Lista as sessoes do proprio usuario autenticado a partir de auth.sessions.
-- A revogacao das outras sessoes usa o endpoint nativo do GoTrue
-- (POST /auth/v1/logout?scope=others, SDK signOut(scope: others)), que ja e
-- server-side e auditado em auth.audit_log_entries; por isso nao ha RPC nem
-- Edge Function de revogacao aqui.
-- ponytail: so o proprio auth.uid(); nunca aceita user_id por parametro.

create or replace function public.superadmin_account_sessions_list_v1()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
  v_current uuid;
  v_sessions jsonb;
begin
  perform app_private.assert_account_actor();
  v_user := auth.uid();
  v_current := nullif(coalesce(auth.jwt() ->> 'session_id', ''), '')::uuid;

  select coalesce(
           jsonb_agg(row_data order by is_current desc, refreshed_at desc nulls last, created_at desc),
           '[]'::jsonb)
    into v_sessions
  from (
    select
      s.id = v_current as is_current,
      s.created_at,
      coalesce(s.refreshed_at, s.updated_at) as refreshed_at,
      jsonb_build_object(
        'id', s.id,
        'is_current', s.id = v_current,
        'created_at', s.created_at,
        'refreshed_at', coalesce(s.refreshed_at, s.updated_at),
        'not_after', s.not_after,
        'user_agent', left(coalesce(s.user_agent, ''), 240),
        'ip', host(s.ip)
      ) as row_data
    from auth.sessions s
    where s.user_id = v_user
      and (s.not_after is null or s.not_after > now())
  ) live;

  return jsonb_build_object(
    'current_session_id', v_current,
    'sessions', v_sessions
  );
end;
$$;

revoke all on function public.superadmin_account_sessions_list_v1() from public, anon;
grant execute on function public.superadmin_account_sessions_list_v1() to authenticated;
